// Licensed under GPL-3.0. See LICENSE.
//
//  AIConfigService.swift
//  Nook
//
//  Manages AI configuration persistence via JSON file
//

import CryptoKit
import Foundation
import NookSettings
import OSLog

@MainActor
@Observable
class AIConfigService {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Nook", category: "AIConfig")

    private(set) var config: AIConfiguration
    private let configURL: URL

    // Convenience accessors
    var providers: [AIProviderConfig] { config.providers }
    var models: [AIModelConfig] { config.models }
    var generationConfig: AIGenerationConfig {
        get { config.generationConfig }
        set {
            config.generationConfig = newValue
            save()
        }
    }
    var mcpServers: [MCPServerConfig] {
        get { config.mcpServers }
        set {
            config.mcpServers = newValue
            save()
        }
    }
    var browserToolsConfig: BrowserToolsConfig {
        get { config.browserToolsConfig }
        set {
            config.browserToolsConfig = newValue
            save()
        }
    }

    var activeProvider: AIProviderConfig? {
        config.providers.first { $0.id == config.activeProviderId }
    }

    var activeModel: AIModelConfig? {
        // The same model id can belong to two providers, so the provider counts too.
        config.models.first { $0.id == config.activeModelId && $0.providerId == config.activeProviderId }
            ?? config.models.first { $0.id == config.activeModelId }
    }

    /// FORK: providers the chat can use now: switched on, and with a key where one is needed.
    var usableProviders: [AIProviderConfig] {
        config.providers.filter { provider in
            guard provider.isEnabled else { return false }
            switch provider.providerType {
            case .appleIntelligence: return AppleIntelligenceProvider.isAvailable
            case .ollama, .openAICompatible: return true
            case .gemini, .openRouter: return !provider.apiKey.isEmpty
            }
        }
    }

    /// FORK: picks a model from any usable provider; the chat then talks to that provider.
    func selectModel(_ model: AIModelConfig) {
        config.activeProviderId = model.providerId
        config.activeModelId = model.id
        save()
    }

    /// FORK: asks a custom provider (OmniRoute, LM Studio, ...) which models it has and adds them.
    /// Returns a short message for the settings page.
    func fetchModels(for provider: AIProviderConfig) async -> String {
        let isGemini = provider.providerType == .gemini
        guard Self.isSafeAddress(provider.baseURL) else { return "Failed: \(Self.insecureMessage)" }
        guard let url = URL(string: provider.baseURL + "/models" + (isGemini ? "?pageSize=1000" : "")) else { return "Failed: the Base URL is not valid" }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        if !provider.apiKey.isEmpty {
            // Gemini wants the key in its own header; the others take a Bearer token.
            if isGemini { request.setValue(provider.apiKey, forHTTPHeaderField: "x-goog-api-key") }
            else { request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization") }
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return "Failed: no response" }
            guard http.statusCode == 200 else { return "Failed: \(Self.reason(http.statusCode))" }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            var found: [(id: String, name: String)] = []
            if isGemini {
                for m in json?["models"] as? [[String: Any]] ?? [] {
                    // Only models that can chat.
                    guard let name = m["name"] as? String,
                          (m["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true else { continue }
                    let id = name.hasPrefix("models/") ? String(name.dropFirst(7)) : name
                    found.append((id, m["displayName"] as? String ?? id))
                }
            } else {
                for m in json?["data"] as? [[String: Any]] ?? [] {
                    if let id = m["id"] as? String { found.append((id, (m["name"] as? String) ?? id)) }
                }
            }
            guard !found.isEmpty else { return "Failed: the provider listed no models" }
            fetchedModels[provider.id] = found.sorted { $0.id < $1.id }.map {
                AIModelConfig(id: $0.id, displayName: provider.providerType == .openAICompatible ? $0.id : $0.name, providerId: provider.id, isCustom: true,
                              capabilities: AIModelCapabilities(toolCalling: true, streaming: true, webSearch: isGemini))
            }
            return "Success: \(found.count) models found. Switch on the ones you want in the chat."
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    /// FORK: switches on the chat models a provider lists that answer a test request. Image, speech, embedding
    /// and other non-chat models are skipped without asking. Returns a short summary.
    func enableWorkingModels(for provider: AIProviderConfig) async -> String {
        let skip = ["image", "tts", "audio", "live", "embedding", "robotics", "computer-use", "deep-research", "antigravity", "veo", "imagen", "aqa", "learnlm", "gemma", "transcribe", "speech", "translate", "tuning", "dialog", "bidi", "ocr", "diffusion", "lyria"]
        let candidates = (fetchedModels[provider.id] ?? []).filter { m in
            !skip.contains { m.id.lowercased().contains($0) } && !models.contains { $0.id == m.id && $0.providerId == provider.id }
        }
        guard !candidates.isEmpty else { return "Nothing new to turn on" }
        var worked = 0, failed = 0
        await withTaskGroup(of: (AIModelConfig, Bool).self) { group in
            var iterator = candidates.makeIterator()
            func next() { if let m = iterator.next() { group.addTask { (m, await self.verifyModel(m.id, for: provider) == nil) } } }
            for _ in 0..<4 { next() }   // four at a time, to stay inside rate limits
            for await (model, ok) in group {
                if ok { addModel(model); worked += 1 } else { failed += 1 }
                next()
            }
        }
        return "Turned on \(worked) models that work. \(failed) did not answer and were left off."
    }

    /// FORK: asks a custom provider for one token from a model, so only a model that answers gets added.
    /// Returns nil when it works, else why not.
    func verifyModel(_ modelId: String, for provider: AIProviderConfig) async -> String? {
        if provider.providerType != .ollama, provider.providerType != .appleIntelligence, !Self.isSafeAddress(provider.baseURL) { return Self.insecureMessage }
        var request: URLRequest
        let body: [String: Any]
        switch provider.providerType {
        case .gemini:
            guard let url = URL(string: "\(provider.baseURL)/models/\(modelId):generateContent") else { return "the Base URL is not valid" }
            request = URLRequest(url: url)
            request.setValue(provider.apiKey, forHTTPHeaderField: "x-goog-api-key")
            body = ["contents": [["role": "user", "parts": [["text": "hi"]]]], "generationConfig": ["maxOutputTokens": 1]]
        case .openAICompatible, .openRouter:
            guard let url = URL(string: provider.baseURL + "/chat/completions") else { return "the Base URL is not valid" }
            request = URLRequest(url: url)
            if !provider.apiKey.isEmpty { request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization") }
            body = ["model": modelId, "max_tokens": 1, "messages": [["role": "user", "content": "hi"]]]
        default:
            return nil
        }
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return "no response" }
            if http.statusCode == 200 { return nil }
            let message = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
            return message.map { String($0.prefix(120)) } ?? Self.reason(http.statusCode)
        } catch {
            return error.localizedDescription
        }
    }

    /// A key is only sent over HTTPS, or to this Mac (LM Studio, OmniRoute and the like): over plain HTTP to
    /// another machine it would cross the network readable. The chat's own provider enforces the same rule.
    static func isSafeAddress(_ baseURL: String) -> Bool { AIAddress.isSafe(baseURL) }

    static let insecureMessage = "the address must start with https:// (http:// is only allowed for this Mac)"

    static func reason(_ status: Int) -> String {
        switch status {
        case 401, 403: return "the key was refused (HTTP \(status))"
        case 404: return "address not found (HTTP 404), check the Base URL"
        default: return "HTTP \(status)"
        }
    }

    var activeProviderType: AIProviderType? {
        activeProvider?.providerType
    }

    // Dynamic model lists (fetched from APIs)
    var openRouterModels: [AIModelConfig] = []
    var ollamaModels: [AIModelConfig] = []
    /// FORK: what a custom provider said it has, by provider id. Kept here, not saved: it can be hundreds long.
    var fetchedModels: [String: [AIModelConfig]] = [:]
    var isFetchingModels: Bool = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let nookDir = appSupport.appendingPathComponent(SharedSupportFolder.name)
        self.configURL = nookDir.appendingPathComponent("ai_config.json")

        // Load or create default config
        if let loaded = AIConfigService.load(from: configURL) {
            self.config = loaded
        } else {
            self.config = AIConfigService.createDefaultConfig()
        }

        // Migrate from UserDefaults if this is a fresh config
        migrateFromUserDefaultsIfNeeded()
        addOnDeviceProvider()
        replaceUneditedSystemPrompt()
    }

    // MARK: - Persistence

    func save() {
        do {
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(config)
            try data.write(to: configURL, options: .atomic)
            // SECURITY: Restrict config file permissions to owner-only (may contain sensitive paths/settings)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch {
            Self.log.error("Failed to save AI config: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> AIConfiguration? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AIConfiguration.self, from: data)
    }

    // MARK: - Provider Management

    func setActiveProvider(_ providerId: String) {
        config.activeProviderId = providerId
        // Using a provider switches it on, or it would vanish from the chat's model list.
        if let i = config.providers.firstIndex(where: { $0.id == providerId }) { config.providers[i].isEnabled = true }
        // Auto-select first model for this provider
        if let firstModel = config.models.first(where: { $0.providerId == providerId }) {
            config.activeModelId = firstModel.id
        }
        save()
    }

    func setActiveModel(_ modelId: String) {
        config.activeModelId = modelId
        save()
    }

    func updateProvider(_ provider: AIProviderConfig, apiKey: String? = nil) {
        // Save API key to Keychain if provided
        if let apiKey = apiKey {
            AIKeychainStorage.shared.saveAPIKey(apiKey, for: provider.id)
        }

        if let index = config.providers.firstIndex(where: { $0.id == provider.id }) {
            config.providers[index] = provider
        } else {
            config.providers.append(provider)
        }
        save()
    }

    func removeProvider(_ providerId: String) {
        config.providers.removeAll { $0.id == providerId }
        config.models.removeAll { $0.providerId == providerId }
        if config.activeProviderId == providerId {
            config.activeProviderId = config.providers.first?.id
            config.activeModelId = nil
        }
        // Delete API key from Keychain
        AIKeychainStorage.shared.deleteAPIKey(for: providerId)
        save()
    }

    func addCustomProvider(name: String, baseURL: String, apiKey: String = "") {
        let provider = AIProviderConfig(
            displayName: name,
            providerType: .openAICompatible,
            apiKey: apiKey,
            baseURL: baseURL
        )
        config.providers.append(provider)
        save()
    }

    // MARK: - Model Management

    func addModel(_ model: AIModelConfig) {
        if !config.models.contains(where: { $0.id == model.id && $0.providerId == model.providerId }) {
            config.models.append(model)
            save()
        }
    }

    func addModelById(_ modelId: String, displayName: String?, providerId: String) {
        let name = displayName ?? modelId
        let model = AIModelConfig(
            id: modelId,
            displayName: name,
            providerId: providerId,
            isCustom: true,
            capabilities: AIModelCapabilities(toolCalling: true, streaming: true, webSearch: true)
        )
        addModel(model)
    }

    func removeModel(_ modelId: String, providerId: String) {
        config.models.removeAll { $0.id == modelId && $0.providerId == providerId }
        if config.activeModelId == modelId {
            config.activeModelId = config.models.first(where: { $0.providerId == providerId })?.id
        }
        save()
    }

    func modelsForProvider(_ providerId: String) -> [AIModelConfig] {
        config.models.filter { $0.providerId == providerId }
    }

    // MARK: - MCP Server Management

    func addMCPServer(_ server: MCPServerConfig) {
        config.mcpServers.append(server)
        save()
    }

    func updateMCPServer(_ server: MCPServerConfig) {
        if let index = config.mcpServers.firstIndex(where: { $0.id == server.id }) {
            config.mcpServers[index] = server
            save()
        }
    }

    func removeMCPServer(_ serverId: String) {
        config.mcpServers.removeAll { $0.id == serverId }
        save()
    }

    // MARK: - Fetch Dynamic Models

    func fetchOpenRouterModels(search: String? = nil) async {
        isFetchingModels = true
        defer { isFetchingModels = false }

        guard let provider = config.providers.first(where: { $0.providerType == .openRouter }),
              !provider.apiKey.isEmpty else { return }

        do {
            var urlString = "https://openrouter.ai/api/v1/models"
            if let search = search, !search.isEmpty {
                urlString += "?search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)"
            }
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15.0

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let modelsArray = json?["data"] as? [[String: Any]] else { return }

            var fetched: [AIModelConfig] = []
            for modelDict in modelsArray {
                guard let modelId = modelDict["id"] as? String,
                      let name = modelDict["name"] as? String else { continue }

                let contextLength = modelDict["context_length"] as? Int ?? 128_000
                let topProvider = modelDict["top_provider"] as? [String: Any]
                let maxOutput = topProvider?["max_completion_tokens"] as? Int ?? 4096

                let model = AIModelConfig(
                    id: modelId,
                    displayName: name,
                    providerId: provider.id,
                    capabilities: AIModelCapabilities(
                        toolCalling: true,
                        streaming: true,
                        webSearch: true,
                        contextWindow: contextLength,
                        maxOutput: maxOutput
                    )
                )
                fetched.append(model)
            }

            openRouterModels = fetched
        } catch {
            Self.log.error("Failed to fetch OpenRouter models: \(error.localizedDescription)")
        }
    }

    func fetchOllamaModels() async {
        isFetchingModels = true
        defer { isFetchingModels = false }

        guard let provider = config.providers.first(where: { $0.providerType == .ollama }) else { return }

        do {
            guard let url = URL(string: "\(provider.baseURL)/api/tags") else {
                ollamaModels = []
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5.0

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                ollamaModels = []
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let modelsArray = json?["models"] as? [[String: Any]] else {
                ollamaModels = []
                return
            }

            var fetched: [AIModelConfig] = []
            for modelDict in modelsArray {
                guard let name = modelDict["name"] as? String else { continue }
                let model = AIModelConfig(
                    id: name,
                    displayName: name,
                    providerId: provider.id,
                    capabilities: AIModelCapabilities(
                        toolCalling: true,
                        streaming: true,
                        webSearch: false
                    )
                )
                fetched.append(model)
            }

            ollamaModels = fetched.sorted { $0.displayName < $1.displayName }
        } catch {
            Self.log.error("Failed to fetch Ollama models: \(error.localizedDescription)")
            ollamaModels = []
        }
    }

    // MARK: - Default Configuration

    private static func createDefaultConfig() -> AIConfiguration {
        let geminiProvider = AIProviderConfig(
            id: "gemini",
            displayName: "Google Gemini",
            providerType: .gemini
        )
        let openRouterProvider = AIProviderConfig(
            id: "openrouter",
            displayName: "OpenRouter",
            providerType: .openRouter
        )
        let ollamaProvider = AIProviderConfig(
            id: "ollama",
            displayName: "Ollama (Local)",
            providerType: .ollama,
            baseURL: "http://localhost:11434"
        )

        return AIConfiguration(
            providers: [geminiProvider, openRouterProvider, ollamaProvider],
            models: [],
            activeProviderId: nil,
            activeModelId: nil,
            generationConfig: AIGenerationConfig(),
            mcpServers: [],
            browserToolsConfig: BrowserToolsConfig(executionMode: .askBeforeExecuting)
        )
    }

    // MARK: - On-Device Provider

    /// Lists Apple Intelligence first and makes it the active provider when nothing usable is chosen:
    /// no provider, no model, or a provider still missing its key. A working setup is left alone.
    private func addOnDeviceProvider() {
        let id = AppleIntelligenceProvider.providerId
        var changed = false
        if !config.providers.contains(where: { $0.id == id }) {
            config.providers.insert(AIProviderConfig(id: id, displayName: AIProviderType.appleIntelligence.displayName, providerType: .appleIntelligence), at: 0)
            changed = true
        }
        if !config.models.contains(where: { $0.id == AppleIntelligenceProvider.modelId }) {
            config.models.append(AIModelConfig(id: AppleIntelligenceProvider.modelId, displayName: "On-Device", providerId: id, capabilities: AIModelCapabilities(toolCalling: true)))
            changed = true
        }
        let usable = config.activeModelId != nil && activeProvider.map { !$0.providerType.requiresAPIKey || !$0.apiKey.isEmpty } == true
        if !usable, AppleIntelligenceProvider.isAvailable {
            config.activeProviderId = id
            config.activeModelId = AppleIntelligenceProvider.modelId
            changed = true
        }
        if changed { save() }
    }

    /// SHA-256 of the default system prompt before September 2026. A saved prompt that still matches
    /// it was never edited, so it moves to the current default; an edited one is left alone.
    private static let previousDefaultPromptHash = "711d0701b5580efd395aa9c85e233349b9d50e4ef3b60b937d6eef722ab978b9"

    private func replaceUneditedSystemPrompt() {
        let hash = SHA256.hash(data: Data(config.generationConfig.systemPrompt.utf8)).map { String(format: "%02x", $0) }.joined()
        guard hash == Self.previousDefaultPromptHash else { return }
        config.generationConfig.systemPrompt = AIGenerationConfig.defaultSystemPrompt
        save()
    }

    // MARK: - Migration from UserDefaults

    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "ai_config_migrated_v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        // Migrate API keys to Keychain and remove plaintext entries
        if let geminiKey = defaults.string(forKey: "settings.geminiApiKey"), !geminiKey.isEmpty {
            if AIKeychainStorage.shared.saveAPIKey(geminiKey, for: "gemini") {
                defaults.removeObject(forKey: "settings.geminiApiKey")
            }
        }

        if let openRouterKey = defaults.string(forKey: "settings.openRouterApiKey"), !openRouterKey.isEmpty {
            if AIKeychainStorage.shared.saveAPIKey(openRouterKey, for: "openrouter") {
                defaults.removeObject(forKey: "settings.openRouterApiKey")
            }
        }

        if let ollamaEndpoint = defaults.string(forKey: "settings.ollamaEndpoint"), !ollamaEndpoint.isEmpty {
            if let idx = config.providers.firstIndex(where: { $0.id == "ollama" }) {
                config.providers[idx].baseURL = ollamaEndpoint
            }
        }

        // Migrate active provider
        if let providerRaw = defaults.string(forKey: "settings.aiProvider") {
            switch providerRaw {
            case "gemini":
                config.activeProviderId = "gemini"
                if let modelRaw = defaults.string(forKey: "settings.geminiModel") {
                    config.activeModelId = modelRaw
                }
            case "openrouter":
                config.activeProviderId = "openrouter"
                if let modelRaw = defaults.string(forKey: "settings.openRouterModel") {
                    config.activeModelId = modelRaw
                }
            case "ollama":
                config.activeProviderId = "ollama"
                if let modelRaw = defaults.string(forKey: "settings.ollamaModel"), !modelRaw.isEmpty {
                    config.activeModelId = modelRaw
                }
            default:
                break
            }
        }

        // Migrate web search settings
        config.generationConfig.webSearchEnabled = defaults.bool(forKey: "settings.webSearchEnabled")
        if let engine = defaults.string(forKey: "settings.webSearchEngine") {
            config.generationConfig.webSearchEngine = engine
        }
        let maxResults = defaults.integer(forKey: "settings.webSearchMaxResults")
        if maxResults > 0 {
            config.generationConfig.webSearchMaxResults = maxResults
        }
        if let contextSize = defaults.string(forKey: "settings.webSearchContextSize") {
            config.generationConfig.webSearchContextSize = contextSize
        }

        defaults.set(true, forKey: migrationKey)
        save()
        Self.log.info("Migrated AI configuration from UserDefaults")
    }
}

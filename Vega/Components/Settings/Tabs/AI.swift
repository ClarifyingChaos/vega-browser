// Licensed under GPL-3.0. See LICENSE.
//
//  AI.swift
//  Vega
//
//  AI settings — flat Form layout matching other settings tabs
//

import VegaSettings
import SwiftUI
import VegaUI
import VegaDesign

struct SettingsAITab: View {
    @Environment(\.vegaSettings) var vegaSettings
    @Environment(AIConfigService.self) var configService
    @Environment(MCPManager.self) var mcpManager

    @State private var openRouterSearch: String = ""
    @State private var testingConnection: Bool = false
    @State private var providerToRemove: AIProviderConfig?
    // FORK: what is typed in each key field, so the field does not depend on the Keychain answering on every keystroke.
    @State private var keyDrafts: [String: String] = [:]
    @State private var keyErrors: [String: String] = [:]
    // FORK: one result per provider, so testing one does not mark the others.
    @State private var connectionTestResults: [String: String] = [:]
    @State private var newMCPServerName: String = ""
    @State private var newMCPServerCommand: String = ""
    @State private var newMCPServerArgs: String = ""
    @State private var showAddMCPServer: Bool = false
    @State private var showAddCustomProvider: Bool = false
    @State private var customProviderName: String = ""
    @State private var customProviderURL: String = ""
    @State private var customProviderKey: String = ""
    @State private var addModelId: String = ""
    @State private var showFetchedModels: Bool = false

    var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            SettingsHero(symbol: "sparkles", title: "AI", detail: "Tab organizer, providers and the assistant\u{2019}s tools.")

            Section {
                Toggle(isOn: $settings.showAIAssistant) {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                        Text("AI Assistant")
                            .font(VegaDesign.Font.body)
                        Text("Shows the chat button in the sidebar and toolbar")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Tab Organizer
            Section {
                if let note = TabOrganizationModel.unavailableNote {
                    Text(note)
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle(isOn: $settings.tabOrganizerEnabled) {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                            Text("Tab Organizer")
                                .font(VegaDesign.Font.body)
                            Text("Uses Apple Intelligence on this Mac to group, rename, sort, and deduplicate tabs")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settings.autoRenamePinnedTabs) {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                            Text("Rename Pinned Tabs")
                                .font(VegaDesign.Font.body)
                            Text("Shortens a tab's title when you pin it to a space")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $settings.linkPreviews) {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                            Text("Link Previews")
                                .font(VegaDesign.Font.body)
                            Text("Hold Shift while hovering a link to see a short summary of the page")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Tab Organizer")
            } footer: {
                if vegaSettings.tabOrganizerEnabled, TabOrganizationModel.unavailableNote == nil {
                    Text("Right-click a space or press \u{2318}\u{21E7}\u{2325}O to organize tabs")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // MARK: - Downloads
            Section {
                Toggle(isOn: $settings.tidyDownloads) {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                        Text("Tidy Downloads")
                            .font(VegaDesign.Font.body)
                        Text("Renames downloads with meaningless names, such as 387494876.pdf, after the page they came from")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(TabOrganizationModel.unavailableNote != nil)
                if let note = TabOrganizationModel.unavailableNote {
                    Text(note)
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Downloads")
            }

            // MARK: - Providers
            Section("Providers") {
                ForEach(configService.providers.filter { $0.providerType != .appleIntelligence || AppleIntelligenceProvider.isAvailable }) { provider in
                    providerRow(provider)
                        .padding(.vertical, VegaDesign.Spacing.md)
                }
                .confirmationDialog(
                    "Remove \(providerToRemove?.displayName ?? "provider")?",
                    isPresented: Binding(get: { providerToRemove != nil }, set: { if !$0 { providerToRemove = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive) {
                        if let provider = providerToRemove { configService.removeProvider(provider.id) }
                        providerToRemove = nil
                    }
                } message: {
                    Text("Its saved key and models are deleted too.")
                }

                if showAddCustomProvider {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
                        TextField("Provider Name", text: $customProviderName)
                        TextField("Base URL (e.g., http://localhost:1234/v1)", text: $customProviderURL)
                        SecureField("API Key (optional)", text: $customProviderKey)
                        HStack {
                            Button("Cancel") {
                                showAddCustomProvider = false
                                customProviderName = ""
                                customProviderURL = ""
                                customProviderKey = ""
                            }
                            Button("Add") {
                                configService.addCustomProvider(
                                    name: customProviderName,
                                    baseURL: customProviderURL,
                                    apiKey: customProviderKey
                                )
                                showAddCustomProvider = false
                                customProviderName = ""
                                customProviderURL = ""
                                customProviderKey = ""
                            }
                            .disabled(customProviderName.isEmpty || customProviderURL.isEmpty)
                        }
                    }
                } else {
                    Button(action: { showAddCustomProvider = true }) {
                        Label("Add Custom Provider", vegaIcon: "plus.circle")
                    }
                }
            }

            // MARK: - Models
            Section("Models") {
                if configService.models.isEmpty {
                    Text("No models added. Add a model by ID or fetch from a provider.")
                        .foregroundStyle(.secondary)
                        .font(VegaDesign.Font.secondary)
                }

                ForEach(configService.models.filter { $0.providerId != AppleIntelligenceProvider.providerId || AppleIntelligenceProvider.isAvailable }) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text(model.displayName)
                                .font(VegaDesign.Font.secondary)
                            Text(model.id)
                                .font(VegaDesign.Font.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        if configService.config.activeModelId == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(VegaDesign.Font.body)
                        }

                        Button(action: { configService.setActiveModel(model.id) }) {
                            Text(configService.config.activeModelId == model.id ? "Active" : "Use")
                                .font(VegaDesign.Font.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(configService.config.activeModelId == model.id)

                        Button(action: {
                            configService.removeModel(model.id, providerId: model.providerId)
                        }) {
                            VegaSymbol("trash", size: 14)
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // Add by ID
                HStack {
                    TextField("Add model by ID (e.g., gpt-4o)", text: $addModelId)
                        .textFieldStyle(.settings)
                        .font(VegaDesign.Font.secondary)
                    Button("Add") {
                        guard !addModelId.isEmpty,
                              let providerId = configService.config.activeProviderId else { return }
                        configService.addModelById(addModelId, displayName: nil, providerId: providerId)
                        addModelId = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(addModelId.isEmpty || configService.config.activeProviderId == nil)
                }

                // Fetch from provider
                if configService.activeProviderType == .openRouter {
                    DisclosureGroup("Fetch from OpenRouter", isExpanded: $showFetchedModels) {
                        HStack {
                            TextField("Search models...", text: $openRouterSearch)
                                .textFieldStyle(.settings)
                                .font(VegaDesign.Font.secondary)
                            Button("Fetch") {
                                Task {
                                    await configService.fetchOpenRouterModels(search: openRouterSearch.isEmpty ? nil : openRouterSearch)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(configService.isFetchingModels)
                        }

                        if configService.isFetchingModels {
                            HStack {
                                ProgressView().scaleEffect(0.7)
                                Text("Loading models...")
                                    .font(VegaDesign.Font.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(configService.openRouterModels.prefix(50)) { model in
                            fetchedModelRow(model)
                        }
                    }
                }

                if configService.activeProviderType == .ollama {
                    DisclosureGroup("Fetch from Ollama", isExpanded: $showFetchedModels) {
                        Button("Refresh") {
                            Task { await configService.fetchOllamaModels() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(configService.isFetchingModels)

                        if configService.isFetchingModels {
                            HStack {
                                ProgressView().scaleEffect(0.7)
                                Text("Loading models...")
                                    .font(VegaDesign.Font.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(configService.ollamaModels) { model in
                            fetchedModelRow(model)
                        }
                    }
                }
            }

            // MARK: - Generation
            Section("Generation") {
                // Temperature
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", configService.generationConfig.temperature))
                            .font(VegaDesign.Font.secondary.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { configService.generationConfig.temperature },
                            set: {
                                var config = configService.generationConfig
                                config.temperature = $0
                                configService.generationConfig = config
                            }
                        ),
                        in: 0...2,
                        step: 0.1
                    )
                    Text("Lower = more focused, Higher = more creative")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }

                // Max tokens
                HStack {
                    Text("Max Output Tokens")
                    Spacer()
                    TextField("4096", value: Binding(
                        get: { configService.generationConfig.maxTokens },
                        set: {
                            var config = configService.generationConfig
                            config.maxTokens = $0
                            configService.generationConfig = config
                        }
                    ), format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.settings)
                    .frame(width: VegaDesign.Size.fieldNarrow)
                }

                // System prompt
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xs) {
                    HStack {
                        Text("System Prompt")
                        Spacer()
                        Button("Reset to Default") {
                            var config = configService.generationConfig
                            config.systemPrompt = AIGenerationConfig.defaultSystemPrompt
                            configService.generationConfig = config
                        }
                        .font(VegaDesign.Font.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    TextEditor(text: Binding(
                        get: { configService.generationConfig.systemPrompt },
                        set: {
                            var config = configService.generationConfig
                            config.systemPrompt = $0
                            configService.generationConfig = config
                        }
                    ))
                    .font(VegaDesign.Font.secondary)
                    // FORK: the same filled, rounded surface as the other fields, not a square border.
                    .scrollContentBackground(.hidden)
                    .padding(VegaDesign.Spacing.md)
                    .frame(height: VegaDesign.Size.textEditorHeight)
                    .vegaControlSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.md))
                }

                // Streaming
                Toggle("Enable Streaming", isOn: Binding(
                    get: { configService.generationConfig.streamingEnabled },
                    set: {
                        var config = configService.generationConfig
                        config.streamingEnabled = $0
                        configService.generationConfig = config
                    }
                ))

                // Web search
                Toggle("Web Search", isOn: Binding(
                    get: { configService.generationConfig.webSearchEnabled },
                    set: {
                        var config = configService.generationConfig
                        config.webSearchEnabled = $0
                        configService.generationConfig = config
                    }
                ))

                if configService.generationConfig.webSearchEnabled {
                    Picker("Engine", selection: Binding(
                        get: { configService.generationConfig.webSearchEngine },
                        set: {
                            var config = configService.generationConfig
                            config.webSearchEngine = $0
                            configService.generationConfig = config
                        }
                    )) {
                        Text("Auto").tag("auto")
                        Text("Native").tag("native")
                        Text("Exa").tag("exa")
                    }
                    .pickerStyle(.menu)

                    Picker("Context Size", selection: Binding(
                        get: { configService.generationConfig.webSearchContextSize },
                        set: {
                            var config = configService.generationConfig
                            config.webSearchContextSize = $0
                            configService.generationConfig = config
                        }
                    )) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                    .pickerStyle(.menu)

                    Picker("Max Results", selection: Binding(
                        get: { configService.generationConfig.webSearchMaxResults },
                        set: {
                            var config = configService.generationConfig
                            config.webSearchMaxResults = $0
                            configService.generationConfig = config
                        }
                    )) {
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                    }
                    .pickerStyle(.menu)
                }
            }

            // MARK: - Browser Tools
            Section("Browser Tools") {
                Picker("Execution Mode", selection: Binding(
                    get: { configService.browserToolsConfig.executionMode },
                    set: {
                        var config = configService.browserToolsConfig
                        config.executionMode = $0
                        configService.browserToolsConfig = config
                    }
                )) {
                    ForEach(BrowserToolExecutionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                // FORK: forty raw tool names behind one disclosure; most people never touch them.
                DisclosureGroup("Individual Tools") {
                    ForEach(Array(BrowserToolsConfig.allToolNames.sorted()), id: \.self) { toolName in
                        Toggle(isOn: Binding(
                            get: { configService.browserToolsConfig.enabledTools.contains(toolName) },
                            set: { enabled in
                                var config = configService.browserToolsConfig
                                if enabled {
                                    config.enabledTools.insert(toolName)
                                } else {
                                    config.enabledTools.remove(toolName)
                                }
                                configService.browserToolsConfig = config
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(toolName)
                                    .font(VegaDesign.Font.secondary)
                                if let tool = BrowserTools.toolsByName[toolName] {
                                    Text(tool.description)
                                        .font(VegaDesign.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - MCP Servers
            Section("MCP Servers") {
                if configService.mcpServers.isEmpty && !showAddMCPServer {
                    VStack(spacing: VegaDesign.Spacing.md) {
                        VegaSymbol("puzzlepiece.extension", size: 25)
                            .font(VegaDesign.Font.titleLarge)
                            .foregroundStyle(.secondary)
                        Text("No MCP servers configured")
                            .font(VegaDesign.Font.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VegaDesign.Spacing.lg)
                }

                ForEach(configService.mcpServers) { server in
                    mcpServerRow(server)
                }

                if showAddMCPServer {
                    addMCPServerForm
                } else {
                    Button(action: { showAddMCPServer = true }) {
                        Label("Add Server", vegaIcon: "plus.circle")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 52) // FORK: rows with a description need the room
    }

    // MARK: - Provider Row

    @ViewBuilder
    private func providerRow(_ provider: AIProviderConfig) -> some View {
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                    HStack(spacing: VegaDesign.Spacing.sm) {
                        Text(provider.displayName)
                            .font(VegaDesign.Font.label)

                        if configService.config.activeProviderId == provider.id {
                            Text("Active")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.green)
                                .padding(.horizontal, VegaDesign.Spacing.sm)
                                .padding(.vertical, VegaDesign.Spacing.xxs)
                                .background(VegaDesign.Radius.shape(VegaDesign.Radius.xs).fill(.green.opacity(0.15)))
                        }
                    }

                    // FORK: no second line that only repeats the name above it.
                    if provider.providerType.displayName != provider.displayName {
                        Text(provider.providerType.displayName)
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { newValue in
                        var updated = provider
                        updated.isEnabled = newValue
                        configService.updateProvider(updated)
                    }
                ))

                if configService.config.activeProviderId != provider.id {
                    Button("Use") {
                        configService.setActiveProvider(provider.id)
                    }
                    .font(VegaDesign.Font.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // FORK: any provider but the built-in on-device one can be removed, with its key and models.
                if provider.providerType != .appleIntelligence {
                    Button("Remove", role: .destructive) { providerToRemove = provider }
                        .font(VegaDesign.Font.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            // FORK: a custom provider can take a key later too, not only when it is added.
            if provider.providerType.requiresAPIKey || provider.providerType == .openAICompatible {
                HStack(spacing: VegaDesign.Spacing.md) {
                    SecureField("API Key", text: Binding(
                        get: { keyDrafts[provider.id] ?? provider.apiKey },
                        set: { newValue in
                            keyDrafts[provider.id] = newValue
                            configService.updateProvider(provider, apiKey: newValue)
                            keyErrors[provider.id] = AIKeychainStorage.shared.apiKey(for: provider.id) == newValue || newValue.isEmpty
                                ? nil : "Could not save the key to the Keychain."
                        }
                    ))
                    .textFieldStyle(.settings)
                    .font(VegaDesign.Font.secondary)

                    if !(keyDrafts[provider.id] ?? provider.apiKey).isEmpty {
                        Button("Test") {
                            testConnection(provider)
                        }
                        .font(VegaDesign.Font.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(testingConnection)
                    }
                }
            }

            if provider.providerType == .ollama || provider.providerType == .openAICompatible {
                TextField("Base URL", text: Binding(
                    get: { provider.baseURL },
                    set: { newValue in
                        var updated = provider
                        updated.baseURL = newValue
                        configService.updateProvider(updated)
                    }
                ))
                .textFieldStyle(.settings)
                .font(VegaDesign.Font.secondary)

                HStack(spacing: VegaDesign.Spacing.md) {
                    if provider.providerType == .ollama {
                        Button("Test") { testConnection(provider) }
                            .font(VegaDesign.Font.caption).buttonStyle(.bordered).controlSize(.small).disabled(testingConnection)
                    }
                    if provider.providerType == .openAICompatible {
                        Button("Fetch Models") {
                            connectionTestResults[provider.id] = "Fetching models…"
                            Task { connectionTestResults[provider.id] = await configService.fetchModels(for: provider) }
                        }
                        .font(VegaDesign.Font.caption).buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            if let error = keyErrors[provider.id] {
                Text(error).font(VegaDesign.Font.caption).foregroundStyle(.red)
            }

            if let result = connectionTestResults[provider.id] {
                Text(result)
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(result.hasPrefix("Success") ? .green : (result.hasPrefix("Failed") ? .red : .secondary))
            }
        }
    }

    // MARK: - Fetched Model Row

    @ViewBuilder
    private func fetchedModelRow(_ model: AIModelConfig) -> some View {
        let alreadyAdded = configService.models.contains { $0.id == model.id && $0.providerId == model.providerId }
        HStack {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                Text(model.displayName)
                    .font(VegaDesign.Font.secondary)
                Text(model.id)
                    .font(VegaDesign.Font.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if alreadyAdded {
                Text("Added")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Add") {
                    configService.addModel(model)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - MCP Server Row

    @ViewBuilder
    private func mcpServerRow(_ server: MCPServerConfig) -> some View {
        let state = mcpManager.connectionState(for: server.id)
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                    Text(server.name)
                        .font(VegaDesign.Font.label)

                    switch server.transport {
                    case .stdio(let cmd, let args):
                        Text("\(cmd) \(args.joined(separator: " "))")
                            .font(VegaDesign.Font.caption.monospaced())
                            .foregroundStyle(.secondary)
                    case .sse(let url):
                        Text(url)
                            .font(VegaDesign.Font.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: VegaDesign.Spacing.xs) {
                    Circle()
                        .fill(stateColor(state))
                        .frame(width: VegaDesign.Size.statusDot, height: VegaDesign.Size.statusDot)
                    Text(state.displayName)
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("", isOn: Binding(
                    get: { server.isEnabled },
                    set: { newValue in
                        var updated = server
                        updated.isEnabled = newValue
                        configService.updateMCPServer(updated)
                        if newValue {
                            mcpManager.connectServer(updated)
                        } else {
                            mcpManager.disconnectServer(server.id)
                        }
                    }
                ))

                Button(action: { mcpManager.reconnectServer(server) }) {
                    VegaSymbol("arrow.clockwise", size: 14)
                        .font(VegaDesign.Font.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    configService.removeMCPServer(server.id)
                    mcpManager.disconnectServer(server.id)
                }) {
                    VegaSymbol("trash", size: 14)
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            if state.isConnected {
                let tools = mcpManager.allTools.filter { $0.serverId == server.id }
                if !tools.isEmpty {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                        Text("Discovered Tools (\(tools.count))")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)

                        ForEach(tools) { tool in
                            HStack(spacing: VegaDesign.Spacing.xs) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(VegaDesign.Font.caption)
                                    .foregroundStyle(.secondary)
                                Text(tool.name)
                                    .font(VegaDesign.Font.caption.monospaced())
                                Text("- \(tool.description)")
                                    .font(VegaDesign.Font.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Add MCP Server Form

    @ViewBuilder
    private var addMCPServerForm: some View {
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
            TextField("Server Name", text: $newMCPServerName)
            TextField("Command (e.g., /usr/local/bin/mcp-server)", text: $newMCPServerCommand)
            TextField("Arguments (space-separated)", text: $newMCPServerArgs)

            HStack {
                Button("Cancel") {
                    showAddMCPServer = false
                    newMCPServerName = ""
                    newMCPServerCommand = ""
                    newMCPServerArgs = ""
                }
                Button("Add") {
                    let args = newMCPServerArgs.split(separator: " ").map(String.init)
                    let server = MCPServerConfig(
                        name: newMCPServerName,
                        transport: .stdio(command: newMCPServerCommand, args: args)
                    )
                    configService.addMCPServer(server)
                    mcpManager.connectServer(server)
                    showAddMCPServer = false
                    newMCPServerName = ""
                    newMCPServerCommand = ""
                    newMCPServerArgs = ""
                }
                .disabled(newMCPServerName.isEmpty || newMCPServerCommand.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func testConnection(_ provider: AIProviderConfig) {
        testingConnection = true
        connectionTestResults[provider.id] = nil
        let key = keyDrafts[provider.id] ?? provider.apiKey

        Task {
            defer { testingConnection = false }
            // The address that answers for this kind of provider, and how it wants the key.
            var path = "/models"
            var header: (String, String)?
            switch provider.providerType {
            case .appleIntelligence:
                connectionTestResults[provider.id] = AppleIntelligenceProvider.isAvailable ? "Success: On-device model is ready" : "Failed: Apple Intelligence is not available"
                return
            case .gemini: header = ("x-goog-api-key", key)   // in a header; in the URL it would reach logs and proxies
            case .openRouter: header = ("Authorization", "Bearer \(key)")
            case .ollama: path = "/api/tags"
            case .openAICompatible: if !key.isEmpty { header = ("Authorization", "Bearer \(key)") }
            }
            guard let url = URL(string: provider.baseURL + path), url.scheme != nil else {
                connectionTestResults[provider.id] = "Failed: the Base URL is not valid"
                return
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            if let header { request.setValue(header.1, forHTTPHeaderField: header.0) }
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    connectionTestResults[provider.id] = provider.providerType == .ollama ? "Success: Ollama is running" : "Success: Connection verified"
                } else if let http = response as? HTTPURLResponse {
                    connectionTestResults[provider.id] = "Failed: \(AIConfigService.reason(http.statusCode))"
                } else {
                    connectionTestResults[provider.id] = "Failed: no response"
                }
            } catch {
                connectionTestResults[provider.id] = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func stateColor(_ state: MCPConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}

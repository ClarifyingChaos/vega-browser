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
    // FORK: the fetched-models picker: a search per provider, and which model is being checked.
    @State private var modelSearch: [String: String] = [:]
    @State private var checkingModels: Set<String> = []
    @State private var enablingAll: Set<String> = []
    @State private var modelPickErrors: [String: String] = [:]
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

            // MARK: - Assistant
            Section {
                toggleRow("AI Assistant", "Shows the chat button in the sidebar and toolbar", isOn: $settings.showAIAssistant)

                // FORK: where the chat opens. Either way it stays on the right and leaves the tab sidebar alone.
                // A pull-down, not a pop-up: a pop-up opens its list over the selected item, covering the control.
                HStack(alignment: .center) {
                    rowLabel("Chat Position", "Floating keeps the page at full width; drag the card by its top edge")
                    Spacer(minLength: VegaDesign.Spacing.lg)
                    Menu {
                        // Plain buttons: the control's own label already names the current choice. Toggles here
                        // drew dim and did nothing.
                        Button("Sidebar") { settings.aiChatFloating = false }
                        Button("Floating") { settings.aiChatFloating = true }
                    } label: {
                        Text(settings.aiChatFloating ? "Floating" : "Sidebar")
                    }
                    .menuStyle(.button)
                    .fixedSize()
                    .disabled(!settings.showAIAssistant)
                    .accessibilityLabel("Chat Position")
                }
            } header: {
                Text("Assistant")
            }

            // MARK: - On this Mac
            // Tab Organizer, pinned-tab names, link previews and download names all run on Apple Intelligence, so
            // they share one section and one note when it is not available.
            Section {
                toggleRow("Tab Organizer", "Group, rename, sort and deduplicate tabs", isOn: $settings.tabOrganizerEnabled)
                toggleRow("Rename Pinned Tabs", "Shortens a tab\u{2019}s title when you pin it to a space", isOn: $settings.autoRenamePinnedTabs)
                toggleRow("Link Previews", "Hold Shift while hovering a link to see a short summary", isOn: $settings.linkPreviews)
                toggleRow("Tidy Downloads", "Names files like 387494876.pdf after the page they came from", isOn: $settings.tidyDownloads)
            } header: {
                Text("On This Mac")
            } footer: {
                if let note = TabOrganizationModel.unavailableNote {
                    Text(note)
                } else {
                    Text("Runs with Apple Intelligence on this Mac. Right-click a space or press \u{2318}\u{21E7}\u{2325}O to organize tabs.")
                }
            }
            .disabled(TabOrganizationModel.unavailableNote != nil)

            // MARK: - Providers
            Section {
                ForEach(configService.providers.filter { $0.providerType != .appleIntelligence || AppleIntelligenceProvider.isAvailable }) { provider in
                    providerRow(provider)
                        .padding(.vertical, VegaDesign.Spacing.md)
                }
                .vegaConfirm("Remove \(providerToRemove?.displayName ?? "provider")?", message: "Its saved key and models are deleted too.",
                             confirm: "Remove", isPresented: Binding(get: { providerToRemove != nil }, set: { if !$0 { providerToRemove = nil } })) {
                    if let provider = providerToRemove { configService.removeProvider(provider.id) }
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
            } header: {
                Text("Providers")
            } footer: {
                Text("Private windows never send a page to a provider, whatever you choose here.")
            }

            // MARK: - Models
            Section("Models") {
                if configService.models.isEmpty {
                    Text("No models added. Add a model by ID or fetch from a provider.")
                        .foregroundStyle(.secondary)
                        .font(VegaDesign.Font.secondary)
                }

                ForEach(configService.models.filter { $0.providerId != AppleIntelligenceProvider.providerId || AppleIntelligenceProvider.isAvailable }) { model in
                    let isActive = configService.config.activeModelId == model.id
                    HStack(spacing: VegaDesign.Spacing.md) {
                        // The model you chat with: pick one, as in a list of radio choices.
                        Button { configService.setActiveModel(model.id) } label: {
                            HStack(spacing: VegaDesign.Spacing.md) {
                                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary.opacity(0.6))
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                                    Text(model.displayName)
                                    Text(model.id)
                                        .font(VegaDesign.Font.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(model.displayName)\(isActive ? ", active" : "")")
                        .accessibilityHint("Use this model for the chat")

                        Menu {
                            Button("Use This Model", systemImage: "checkmark.circle") { configService.setActiveModel(model.id) }
                                .disabled(isActive)
                            Divider()
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                configService.removeModel(model.id, providerId: model.providerId)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .menuStyle(.button)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .accessibilityLabel("More for \(model.displayName)")
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
                LabeledContent {
                    HStack(spacing: VegaDesign.Spacing.md) {
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
                        .frame(width: 180)
                        .accessibilityLabel("Temperature")
                        Text(String(format: "%.1f", configService.generationConfig.temperature))
                            .font(VegaDesign.Font.secondary.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                } label: {
                    rowLabel("Temperature", "Lower is more focused, higher is more creative")
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
                    .font(VegaDesign.Font.secondary.weight(.regular))
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

    // MARK: - Rows

    /// A title with its one-line explanation under it: the pattern of System Settings.
    private func rowLabel(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(VegaDesign.Font.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Label block on the left, switch centred against both lines on the right.
    private func toggleRow(_ title: String, _ detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            rowLabel(title, detail)
            Spacer(minLength: VegaDesign.Spacing.lg)
            Toggle(title, isOn: isOn).labelsHidden()
        }
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

                Toggle("Enabled", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { newValue in
                        var updated = provider
                        updated.isEnabled = newValue
                        configService.updateProvider(updated)
                    }
                ))
                .labelsHidden()

                // Use and Remove live in a menu, as in System Settings, so the row keeps one control and a toggle.
                Menu {
                    if configService.config.activeProviderId != provider.id {
                        Button("Use This Provider", systemImage: "checkmark.circle") { configService.setActiveProvider(provider.id) }
                    }
                    // FORK: any provider but the built-in on-device one can be removed, with its key and models.
                    if provider.providerType != .appleIntelligence {
                        Button("Remove\u{2026}", systemImage: "trash", role: .destructive) { providerToRemove = provider }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More for \(provider.displayName)")
            }

            // FORK: a custom provider can take a key later too, not only when it is added.
            if provider.providerType.requiresAPIKey || provider.providerType == .openAICompatible {
                HStack(spacing: VegaDesign.Spacing.md) {
                    // FORK: typing only changes the draft. Saving on every keystroke rebuilt the whole page and
                    // dropped the field's focus after one character, so only pasting a key worked.
                    SecureField("API Key", text: Binding(
                        get: { keyDrafts[provider.id] ?? provider.apiKey },
                        set: { keyDrafts[provider.id] = $0; keyErrors[provider.id] = nil }
                    ))
                    .textFieldStyle(.settings)
                    .font(VegaDesign.Font.secondary)
                    .onSubmit { saveKey(provider) }

                    if let draft = keyDrafts[provider.id], draft != provider.apiKey {
                        Button("Save") { saveKey(provider) }
                            .font(VegaDesign.Font.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }

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
                // A key typed and not saved is saved when the page closes.
                .onDisappear { saveKey(provider) }
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

            // Gemini and OpenRouter list their models too, once they have a key.
            if provider.providerType != .appleIntelligence {
                Toggle(isOn: Binding(
                    get: { provider.sendsPageContent },
                    set: { on in var updated = provider; updated.sendsPageContent = on; configService.updateProvider(updated) }
                )) {
                    VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                        Text("Send the page to this provider").font(VegaDesign.Font.secondary)
                        Text("Off, it answers from your question alone.")
                            .font(VegaDesign.Font.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if provider.providerType == .gemini || provider.providerType == .openRouter {
                Button("Fetch Models") {
                    saveKey(provider)
                    connectionTestResults[provider.id] = "Fetching models…"
                    Task { connectionTestResults[provider.id] = await configService.fetchModels(for: provider) }
                }
                .font(VegaDesign.Font.caption).buttonStyle(.bordered).controlSize(.small)
                .disabled((keyDrafts[provider.id] ?? provider.apiKey).isEmpty)
            }

            if provider.providerType != .ollama, provider.providerType != .appleIntelligence, let listed = configService.fetchedModels[provider.id], !listed.isEmpty {
                fetchedModelPicker(provider, listed: listed)
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

    // MARK: - Fetched models picker

    /// What a custom provider offers, with a switch per model: on means it shows in the chat's model list.
    /// A model is checked with a one-token request before it is switched on.
    @ViewBuilder
    private func fetchedModelPicker(_ provider: AIProviderConfig, listed: [AIModelConfig]) -> some View {
        let needle = (modelSearch[provider.id] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let shown = needle.isEmpty ? listed : listed.filter { $0.id.lowercased().contains(needle) }
        VStack(alignment: .leading, spacing: VegaDesign.Spacing.sm) {
            HStack {
                Text("Choose which models appear in the chat")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if provider.providerType == .gemini {
                    Button(enablingAll.contains(provider.id) ? "Checking…" : "Turn on working models") {
                        enablingAll.insert(provider.id)
                        Task {
                            connectionTestResults[provider.id] = await configService.enableWorkingModels(for: provider)
                            enablingAll.remove(provider.id)
                        }
                    }
                    .font(VegaDesign.Font.caption).buttonStyle(.bordered).controlSize(.small)
                    .disabled(enablingAll.contains(provider.id))
                }
            }
            TextField("Search \(listed.count) models", text: Binding(get: { modelSearch[provider.id] ?? "" }, set: { modelSearch[provider.id] = $0 }))
                .textFieldStyle(.settings)
                .font(VegaDesign.Font.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(shown.prefix(200)) { model in
                        let key = provider.id + "/" + model.id
                        HStack(spacing: VegaDesign.Spacing.sm) {
                            Text(model.id)
                                .font(VegaDesign.Font.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            if checkingModels.contains(key) { ProgressView().controlSize(.small) }
                            Toggle("", isOn: Binding(
                                get: { configService.models.contains { $0.id == model.id && $0.providerId == provider.id } },
                                set: { on in
                                    modelPickErrors[provider.id] = nil
                                    if !on { configService.removeModel(model.id, providerId: provider.id); return }
                                    checkingModels.insert(key)
                                    Task {
                                        let problem = await configService.verifyModel(model.id, for: provider)
                                        checkingModels.remove(key)
                                        if let problem { modelPickErrors[provider.id] = "\(model.id) was not added: \(problem)"; return }
                                        configService.addModel(model)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .controlSize(.small)
                            .disabled(checkingModels.contains(key))
                        }
                        .padding(.vertical, 4)
                    }
                    if shown.count > 200 {
                        Text("Showing 200 of \(shown.count). Search to narrow the list.")
                            .font(VegaDesign.Font.caption).foregroundStyle(.secondary).padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 240)
            if let error = modelPickErrors[provider.id] {
                Text(error).font(VegaDesign.Font.caption).foregroundStyle(.red)
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

    /// Files the typed key in the Keychain and says so if that fails.
    private func saveKey(_ provider: AIProviderConfig) {
        guard let draft = keyDrafts[provider.id],
              configService.providers.contains(where: { $0.id == provider.id }),
              draft != provider.apiKey else { return }
        configService.updateProvider(provider, apiKey: draft)
        keyErrors[provider.id] = AIKeychainStorage.shared.apiKey(for: provider.id) == draft || draft.isEmpty
            ? nil : "Could not save the key to the Keychain."
        if keyErrors[provider.id] == nil { keyDrafts[provider.id] = nil }
    }

    private func testConnection(_ provider: AIProviderConfig) {
        saveKey(provider)
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
            guard AIConfigService.isSafeAddress(provider.baseURL) || provider.providerType == .ollama else {
                connectionTestResults[provider.id] = "Failed: \(AIConfigService.insecureMessage)"
                return
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

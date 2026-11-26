// Licensed under GPL-3.0. See LICENSE.
//
//  SearchEngines.swift
//  NookUI
//
//  FORK: Settings > General > Search as one list to pick from, and the Add Search Engine sheet.
//

import SwiftUI
import NookDesign
import NookSettings

/// Every engine as a row to choose, the built-in ones first.
struct SearchEngineList: View {
    @Environment(NookSettingsService.self) private var settings

    /// Engines that say they keep no search profile of a person.
    private static let privacyFocused: Set<SearchProvider> = [.duckDuckGo, .brave, .kagi]

    var body: some View {
        ForEach(SearchProvider.allCases) { provider in
            row(provider.rawValue, name: provider.displayName, detail: provider.host,
                tag: Self.privacyFocused.contains(provider) ? "Privacy focused" : nil)
        }
        ForEach(settings.customSearchEngines) { engine in
            HStack(spacing: NookDesign.Spacing.md) {
                row(engine.id.uuidString, name: engine.name, detail: URL(string: engine.urlTemplate.replacingOccurrences(of: "%@", with: ""))?.host ?? engine.urlTemplate,
                    // Saved by a version that did not check the address.
                    tag: engine.urlTemplate.lowercased().hasPrefix("https://") ? nil : "Not encrypted", warns: true)
                Button {
                    if settings.searchEngineId == engine.id.uuidString { settings.searchEngineId = SearchProvider.duckDuckGo.rawValue }
                    settings.customSearchEngines.removeAll { $0.id == engine.id }
                } label: {
                    NookSymbol("trash", size: 17)
                }
                .buttonStyle(.borderless)
                .help("Remove \(engine.name)")
                .accessibilityLabel("Remove \(engine.name)")
            }
        }
    }

    private func row(_ id: String, name: String, detail: String, tag: String?, warns: Bool = false) -> some View {
        let chosen = settings.searchEngineId == id
        return Button {
            settings.searchEngineId = id
        } label: {
            HStack(spacing: NookDesign.Spacing.lg) {
                Text(name.prefix(1).uppercased())
                    .font(NookDesign.Font.secondary.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .background(NookDesign.Radius.shape(NookDesign.Radius.sm).fill(.quaternary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                    HStack(spacing: NookDesign.Spacing.sm) {
                        Text(name)
                        if let tag {
                            Text(tag)
                                .font(NookDesign.Font.micro)
                                .foregroundStyle(warns ? Color.orange : Color.green)
                                .padding(.horizontal, NookDesign.Spacing.sm)
                                .padding(.vertical, NookDesign.Spacing.xxs)
                                .background(Capsule().fill((warns ? Color.orange : Color.green).opacity(NookDesign.Surface.tintOpacity)))
                        }
                    }
                    Text(detail).font(NookDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: chosen ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(chosen ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Add Search Engine

struct CustomSearchEngineEditor: View {
    let onSave: (CustomSearchEngine) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var template: Result<String, CustomSearchEngine.TemplateError> { CustomSearchEngine.template(from: address) }

    var body: some View {
        VStack(alignment: .leading, spacing: NookDesign.Spacing.lg) {
            Text("Add Search Engine")
                .font(NookDesign.Font.heading)

            Text("Popular").font(NookDesign.Font.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: NookDesign.Spacing.md)], alignment: .leading, spacing: NookDesign.Spacing.md) {
                ForEach(CustomSearchEngine.popular, id: \.name) { engine in
                    let chosen = address == engine.template
                    Button {
                        name = engine.name
                        address = engine.template
                    } label: {
                        Text(engine.name)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, NookDesign.Spacing.sm)
                            .background(Capsule().fill(chosen ? AnyShapeStyle(Color.accentColor.opacity(NookDesign.Surface.tintOpacity)) : AnyShapeStyle(.quaternary)))
                            .overlay(Capsule().strokeBorder(chosen ? Color.accentColor : .clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }

            field("Name", text: $name, prompt: "Startpage")
            field("Search address", text: $address, prompt: "https://example.com/search?q=%s")
                .autocorrectionDisabled()
            Text("Put %s (or %@) where your search words go.")
                .font(NookDesign.Font.caption)
                .foregroundStyle(.secondary)

            if !address.isEmpty {
                switch template {
                case .success(let value):
                    Text("Preview: \(value.replacingOccurrences(of: "%@", with: "vega%20browser"))")
                        .font(NookDesign.Font.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                case .failure(let error):
                    HStack(spacing: NookDesign.Spacing.sm) {
                        NookSymbol("exclamationmark.triangle", size: 16)
                        Text(error.rawValue)
                    }
                    .font(NookDesign.Font.caption)
                    .foregroundStyle(.orange)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.bordered)
                Button("Add") {
                    guard case .success(let value) = template else { return }
                    onSave(CustomSearchEngine(name: trimmedName, urlTemplate: value))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty || (try? template.get()) == nil)
            }
        }
        .padding(NookDesign.Spacing.xxl)
        .frame(width: NookDesign.Size.sheetSmallWidth)
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: NookDesign.Spacing.xs) {
            Text(title).font(NookDesign.Font.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(title, text: text, prompt: Text(verbatim: prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        }
    }
}

//
//  SpaceCreationDialog.swift
//  Vega
//
//  Created by Maciek Bagiński on 04/08/2025.
//

import AppKit
import SwiftUI

struct SpaceCreationDialog: DialogPresentable {
    @State private var spaceName: String
    @State private var spaceIcon: String
    @State private var accentHex: String = SpaceAccent.defaultHex

    let onCreate: (String, String, String) -> Void
    let onCancel: () -> Void

    init(
        onCreate: @escaping (String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _spaceName = State(initialValue: "")
        _spaceIcon = State(initialValue: "")
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    func dialogHeader() -> DialogHeader {
        DialogHeader(
            icon: "folder.badge.plus",
            title: "Create a New Space",
            subtitle: "Organize your tabs into a new space"
        )
    }

    @ViewBuilder
    func dialogContent() -> some View {
        SpaceCreationContent(
            spaceName: $spaceName,
            spaceIcon: $spaceIcon,
            accentHex: $accentHex
        )
    }

    func dialogFooter() -> DialogFooter {
        DialogFooter(
            rightButtons: [
                DialogButton(
                    text: "Cancel",
                    variant: .secondary,
                    keyboardShortcut: .escape,
                    action: onCancel
                ),
                DialogButton(
                    text: "Create Space",
                    iconName: "plus",
                    variant: .primary,
                    keyboardShortcut: .return,
                    action: handleCreate
                )
            ]
        )
    }

    private func handleCreate() {
        let trimmedName = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(trimmedName, spaceIcon, accentHex)
    }
}

struct SpaceCreationContent: View {
    @Binding var spaceName: String
    @Binding var spaceIcon: String
    @Binding var accentHex: String
    @State private var showIconPicker = false
    @EnvironmentObject var browserManager: BrowserManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Space Name")
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.primary)

                VegaTextField(
                    text: $spaceName,
                    placeholder: "Enter space name",
                    variant: .default,
                    iconName: "textformat"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Space Icon")
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Button {
                        showIconPicker = true
                    } label: {
                        SpaceIconView(icon: spaceIcon, tint: .primary)
                            .padding(4)
                            .background(.white.opacity(0.2))
                            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    }
                    .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showIconPicker) {
                        SpaceIconPicker(selected: spaceIcon, onPick: {
                            spaceIcon = $0
                            showIconPicker = false
                        })
                    }

                    Text("Choose an icon to represent this space")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            VStack(alignment: .leading, spacing: VegaDesign.Spacing.sectionGap) {
                Text("Accent")
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.primary)
                SpaceAccentPicker(selectedHex: $accentHex)
            }

        }
        .padding(.horizontal, 4)
    }

}


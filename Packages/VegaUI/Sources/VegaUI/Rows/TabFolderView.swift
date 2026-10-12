// Licensed under GPL-3.0. See LICENSE.
//
//  TabFolderView.swift
//  Vega
//
//  Created by Jonathan Caudill on 2025-09-24.
//

import VegaTabsCore
import SwiftUI
import VegaDesign
import VegaWeb

/// A folder header row in the sidebar outline. Its children are separate rows below it.
public struct TabFolderView: View {
    let item: Item
    let spaceID: UUID
    /// True while a drag would drop into this folder.
    var isDropTarget: Bool = false

    @State private var isHovering: Bool = false
    @State private var draftName: String = ""
    @FocusState private var nameFieldFocused: Bool

    @Environment(BrowserWindowState.self) private var windowState
    private let renameState = SidebarRenameState.shared

    @Environment(TabsController.self) private var tabs
    private var isOpen: Bool { tabs.isOpen(folder: item.id) }
    private var isRenaming: Bool { renameState.itemID == item.id }

    public init(
        item: Item,
        spaceID: UUID,
        isDropTarget: Bool = false
    ) {
        self.item = item
        self.spaceID = spaceID
        self.isDropTarget = isDropTarget
    }

    public var body: some View {
        Button(action: {
            withAnimation(VegaDesign.Motion.spring) {
                tabs.toggleFolder(item.id)
            }
        }) {
            HStack(spacing: VegaDesign.Spacing.md) {
                Image(systemName: "chevron.right")
                    .font(.system(size: VegaDesign.Size.rowGlyph - 1, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .animation(VegaDesign.Motion.standard, value: isOpen)

                Image(systemName: item.live != nil ? "arrow.triangle.pull" : (isOpen ? "folder.fill" : "folder"))
                    .font(.system(size: VegaDesign.Size.spaceIcon, weight: .medium))
                    .foregroundStyle(tabs.space(spaceID)?.accentColor ?? .secondary)

                if isRenaming {
                    TextField("", text: $draftName)
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(.primary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocorrectionDisabled()
                        .focused($nameFieldFocused)
                        .onAppear {
                            draftName = item.displayTitle
                            DispatchQueue.main.async { nameFieldFocused = true }
                        }
                        .onSubmit { commitRename() }
                        .onEscapeKey { cancelRename() }
                } else {
                    Text(item.displayTitle)
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: VegaDesign.Spacing.xs)

                if let status = tabs.liveStatus[item.id] {
                    Image(systemName: "exclamationmark.triangle")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                        .help(status == .signedOut ? "Sign in to GitHub" : "Couldn't load pull requests")
                }

                if !isHovering {
                    Text("\(tabs.children(of: .folder(itemID: item.id)).count)")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.tertiary)
                }

                if isHovering && !isRenaming {
                    Menu {
                        folderMenu
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                    .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton, radius: VegaDesign.Radius.sm))
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(height: VegaDesign.Size.row)
            .frame(maxWidth: .infinity)
            .background(
                VegaDesign.Radius.shape(VegaDesign.Radius.md)
                    .fill(isDropTarget ? VegaDesign.Surface.fillPressed : (isHovering ? VegaDesign.Surface.fill : Color.clear))
            )
            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) {
                isHovering = hovering
            }
        }
        .contextMenu {
            folderMenu
                .environment(windowState)
                .environment(tabs)
        }
        .onChange(of: nameFieldFocused) { _, focused in
            if isRenaming && !focused { commitRename() }
        }
    }

    private var folderMenu: some View {
        FolderContextMenu(itemID: item.id, onRename: startRenaming)
    }

    // MARK: - Rename

    private func startRenaming() {
        draftName = item.displayTitle
        renameState.itemID = item.id
    }

    private func cancelRename() {
        renameState.itemID = nil
        nameFieldFocused = false
    }

    private func commitRename() {
        guard isRenaming else { return }
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty && newName != item.displayTitle {
            tabs.rename(item.id, newName)
        }
        cancelRename()
    }
}

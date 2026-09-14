//
//  TabFolderView.swift
//  Vega
//
//  Created by Jonathan Caudill on 2025-09-24.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct TabFolderView: View {
    @ObservedObject var folder: TabFolder
    let space: Space
    let onDelete: () -> Void
    let onAddTab: () -> Void
    let onActivateTab: (Tab) -> Void
    var isRegular: Bool = false

    @State private var isHovering: Bool = false
    @State private var isRenaming: Bool = false
    @State private var draftName: String = ""
    @FocusState private var nameFieldFocused: Bool

    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(BrowserWindowState.self) private var windowState
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    // Get tabs in this folder
    private var tabsInFolder: [Tab] {
        if isRegular {
            return tabManager.regularFolderTabs(for: space.id, folderId: folder.id)
        }
        let tabs = tabManager.spacePinnedTabs(for: space.id)
            .filter { $0.folderId == folder.id }
            .sorted { $0.index < $1.index }
        return tabs
    }

    private var tabCount: Int {
        tabsInFolder.count
    }

    private var isDropTargeted: Bool {
        dragSession.isDragging && dragSession.activeZone == .folder(folder.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Folder header
            folderHeader

            // Folder content (tabs)
            if folder.isOpen {
                folderContent
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .identity
                    ))
            }
        }
        .onChange(of: dragSession.pendingDrop) { _, drop in
            handleFolderDrop(drop)
        }
        .onChange(of: dragSession.pendingReorder) { _, reorder in
            handleFolderReorder(reorder)
        }
    }

    // MARK: - Drop Handling

    private func handleFolderDrop(_ drop: PendingDrop?) {
        guard let drop = drop, case .folder(let folderId) = drop.targetZone, folderId == folder.id else { return }
        let allTabs = tabManager.allTabs()
        guard let tab = allTabs.first(where: { $0.id == drop.item.tabId }) else { return }
        let op = dragSession.makeDragOperation(from: drop, tab: tab)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragSession.clearDrag()
            tabManager.handleDragOperation(op)
        }
        dragSession.pendingDrop = nil
    }

    private func handleFolderReorder(_ reorder: PendingReorder?) {
        guard let reorder = reorder, case .folder(let folderId) = reorder.zone, folderId == folder.id else { return }
        let tabs = tabsInFolder
        guard reorder.fromIndex < tabs.count else {
            dragSession.pendingReorder = nil
            return
        }
        let tab = tabs[reorder.fromIndex]
        let op = dragSession.makeDragOperation(from: reorder, tab: tab)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dragSession.clearDrag()
            tabManager.handleDragOperation(op)
        }
        dragSession.pendingReorder = nil
    }

    private var folderHeader: some View {
        Button(action: {
            withAnimation(VegaDesign.Motion.spring) {
                folder.isOpen.toggle()
            }
        }) {
            HStack(spacing: VegaDesign.Spacing.md) {
                Image(systemName: "chevron.right")
                    .font(.system(size: VegaDesign.Size.rowGlyph - 1, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(folder.isOpen ? 90 : 0))
                    .animation(VegaDesign.Motion.standard, value: folder.isOpen)

                Image(systemName: folder.isOpen ? "folder.fill" : "folder")
                    .font(.system(size: VegaDesign.Size.spaceIcon, weight: .medium))
                    .foregroundStyle(space.accentColor)

                // Folder name - editable
                if isRenaming {
                    TextField("", text: $draftName)
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(.primary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocorrectionDisabled()
                        .focused($nameFieldFocused)
                        .onAppear {
                            draftName = folder.name
                            DispatchQueue.main.async {
                                nameFieldFocused = true
                            }
                        }
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                } else {
                    Text(folder.name)
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: VegaDesign.Spacing.xs)

                if !isHovering {
                    Text("\(tabCount)")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.tertiary)
                }

                // Context menu button
                if isHovering && !isRenaming {
                    Menu {
                        sharedFolderMenu
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
                    .fill(
                        isDropTargeted
                            ? VegaDesign.Surface.fillPressed
                            : (isHovering ? VegaDesign.Surface.fill : Color.clear)
                    )
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
            sharedFolderMenu
        }
        .onChange(of: nameFieldFocused) { _, focused in
            // When losing focus during rename, commit
            if isRenaming && !focused {
                commitRename()
            }
        }
    }

    private var folderContent: some View {
        let tabs = tabsInFolder

        return VegaDropZoneHostView(
            zoneID: .folder(folder.id),
            isVertical: true,
            manager: dragSession
        ) {
            VStack(spacing: VegaDesign.Spacing.rowGap) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    folderTabView(tab, index: index)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .animation(VegaDesign.Motion.spring.delay(Double(index) * 0.03)),
                                removal: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .animation(VegaDesign.Motion.spring.delay(Double(tabs.count - index - 1) * 0.02))
                            )
                        )
                }
            }
        }
        .padding(.vertical, VegaDesign.Spacing.xxs)
        .onAppear {
            let zone = DropZoneID.folder(folder.id)
            dragSession.itemCellSize[zone] = VegaDesign.Size.row
            dragSession.itemCellSpacing[zone] = VegaDesign.Spacing.rowGap
            dragSession.itemCounts[zone] = tabs.count
        }
        .onDisappear {
            let zone = DropZoneID.folder(folder.id)
            dragSession.itemCellSize[zone] = nil
            dragSession.itemCellSpacing[zone] = nil
            dragSession.itemCounts[zone] = nil
        }
        .onChange(of: tabs.count) { _, newCount in
            dragSession.itemCounts[.folder(folder.id)] = newCount
        }
    }

    private func folderTabView(_ tab: Tab, index: Int) -> some View {
        VegaDragSourceView(
            item: VegaDragItem(tabId: tab.id, title: tab.displayName, urlString: tab.url.absoluteString),
            tab: tab,
            zoneID: .folder(folder.id),
            index: index,
            manager: dragSession
        ) {
            SpaceTab(
                tab: tab,
                action: {
                    onActivateTab(tab)
                },
                onClose: { tabManager.removeTab(tab.id) },
                onMute: { tab.toggleMute() },
                menuContext: .folder
            )
            .padding(.leading, VegaDesign.Spacing.folderIndent)
        }
        .opacity(dragSession.draggedItem?.tabId == tab.id ? 0.0 : 1.0)
        .offset(y: dragSession.reorderOffset(for: .folder(folder.id), at: index))
        .animation(VegaDesign.Motion.spring, value: dragSession.insertionIndex[.folder(folder.id)])
        .transition(.move(edge: .top).combined(with: .opacity))

    }

    private var sharedFolderMenu: some View {
        FolderContextMenu(
            folder: folder,
            onRename: startRenaming,
            onAddTab: onAddTab,
            onAlphabetize: alphabetizeTabs,
            onDelete: onDelete
        )
    }

    private func alphabetizeTabs() {
        let sortedTabs = tabsInFolder.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        withAnimation(VegaDesign.Motion.spring) {
            // Update tab indices to match alphabetical order
            for (index, tab) in sortedTabs.enumerated() {
                tab.index = index
            }
            tabManager.persistSnapshot()
        }
    }

    // MARK: - Rename Actions

    private func startRenaming() {
        draftName = folder.name
        isRenaming = true
    }

    private func cancelRename() {
        isRenaming = false
        draftName = folder.name
        nameFieldFocused = false
    }

    private func commitRename() {
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty && newName != folder.name {
            tabManager.renameFolder(folder.id, newName: newName)
        }
        isRenaming = false
        nameFieldFocused = false
    }
}

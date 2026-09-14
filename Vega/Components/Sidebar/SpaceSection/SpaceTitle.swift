import SwiftUI

struct SpaceTitle: View {
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var tabManager: TabManager

    let space: Space
    var iconSize: CGFloat = VegaDesign.Size.spaceIcon

    @State private var isHovering: Bool = false
    @State private var isRenaming: Bool = false
    @State private var draftName: String = ""
    @FocusState private var nameFieldFocused: Bool
    @State private var isEllipsisHovering: Bool = false
    @ObservedObject private var dragSession = VegaDragSessionManager.shared

    @State private var showIconPicker = false

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.sm) {
            SpaceIconView(icon: space.icon, size: iconSize, tint: space.accentColor)
                .onTapGesture(count: 2) {
                    showIconPicker = true
                }
                .popover(isPresented: $showIconPicker) {
                    SpaceIconPicker(selected: space.icon, onPick: {
                        space.icon = $0
                        tabManager.persistSnapshot()
                        showIconPicker = false
                    })
                }

            if isRenaming {
                TextField("", text: $draftName)
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(textColor)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .focused($nameFieldFocused)
                    .onAppear {
                        draftName = space.name
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
                HStack(spacing: VegaDesign.Spacing.sm) {
                    Text(space.name)
                        .font(VegaDesign.Font.label)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onTapGesture(count: 2) {
                            startRenaming()
                        }
                }
            }

            Spacer()

            if isHovering {
                Menu {
                    SpaceContextMenu(
                        space: space,
                        canDelete: canDeleteSpace,
                        onEditName: {
                            startRenaming()
                        },
                        onEditIcon: {
                            showIconPicker = true
                        },
                        onOpenSettings: {
                            browserManager.showSpaceSettings(for: space)
                        },
                        onDeleteSpace: deleteSpace
                    )
                    .environmentObject(browserManager)
                    .environment(\.controlSize, .regular)
                } label: {
                    Label("Configure Space", systemImage: "ellipsis")
                        .font(.body.weight(.semibold))
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.button)
                .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton, radius: VegaDesign.Radius.sm))
            }

        }
        // Match tabs' internal left/right padding so text aligns
        .onChange(of: dragSession.pendingDrop) { _, drop in
            guard let drop = drop, drop.targetZone == .spacePinned(space.id) else { return }
            guard tabManager.spacePinnedTabs(for: space.id).isEmpty else { return }
            let allTabs = tabManager.allTabs()
            guard let tab = allTabs.first(where: { $0.id == drop.item.tabId }) else { return }
            let op = dragSession.makeDragOperation(from: drop, tab: tab)
            withAnimation(VegaDesign.Motion.spring) {
                tabManager.handleDragOperation(op)
            }
            dragSession.pendingDrop = nil
        }
        .padding(.horizontal, VegaDesign.Spacing.sm)
        .frame(height: VegaDesign.Size.navRow)
        .frame(maxWidth: .infinity)
        .background(hoverColor)
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .contentShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) {
                isHovering = hovering
            }
        }
        .onChange(of: nameFieldFocused) { _, focused in
            // When losing focus during rename, commit
            if isRenaming && !focused {
                commitRename()
            }
        }
        // Provide a right-click context menu
        .contextMenu {
            SpaceContextMenu(
                space: space,
                canDelete: canDeleteSpace,
                onEditName: {
                    startRenaming()
                },
                onEditIcon: {
                    showIconPicker = true
                },
                onOpenSettings: {
                    browserManager.showSpaceSettings(for: space)
                },
                onDeleteSpace: deleteSpace
            )
            .environmentObject(browserManager)
        }
    }
    
    //MARK: - Colors
    
    private var isDropHovering: Bool {
        guard dragSession.isDragging else { return false }
        return dragSession.activeZone == .spacePinned(space.id)
            && tabManager.spacePinnedTabs(for: space.id).isEmpty
    }

    private var hoverColor: Color {
        if isHovering || isDropHovering {
            return VegaDesign.Surface.fill
        } else {
            return .clear
        }
    }
    private var textColor: Color {
        .primary
    }

    private var canDeleteSpace: Bool {
        tabManager.spaces.count > 1
    }

    // MARK: - Actions

    private func startRenaming() {
        draftName = space.name
        isRenaming = true
    }

    private func cancelRename() {
        isRenaming = false
        draftName = space.name
        nameFieldFocused = false
    }

    private func commitRename() {
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty, newName != space.name {
            do {
                try tabManager.renameSpace(
                    spaceId: space.id,
                    newName: newName
                )
            } catch {
            }
        }
        isRenaming = false
        nameFieldFocused = false
    }

    private func deleteSpace() {
        tabManager.removeSpace(space.id)
    }

    private func createFolder() {
        tabManager.createFolder(for: space.id)
    }

    private func assignProfile(_ id: UUID) {
        tabManager.assign(spaceId: space.id, toProfile: id)
    }

    private func resolvedProfileName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return browserManager.profileManager.profiles.first(where: { $0.id == id })?.name
    }
    
}

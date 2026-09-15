//
//  SpacesListItem.swift
//  Vega
//
//  Created by Maciek Bagiński on 04/08/2025.
//  Refactored by Aether on 15/11/2025.
//

import VegaTabsCore
import SwiftUI

struct SpacesListItem: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var windowState

    let space: SpaceRecord
    let isActive: Bool
    let compact: Bool
    let isFaded: Bool
    let onHoverChange: ((Bool) -> Void)?

    @State private var isHovering: Bool = false

    private let dotSize: CGFloat = VegaDesign.Spacing.sm

    init(
        space: SpaceRecord,
        isActive: Bool,
        compact: Bool,
        isFaded: Bool,
        onHoverChange: ((Bool) -> Void)? = nil
    ) {
        self.space = space
        self.isActive = isActive
        self.compact = compact
        self.isFaded = isFaded
        self.onHoverChange = onHoverChange
    }

    var body: some View {
        Button {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            withAnimation(VegaDesign.Motion.standard) {
                tabs.setSpace(space.id, in: windowState)
            }
        } label: {
            spaceIcon
                .frame(maxWidth: .infinity)

        }
        .labelStyle(.iconOnly)
        .buttonStyle(VegaIconButtonStyle())
        .background(VegaDesign.Radius.shape(VegaDesign.Radius.md).fill(isActive ? VegaDesign.Surface.fill : .clear))
        .layoutPriority(isActive ? 1 : 0)
        .opacity(isFaded ? 0.3 : 1.0)
        .onHoverTracking { hovering in
            isHovering = hovering
            onHoverChange?(hovering)
        }
        .contextMenu {
            SpaceContextMenu(
                space: space,
                canDelete: tabs.switchableSpaces(for: windowState).count > 1,
                onEditName: nil,
                onEditIcon: nil,
                onOpenSettings: {
                    SpaceEditDialog.present(spaceID: space.id, tabs: tabs, dialogManager: browserManager.dialogManager)
                },
                onDeleteSpace: { tabs.deleteSpace(space.id) }
            )
            .environmentObject(browserManager)
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var spaceIcon: some View {
        if compact && !isActive {
            Circle()
                .fill(.tertiary)
                .frame(width: dotSize, height: dotSize)
        } else {
            SpaceIconView(icon: space.icon, tint: isActive ? space.accentColor : AppColors.textTertiary)
        }
    }
}

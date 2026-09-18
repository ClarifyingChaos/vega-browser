// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  TabSheet.swift
//  VegaiOS
//
//  The phone's tab surface: the macOS sidebar outline at phone width. It opens
//  large because it is the deliberate surface (find, reorder, pin); quick
//  switching is the swipe on the bar. It drops to medium on a drag.
//

import SwiftUI
import VegaDesign
import VegaTabsCore
import VegaUI
import VegaWeb

struct TabSheet: View {
    @EnvironmentObject private var model: BrowserModel
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var window
    @Environment(\.dismiss) private var dismiss

    @State private var detent: PresentationDetent = .large

    private var spaceID: UUID? { window.spaceID }

    var body: some View {
        ScrollView {
            if let spaceID {
                LazyVStack(alignment: .leading, spacing: VegaDesign.Spacing.lg) {
                    FavoritesGrid(spaceID: spaceID) { dismiss() }
                    TabSheetRows(spaceID: spaceID) { dismiss() }
                }
                .padding(VegaDesign.Spacing.rowPadding)
            }
        }
        .safeAreaInset(edge: .top) {
            header
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        ZStack {
            // Centred regardless of the close button's width.
            SpacesList()
                .frame(height: VegaDesign.Spacing.xl)

            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: VegaDesign.Size.iconButton)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        // Clears the sheet's own drag indicator, which draws at the same top edge.
        .padding(.top, VegaDesign.Spacing.xxl)
        .padding(.bottom, VegaDesign.Spacing.md)
        .background(.bar)
    }
}

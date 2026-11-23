// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarUpdateNotification.swift
//  Vega
//
//  Created by Jonathan Caudill on 27/09/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI
import VegaSettings

struct SidebarUpdateNotification: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.vegaSettings) var settingsManager
    let downloadsMenuVisible: Bool
    @State private var isVisible: Bool = false
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var gradientPhase: Double = 0.0

    // continuous motion, not a state transition
    private let gradientAnimationDuration: Double = 2.0

    private var availability: BrowserManager.UpdateAvailability? {
        if let update = browserManager.updateAvailability {
            return update
        }
        if settingsManager.debugToggleUpdateNotification {
            return BrowserManager.UpdateAvailability(
                version: "9999.0",
                shortVersion: "Preview Build",
                releaseNotesURL: nil,
                isDownloaded: true
            )
        }
        return nil
    }

    private var shouldShowNotification: Bool {
        availability != nil
    }

    var body: some View {
        // Gives way to the downloads list, which opens in its place: moved up, it sat on top of the list.
        if let availability, shouldShowNotification, !downloadsMenuVisible {
            VStack(spacing: 0) {
                // FORK: one stack with even spacing. The title used to slide 25 pt up and out of the
                // card to make room, which left it hidden once a second link was added.
                VStack(spacing: VegaDesign.Spacing.md) {
                    Label {
                        Text("Vega \(availability.shortVersion) is available")
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
                    }
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)

                    if isExpanded {
                        Button(action: {
                            installUpdate(wasDownloaded: availability.isDownloaded)
                        }) {
                            Text("Restart and Update")
                                .font(VegaDesign.Font.secondary)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: VegaDesign.Size.iconButton)
                                .background(
                                    VegaDesign.Radius.shape(VegaDesign.Radius.md)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.accentColor, Color.white, Color.accentColor, Color.white]),
                                                startPoint: UnitPoint(x: gradientPhase, y: gradientPhase),
                                                endPoint: UnitPoint(x: gradientPhase + 1.0, y: gradientPhase + 1.0)
                                            )
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        // The shimmer runs only while the button shows: a forever animation started with the card
                        // redrew the window every frame for as long as an update waited.
                        .onAppear {
                            withAnimation(.linear(duration: gradientAnimationDuration).repeatForever(autoreverses: false)) {
                                gradientPhase = 1.0
                            }
                        }
                        .onDisappear { gradientPhase = 0 }

                        // What changed, before restarting.
                        Button("What's New") { browserManager.openSettings(tab: .updates) }
                            .buttonStyle(.plain)
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, VegaDesign.Spacing.lg)
                .padding(.vertical, VegaDesign.Spacing.lg)
                .vegaFloatingSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
                .frame(maxWidth: .infinity)
                .onHoverTracking { hovering in
                    isHovering = hovering
                    withAnimation(VegaDesign.Motion.spring) {
                        isExpanded = hovering
                    }
                }
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 50)
            .animation(VegaDesign.Motion.standard, value: isVisible)
            .animation(VegaDesign.Motion.standard, value: isExpanded)
            .onAppear { showNotification() }
            .onChange(of: shouldShowNotification) { _, newValue in
                if newValue {
                    showNotification()
                } else {
                    hideNotification()
                }
            }
        }
    }

    private func showNotification() {
        isVisible = true
    }

    private func hideNotification() {
        isVisible = false
    }

    private func installUpdate(wasDownloaded: Bool) {
        browserManager.installPendingUpdateIfAvailable()
    }
}

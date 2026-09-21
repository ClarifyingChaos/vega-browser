// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  ZoomPopupView.swift
//  Vega
//
//  Created by Assistant on 13/10/2025.
//

import SwiftUI
import VegaDesign

struct ZoomPopupView: View {
    var zoomManager: ZoomManager
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var hideTimer: Timer?

    var body: some View {
        // Just the three controls: - button, percentage, + button
        HStack(spacing: 8) {
            // Zoom out button
            Button(action: {
                onZoomOut()
                resetHideTimer()
            }) {
                Image(systemName: "minus")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .fill(VegaDesign.Surface.fill)
                    )
                    .overlay(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .stroke(VegaDesign.Surface.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(zoomManager.isAtMinimumZoom)

            // Current zoom percentage (clickable for reset)
            Button(action: {
                onZoomReset()
                resetHideTimer()
            }) {
                Text(zoomManager.getZoomPercentageDisplay())
                    .font(VegaDesign.Font.label)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 50, maxHeight: 28)
                    .padding(.horizontal, 8)
                    .background(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .fill(VegaDesign.Surface.fillPressed)
                    )
                    .overlay(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .stroke(VegaDesign.Surface.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Zoom in button
            Button(action: {
                onZoomIn()
                resetHideTimer()
            }) {
                Image(systemName: "plus")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .fill(VegaDesign.Surface.fill)
                    )
                    .overlay(
                        VegaDesign.Radius.shape(VegaDesign.Radius.sm)
                            .stroke(VegaDesign.Surface.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(zoomManager.isAtMaximumZoom)
        }
        .padding(12)
        .frame(maxWidth: 160)
        .vegaGlassEffect(in: VegaDesign.Radius.shape(VegaDesign.Radius.lg))
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(VegaDesign.Motion.spring, value: isVisible)
        .onAppear {
            isVisible = true
            startHideTimer()
        }
        .onChange(of: zoomManager.currentZoomLevel) {
            resetHideTimer()
        }
        .onDisappear {
            hideTimer?.invalidate()
        }
    }

    // MARK: - Timer Management

    private func startHideTimer() {
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            onDismiss()
        }
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        startHideTimer()
    }
}

// MARK: - Preview

#Preview {
    ZoomPopupView(
        zoomManager: ZoomManager(),
        onZoomIn: {},
        onZoomOut: {},
        onZoomReset: {},
        onDismiss: {}
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}


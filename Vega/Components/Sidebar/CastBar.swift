// Licensed under GPL-3.0. See LICENSE.
//
//  CastBar.swift
//  Vega
//
//  FORK: Arc's Cast. A bar above the sidebar's media controls holding the system AirPlay picker.
//  The device list opens from the bar on its own; when it closes (a device picked, or a click
//  elsewhere) the bar goes. shortcut: the list itself is AppKit's popover, so it can reach past
//  the sidebar; AirPlay devices are not exposed to build our own list.
//

import AVKit
import SwiftUI
import VegaDesign
import VegaWeb
import VegaUI

struct CastBar: View {
    @Environment(BrowserWindowState.self) private var windowState

    var body: some View {
        HStack(spacing: VegaDesign.Spacing.md) {
            Image(systemName: "airplayvideo")
                .font(VegaDesign.Font.title)
                .foregroundStyle(.white)
            Text("Cast to…")
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            RoutePicker { close() }
                .frame(width: 28, height: 28)
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .buttonStyle(VegaIconButtonStyle(size: 24))
                .foregroundStyle(.white)
                .help("Close")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(VegaDesign.Radius.shape(VegaDesign.Radius.md).fill(Color.black))
        .overlay(VegaDesign.Radius.shape(VegaDesign.Radius.md).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, VegaDesign.Spacing.sidebarInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cast")
    }

    private func close() {
        withAnimation(VegaDesign.Motion.standard) { windowState.isCastBarVisible = false }
    }
}

/// AVKit's AirPlay button, pressed once when it appears so the list is already open.
private struct RoutePicker: NSViewRepresentable {
    let onEnd: () -> Void

    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        var onEnd: () -> Void
        init(_ onEnd: @escaping () -> Void) { self.onEnd = onEnd }
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) { onEnd() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onEnd) }

    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.delegate = context.coordinator
        picker.isRoutePickerButtonBordered = false
        picker.setRoutePickerButtonColor(.white, for: .normal)
        picker.setRoutePickerButtonColor(.white, for: .normalHighlighted)
        // The button is built lazily inside the picker, and the window must be up first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak picker] in
            (picker?.subviews.first { $0 is NSButton } as? NSButton)?.performClick(nil)
        }
        return picker
    }

    func updateNSView(_ picker: AVRoutePickerView, context: Context) { context.coordinator.onEnd = onEnd }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  CaptureToast.swift
//  Vega
//
//  Shown after a capture: the picture, "Copied and saved", and where to find it.
//

import AppKit
import SwiftUI
import VegaDesign
import VegaUI

struct CaptureToast: View {
    let capture: Download
    let onViewInLibrary: () -> Void
    let onSaveAs: () -> Void

    private let visibleFor: Duration = .seconds(7)

    var body: some View {
        HStack(alignment: .center, spacing: VegaDesign.Spacing.md) {
            if let file = capture.destinationURL, let image = NSImage(contentsOf: file) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
                    .overlay(VegaDesign.Radius.shape(VegaDesign.Radius.md).strokeBorder(VegaDesign.Surface.hairline))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture copied and saved")
                    .font(VegaDesign.Font.label)
                HStack(spacing: VegaDesign.Spacing.md) {
                    Button("View in Library", action: onViewInLibrary)
                    Button("Save As…", action: onSaveAs)
                }
                .buttonStyle(.plain)
                .font(VegaDesign.Font.secondary)
                .foregroundStyle(Color.accentColor)
            }
            Button("Close", vegaIcon: "xmark") { CaptureLibrary.shared.dismissLatest() }
                .labelStyle(.iconOnly)
                .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton))
                .foregroundStyle(.secondary)
                .help("Close")
        }
        .padding(VegaDesign.Spacing.lg)
        .frame(maxWidth: 340, alignment: .leading)
        .vegaGlassSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.xl))
        .task(id: capture.id) {
            try? await Task.sleep(for: visibleFor)
            if CaptureLibrary.shared.latest?.id == capture.id { CaptureLibrary.shared.dismissLatest() }
        }
    }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  CaptureToast.swift
//  Nook
//
//  Shown after a capture: the picture, "Copied and saved", and where to find it.
//

import AppKit
import SwiftUI
import NookDesign
import NookUI

struct CaptureToast: View {
    let capture: Download
    let onViewInLibrary: () -> Void
    let onSaveAs: () -> Void

    private let visibleFor: Duration = .seconds(7)

    var body: some View {
        HStack(alignment: .center, spacing: NookDesign.Spacing.md) {
            if let file = capture.destinationURL, let image = NSImage(contentsOf: file) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(NookDesign.Radius.shape(NookDesign.Radius.md))
                    .overlay(NookDesign.Radius.shape(NookDesign.Radius.md).strokeBorder(NookDesign.Surface.hairline))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture copied and saved")
                    .font(NookDesign.Font.label)
                HStack(spacing: NookDesign.Spacing.md) {
                    Button("View in Library", action: onViewInLibrary)
                    Button("Save As…", action: onSaveAs)
                }
                .buttonStyle(.plain)
                .font(NookDesign.Font.secondary)
                .foregroundStyle(Color.accentColor)
            }
            Button("Close", nookIcon: "xmark") { CaptureLibrary.shared.dismissLatest() }
                .labelStyle(.iconOnly)
                .buttonStyle(NookIconButtonStyle(size: NookDesign.Size.rowButton))
                .foregroundStyle(.secondary)
                .help("Close")
        }
        .padding(NookDesign.Spacing.lg)
        .frame(maxWidth: 340, alignment: .leading)
        .nookGlassSurface(in: NookDesign.Radius.shape(NookDesign.Radius.xl))
        .task(id: capture.id) {
            try? await Task.sleep(for: visibleFor)
            if CaptureLibrary.shared.latest?.id == capture.id { CaptureLibrary.shared.dismissLatest() }
        }
    }
}

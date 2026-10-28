// Licensed under GPL-3.0. See LICENSE.
//
//  TidyDownloadToast.swift
//  Vega
//
//  Shown when Tidy Downloads renames a file: the new name, the old one struck through, undo.
//

import SwiftUI
import VegaDesign
import VegaUI

struct TidyDownloadToast: View {
    let download: Download
    let downloads: DownloadManager

    private let visibleFor: Duration = .seconds(6)
    private let maxWidth: CGFloat = 300

    var body: some View {
        HStack(alignment: .top, spacing: VegaDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                Text("Download renamed to:")
                    .font(VegaDesign.Font.caption)
                    .foregroundStyle(.secondary)
                Text(download.displayName)
                    .font(VegaDesign.Font.secondary)
                    .lineLimit(1)
                if let old = download.renamedFrom {
                    Text(old)
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.tertiary)
                        .strikethrough()
                        .lineLimit(1)
                }
            }
            HStack(spacing: VegaDesign.Spacing.xxs) {
                Button("Undo", systemImage: "arrow.uturn.backward") { downloads.undoTidy(download) }
                    .help("Undo")
                Button("Close", systemImage: "xmark") { downloads.dismissTidyToast() }
                    .help("Close")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(VegaIconButtonStyle(size: VegaDesign.Size.rowButton))
            .foregroundStyle(.secondary)
        }
        .padding(VegaDesign.Spacing.lg)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .vegaFloatingSurface(in: VegaDesign.Radius.shape(VegaDesign.Radius.xl))
        .task(id: download.id) {
            try? await Task.sleep(for: visibleFor)
            if downloads.lastTidied === download { downloads.dismissTidyToast() }
        }
    }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  SidebarMenuMediaTab.swift
//  Nook
//
//  FORK: Arc's Media view in the Library: the images and videos you downloaded and every capture you took, as one
//  grid of thumbnails, newest first, with a search field on top. Captures are kept in Vega's own folder, so all of
//  them are listed whichever folder you also saved a copy to.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NookDesign
import NookUI

struct SidebarMenuMediaTab: View {
    @EnvironmentObject var browserManager: BrowserManager
    @State private var text = ""

    private func isVideo(_ download: Download) -> Bool? {
        guard download.state == .completed, let file = download.completedFile,
              let type = UTType(filenameExtension: file.pathExtension) else { return nil }
        if type.conforms(to: .image) { return false }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return true }
        return nil
    }

    private var items: [Download] {
        let captures = CaptureLibrary.shared.items + CaptureLibrary.shared.systemShots
        let media = browserManager.downloadManager.allDownloads.filter { isVideo($0) != nil }
        // A file that is both a download and a screenshot (the Downloads folder as the screenshot folder) shows once.
        let known = Set(captures.compactMap { $0.destinationURL?.path })
        return (captures + media.filter { !known.contains($0.destinationURL?.path ?? "") }).filter { download in
            text.isEmpty
                || download.displayName.localizedCaseInsensitiveContains(text)
                || download.originalURL.absoluteString.localizedCaseInsensitiveContains(text)
        }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        let items = items
        let _ = CaptureLibrary.shared.loadIfNeeded()
        ScrollView {
            if items.isEmpty {
                VStack(spacing: NookDesign.Spacing.md) {
                    Image(systemName: text.isEmpty ? "photo.on.rectangle" : "magnifyingglass")
                        .font(NookDesign.Font.titleLarge)
                        .foregroundStyle(.tertiary)
                    Text(text.isEmpty ? "No media yet" : "No media found")
                        .font(NookDesign.Font.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, NookDesign.Spacing.xxxl)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: NookDesign.Spacing.md)], spacing: NookDesign.Spacing.md) {
                    ForEach(items) { item in
                        MediaTile(download: item, isVideo: isVideo(item) == true,
                                  source: CaptureLibrary.shared.items.contains { $0.id == item.id } ? .capture
                                      : CaptureLibrary.shared.systemShots.contains { $0.id == item.id } ? .screenshot : .download)
                    }
                }
                .padding(.horizontal, NookDesign.Spacing.md)
                .padding(.bottom, NookDesign.Spacing.md)
            }
        }
        // The macOS screenshots are read when the tab opens and again every few seconds while it is up.
        .task {
            while !Task.isCancelled {
                CaptureLibrary.shared.refreshSystemShots()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        // Same header as History and Downloads: the field floats over the grid, padding included.
        .nookScrollHeader {
            SidebarMenuSearchField(prompt: "Search Media...", text: $text)
                .padding(NookDesign.Spacing.md)
        }
    }
}

/// Arc's cell: the file fitted inside a rounded dark square.
private struct MediaTile: View {
    let download: Download
    let isVideo: Bool
    enum Source { case download, capture, screenshot }
    var source: Source = .download
    private var isCapture: Bool { source == .capture }
    @EnvironmentObject private var browserManager: BrowserManager
    @State private var isHovering = false

    private var shape: some InsettableShape { NookDesign.Radius.shape(NookDesign.Radius.lg) }

    var body: some View {
        Image(nsImage: download.downloadThumbnail ?? download.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(NookDesign.Spacing.xl)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(NookDesign.Surface.fill)
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                if isVideo {
                    Image(systemName: "play.fill")
                        .font(NookDesign.Font.caption)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .padding(NookDesign.Spacing.sm)
                }
            }
            .overlay(shape.strokeBorder(isHovering ? Color.primary.opacity(0.35) : Color.clear, lineWidth: 1))
            .contentShape(shape)
            .onHover { isHovering = $0 }
            .help(download.displayName)
            .accessibilityLabel(download.displayName)
            .task(id: download.destinationURL) {
                if download.downloadThumbnail == nil { await download.loadThumbnail(size: CGSize(width: 240, height: 240)) }
            }
            .onTapGesture { DownloadManager.shared.previewing = download }
            .onDrag { download.dragItemProvider() }
            .contextMenu {
                if let file = download.completedFile {
                    Button("Open") { NSWorkspace.shared.open(file) }
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                    Divider()
                }
                if isCapture {
                    Button("Save As…") { browserManager.saveCaptureAs(download) }
                    Divider()
                    Button("Delete Capture") { CaptureLibrary.shared.delete(download) }
                } else if source == .screenshot {
                    Divider()
                    Button("Move to Trash") { CaptureLibrary.shared.trash(download) }
                } else {
                    Button("Hide from Vega") { DownloadManager.shared.removeDownload(download.id) }
                }
            }
    }
}

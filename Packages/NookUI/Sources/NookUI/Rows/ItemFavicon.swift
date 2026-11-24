// Licensed under GPL-3.0. See LICENSE.
//
//  ItemFavicon.swift
//  NookUI
//
//  The favicon every row and tile draws, and the inline-rename state the rows and the
//  context menu share.
//

import SwiftUI
import NookTabsCore
import NookWeb

// MARK: - Rename State

/// The row being renamed inline. Shared so a context menu can start a rename on its row.
@MainActor
@Observable
final class SidebarRenameState {
    static let shared = SidebarRenameState()
    var itemID: UUID?
}

extension TabsController {
    /// Creates a "New Folder" under `parent` after `after` and starts renaming it inline.
    public func createFolderForRename(in parent: Parent, after: UUID?) {
        guard let folderID = createFolder(title: "New Folder", in: parent, after: after) else { return }
        if case .folder(let outer) = parent { openFolder(outer) }
        SidebarRenameState.shared.itemID = folderID
    }
}

// MARK: - Favicon

/// A row or tile favicon: the live page's, else the cached one for the item's host, else a globe.
public struct ItemFavicon: View {
    let item: Item
    let session: PageSession?
    @State private var cached: Image?
    @State private var cachedPlatform: PlatformImage?

    public init(item: Item, session: PageSession?) {
        self.item = item
        self.session = session
    }

    public var body: some View {
        let _ = session?.favicon // FORK: re-render when the live icon changes
        Group {
            if let crisp = crispSource {
                CrispIcon(source: crisp)
            } else {
                // The live page's icon only while it is on the item's own site: a favorite that has gone on to another
                // site (a sign-in, a link) keeps its own icon.
                ((session?.hasLoadedFavicon == true && onOwnSite ? session?.favicon : nil) ?? cached ?? session?.favicon ?? Image(systemName: "globe"))
                    .resizable()
                    .scaledToFit()
            }
        }
            // Keyed on the session too: closing a pinned tab or favorite ends its page but keeps
            // the row, and the cached icon must be loaded then.
            .task(id: "\(item.url.flatMap(FaviconCache.pageKey) ?? "")|\(session == nil)|\(session?.hasLoadedFavicon == true)") {
                session?.ensureFaviconLoaded()
                guard let url = item.url, FaviconCache.pageKey(for: url) != nil else { return }
                // FORK: a pin whose address redirects (gmail.com to mail.google.com) keeps the icon its page loaded, as Chromium
                // gives an icon to every address in a redirect chain. Only for a real redirect from the item's own address: a
                // page the tab went on to by a link, a sign-in or Peek is another page, whose icon is not this item's.
                if let session, !session.isPrivate, session.hasLoadedFavicon, FaviconCache.shared.image(forPage: url) == nil,
                   session.redirectedFrom.flatMap(FaviconCache.pageKey) == FaviconCache.pageKey(for: url),
                   let live = FaviconCache.shared.image(forPage: session.url) {
                    FaviconCache.shared.store(live, forPage: url)
                }
                if let image = await FaviconCache.shared.cachedImage(forPage: url) { cached = Image(platformImage: image); cachedPlatform = image }
                // FORK: an unloaded favorite or pinned tab has no page to fetch its icon, so fetch it here.
                // Never for a private tab: it would reach the network and the disk cache.
                guard !(session?.hasLoadedFavicon == true && onOwnSite), session?.isPrivate != true,
                      let image = await FaviconCache.shared.loadOrFetch(for: url) else { return }
                cached = Image(platformImage: image)
                cachedPlatform = image
            }
    }

    /// Whether the live page is still on the item's own host.
    private var onOwnSite: Bool {
        guard let session, let own = item.url.flatMap(FaviconCache.key) else { return false }
        return FaviconCache.key(for: session.url) == own
    }

    /// FORK: the stored bitmap behind the icon, when there is one to resample for the tile.
    private var crispSource: PlatformImage? {
        #if os(macOS)
        if let session, session.hasLoadedFavicon, onOwnSite || cachedPlatform == nil,
           let image = FaviconCache.shared.image(forPage: session.url) { return image }
        return cachedPlatform
        #else
        return nil
        #endif
    }
}

#if os(macOS)
/// Draws an icon at exactly the device pixels it occupies. A square placeholder takes the layout
/// the scaled image would, then the resampled bitmap is drawn 1:1 inside it.
private struct CrispIcon: View {
    let source: PlatformImage
    @Environment(\.displayScale) private var scale
    @State private var edge: CGFloat = 0

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { edge = $0 }
            .overlay {
                if edge > 0 {
                    Image(nsImage: source.resampled(pixels: Int((edge * scale).rounded()), scale: scale))
                        .clipShape(RoundedRectangle(cornerRadius: edge * 0.22, style: .continuous)) // FORK: rounded icons
                }
            }
    }
}
#endif

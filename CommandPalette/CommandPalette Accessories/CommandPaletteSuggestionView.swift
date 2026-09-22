// Licensed under GPL-3.0. See LICENSE.
//
//  CommandPaletteSuggestionView.swift
//  Vega
//
//  Created by Maciek Bagiński on 31/07/2025.
//

import SwiftUI
import VegaDesign
import VegaWeb
import FaviconFinder
import VegaUI

struct CommandPaletteSuggestionView: View {
    var favicon: SwiftUI.Image
    var text: String
    var secondaryText: String? = nil
    var isTabSuggestion: Bool = false
    var isSelected: Bool = false
    var historyURL: URL? = nil
    @State private var isHovered: Bool = false
    @State private var resolvedFavicon: SwiftUI.Image? = nil
    
    var body: some View {
        HStack(alignment: .center,spacing: 12) {
            (resolvedFavicon ?? favicon)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.tertiary)
            if let secondary = secondaryText, !secondary.isEmpty {
                HStack(spacing: 6) {
                    Text(text)
                        .font(VegaDesign.Font.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("-")
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(.tertiary)
                    Text(secondary)
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text(text)
                    .font(VegaDesign.Font.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            if isTabSuggestion {
                HStack(spacing: 6) {
                    Text("Switch to Tab")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "arrow.right")
                        .font(VegaDesign.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
            
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) {
                isHovered = hovering
            }
        }
        .onAppear {
            guard let url = historyURL else { return }
            Task { await fetchFavicon(for: url) }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return VegaDesign.Surface.fillPressed
        } else if isHovered {
            return VegaDesign.Surface.fill
        } else {
            return Color.clear
        }
    }
    
    // MARK: - Favicon Fetching (for history items)
    private func fetchFavicon(for url: URL) async {
        let defaultFavicon = SwiftUI.Image(systemName: "globe")
        // Skip favicon fetching for non-web schemes
        guard url.scheme == "http" || url.scheme == "https", url.host != nil else {
            await MainActor.run { self.resolvedFavicon = defaultFavicon }
            return
        }
        
        // Check cache first
        let cacheKey = url.host ?? url.absoluteString
        if let cachedFavicon = await FaviconCache.shared.cachedImage(for: cacheKey).map(SwiftUI.Image.init(nsImage:)) {
            await MainActor.run { self.resolvedFavicon = cachedFavicon }
            return
        }
        
        do {
            let favicon = try await FaviconFinder(url: url)
                .fetchFaviconURLs()
                .download()
                .largest()
            if let faviconImage = favicon.image {
                let nsImage = faviconImage.image
                let swiftUIImage = SwiftUI.Image(nsImage: nsImage)
                
                // Cache the favicon
                FaviconCache.shared.store(nsImage, for: cacheKey)
                
                await MainActor.run { self.resolvedFavicon = swiftUIImage }
            } else {
                await MainActor.run { self.resolvedFavicon = defaultFavicon }
            }
        } catch {
            await MainActor.run { self.resolvedFavicon = defaultFavicon }
        }
    }
    
}

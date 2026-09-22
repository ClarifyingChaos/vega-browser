// Licensed under GPL-3.0. See LICENSE.
//
//  ShortcutConflictToast.swift
//  Vega
//
//  Created by AI Assistant on 2025.
//
//  Toast notification shown when a keyboard shortcut conflicts between
//  Vega and a website. Informs users they can press again for Vega action.
//

import SwiftUI
import VegaDesign

// MARK: - Shortcut Conflict Toast View

public struct ShortcutConflictToast: View {
    /// The shortcut as the user typed it, e.g. "⌘K".
    let shortcut: String
    let websiteName: String
    let vegaActionName: String
    
    public init(
        shortcut: String,
        websiteName: String,
        vegaActionName: String
    ) {
        self.shortcut = shortcut
        self.websiteName = websiteName
        self.vegaActionName = vegaActionName
    }

    public var body: some View {
        ToastView {
            HStack(spacing: 10) {
                // Keyboard icon
                Image(systemName: "keyboard")
                    .font(VegaDesign.Font.body)
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)
                    .padding(5)
                    .background(VegaDesign.Surface.fill)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
                    .overlay {
                        VegaDesign.Radius.shape(VegaDesign.Radius.md)
                            .stroke(VegaDesign.Surface.hairline, lineWidth: 1)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title: shortcut key used by website
                    HStack(spacing: 4) {
                        Text(shortcut)
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.primary)
                        Text("used by")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(websiteName)
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.primary)
                    }
                    
                    // Subtitle: press again for Vega
                    HStack(spacing: 4) {
                        Text("Press again for")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(vegaActionName)
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .transition(.toast)
    }
}

// MARK: - Preview

#Preview {
    ShortcutConflictToast(
        shortcut: "⌘K",
        websiteName: "Figma",
        vegaActionName: "Command Palette"
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
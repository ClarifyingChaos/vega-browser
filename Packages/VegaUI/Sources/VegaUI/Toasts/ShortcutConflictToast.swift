// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
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
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .padding(5)
                    .background(Color.white.opacity(0.2))
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
                    .overlay {
                        VegaDesign.Radius.shape(VegaDesign.Radius.md)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title: shortcut key used by website
                    HStack(spacing: 4) {
                        Text(shortcut)
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.white)
                        Text("used by")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(websiteName)
                            .font(VegaDesign.Font.secondary)
                            .foregroundStyle(.white)
                    }
                    
                    // Subtitle: press again for Vega
                    HStack(spacing: 4) {
                        Text("Press again for")
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(vegaActionName)
                            .font(VegaDesign.Font.caption)
                            .foregroundStyle(.white.opacity(0.9))
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
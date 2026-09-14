//
//  SpaceTab.swift
//  Vega
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI

struct SpaceTab: View {
    @ObservedObject var tab: Tab
    var action: () -> Void
    var onClose: () -> Void
    var onUnload: (() -> Void)? = nil
    var onMute: () -> Void
    var menuContext: TabMenuContext = .regular
    @State private var isHovering: Bool = false
    @State private var isCloseHovering: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var tabManager: TabManager
    @Environment(BrowserWindowState.self) private var windowState

    /// Fades the trailing edge of the title instead of truncating with an ellipsis.
    /// On hover the clear region grows so the text ends before the close button.
    private var titleFade: some View {
        HStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: VegaDesign.Spacing.titleFade)
            Color.clear
                .frame(width: isHovering ? VegaDesign.Size.row : 0)
        }
    }

    var body: some View {
        Button(action: {
            if isCurrentTab {
                tab.startRenaming()
                isTextFieldFocused = true
            } else {
                if tab.isRenaming {
                    tab.saveRename()
                }
                action()
            }
        }) {
            HStack(spacing: VegaDesign.Spacing.md) {
                tab.favicon
                    .resizable()
                    .scaledToFit()
                    .frame(width: VegaDesign.Size.favicon, height: VegaDesign.Size.favicon)
                    .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.xs))
                if tab.hasAudioContent || tab.hasPlayingAudio || tab.isAudioMuted {
                    Button(action: onMute) {
                        Image(systemName: tab.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .contentTransition(.symbolEffect(.replace))
                            .font(.system(size: VegaDesign.Size.rowGlyph, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(tab.isAudioMuted ? "Unmute" : "Mute")
                }
                
                if tab.isRenaming {
                    TextField("", text: $tab.editingName)
                        .font(VegaDesign.Font.body)
                        .foregroundStyle(tab.isUnloaded ? AppColors.textSecondary : textTab)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            tab.saveRename()
                        }
                        .onExitCommand {
                            tab.cancelRename()
                        }
                        .focused($isTextFieldFocused)
                        .onAppear {
                            isTextFieldFocused = true
                        }
                } else {
                    // Hidden shrinkable copy sizes the row; the visible copy is laid out at
                    // full width and faded, so long titles never widen the row.
                    Text(tab.displayName)
                        .font(VegaDesign.Font.body)
                        .lineLimit(1)
                        .hidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            Text(tab.displayName)
                                .font(VegaDesign.Font.body)
                                .foregroundStyle(textTab)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .mask(titleFade)
                        .textSelection(.disabled) // Make text non-selectable
                }
            }
            .overlay(alignment: .trailing) {
                if isHovering {
                    // Space-pinned loaded tabs: show "-" to unload; unloaded: show "x" to remove
                    let useUnload = onUnload != nil && !tab.isUnloaded
                    Button(action: useUnload ? onUnload! : onClose) {
                        Image(systemName: useUnload ? "minus" : "xmark")
                            .font(VegaDesign.Font.secondary)
                            .foregroundColor(textTab)
                            .frame(width: VegaDesign.Size.rowButton, height: VegaDesign.Size.rowButton)
                            .background(isCloseHovering ? VegaDesign.Surface.fillPressed : Color.clear)
                            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.sm))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHoverTracking { hovering in
                        isCloseHovering = hovering
                    }
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.rowPadding)
            .frame(height: VegaDesign.Size.row)
            .frame(minWidth: VegaDesign.Spacing.zero, maxWidth: .infinity)
            .background(
                backgroundColor
            )
            .overlay {
                if tab.isRenaming {
                    VegaDesign.Radius.shape(VegaDesign.Radius.md)
                        .strokeBorder(browserManager.gradientColorManager.accentColor, lineWidth: 1)
                } else if isCurrentTab {
                    VegaDesign.Radius.shape(VegaDesign.Radius.md)
                        .strokeBorder(VegaDesign.Surface.hairline, lineWidth: 1)
                }
            }
            .clipShape(VegaDesign.Radius.shape(VegaDesign.Radius.md))
            .opacity(tab.isUnloaded ? VegaDesign.Surface.unloadedOpacity : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onHoverTracking { hovering in
            withAnimation(VegaDesign.Motion.quick) {
                isHovering = hovering
            }
        }
        .background(
            Group {
                if tab.isRenaming {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            tab.saveRename()
                        }
                }
            }
        )
        .contextMenu {
            TabContextMenu(tab: tab, context: menuContext)
        }
        .vegaElevation(isActive ? .raised : .flat)
        .onAppear {
            tab.ensureFaviconLoaded()
        }
    }
    
    private var isActive: Bool {
        return browserManager.currentTab(for: windowState)?.id == tab.id
    }
    
    private var isCurrentTab: Bool {
        return browserManager.currentTab(for: windowState)?.id == tab.id
    }
    private var backgroundColor: Color {
        if isCurrentTab {
            return VegaDesign.Surface.raised
        } else if isHovering {
            return VegaDesign.Surface.fill
        } else {
            return Color.clear
        }
    }
    private var textTab: Color {
        .primary
    }

}

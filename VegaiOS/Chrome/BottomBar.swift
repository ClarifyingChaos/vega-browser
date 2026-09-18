// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  BottomBar.swift
//  VegaiOS
//
//  The phone's only chrome. At rest: a dots row above back, the field and the
//  tabs button. On focus the dots and the buttons leave and the field takes the
//  width beside Cancel, so the bar is one row sitting on the keyboard. Forward
//  is edge-swipe only, as in Safari.
//

import SwiftUI
import VegaDesign
import VegaUI
import VegaWeb

struct BottomBar: View {
    @EnvironmentObject private var model: BrowserModel
    @Environment(TabsController.self) private var tabs
    @Environment(BrowserWindowState.self) private var window

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var session: PageSession? { tabs.selectedSession(in: window) }

    var body: some View {
        VStack(spacing: VegaDesign.Spacing.md) {
            if !isFocused {
                SpacesList()
                    .frame(height: VegaDesign.Spacing.xl)
            }

            HStack(spacing: VegaDesign.Spacing.md) {
                if !isFocused {
                    Button {
                        session?.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: VegaDesign.Size.iconButton)
                    }
                    .buttonStyle(.plain)
                    .disabled(session?.canGoBack != true)
                    .foregroundStyle(session?.canGoBack == true ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                }

                AddressField(session: session, text: $text, isFocused: $isFocused) {
                    model.navigate(text)
                    isFocused = false
                }

                if isFocused {
                    Button("Cancel") { isFocused = false }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                } else {
                    Button {
                        model.present(.tabs)
                    } label: {
                        Image(systemName: "square.on.square")
                            .frame(width: VegaDesign.Size.iconButton)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
            }
            .frame(height: VegaDesign.Size.bottomBar)
        }
        .padding(.horizontal, VegaDesign.Spacing.rowPadding)
        .padding(.vertical, VegaDesign.Spacing.md)
        .vegaGlassEffect(in: VegaDesign.Radius.shape(VegaDesign.Radius.xxl))
        .animation(VegaDesign.Motion.standard, value: isFocused)
        .gesture(
            // The swipe covers the whole bar, field included: it is the biggest
            // target and switching tabs is the point. minimumDistance keeps taps
            // going to the field.
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !isFocused,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 {
                        tabs.selectNext(in: window)
                    } else {
                        tabs.selectPrevious(in: window)
                    }
                    Haptics.alignment()
                }
        )
    }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  FeatureTourView.swift
//  Nook
//
//  FORK: a short tour of what Vega can do, with a button to try each one. Shown once (after onboarding or an
//  update), and any time from Help › Feature Tour or the command palette.
//

import SwiftUI
import NookDesign
import NookWeb

struct FeatureTourView: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @State private var page = 0

    static let seenKey = "fork.tour.seen"

    struct Stop {
        let symbol: String
        let title: String
        let detail: String
        let tryLabel: String?
        let action: (@MainActor (BrowserManager) -> Void)?
    }

    private let stops: [Stop] = [
        Stop(symbol: "sidebar.left", title: "Your tabs live in the sidebar",
             detail: "Spaces keep work and life apart: swipe sideways with two fingers to switch. Favorites sit on top, pinned tabs stay, and today's tabs tidy themselves into the Archive.",
             tryLabel: "Open the Library", action: { m in if let w = m.windowRegistry?.activeWindow { LibraryMotion.present(w) } }),
        Stop(symbol: "command", title: "One bar for everything",
             detail: "⌘T searches the web, your open tabs and history. Type a command's name, or > to list them all: Capture, Cast, Reader View, Task Manager and more.",
             tryLabel: "Show Commands", action: { m in m.windowRegistry?.activeWindow?.commandPalette?.open(prefill: ">") }),
        Stop(symbol: "scribble.variable", title: "Easels",
             detail: "A canvas for notes, links and images. Find them in the Library, the + menu, or the command palette.",
             tryLabel: "New Easel", action: { _ in EaselManager.shared.newEasel() }),
        Stop(symbol: "rectangle.split.2x1", title: "Peek, Split View and Notes",
             detail: "Links from other apps open in a floating Peek you can keep. Put two pages side by side, or jot a note right in the sidebar.",
             tryLabel: nil, action: nil),
        Stop(symbol: "key", title: "Passwords and sync",
             detail: "Saved logins live in your Keychain and fill after Touch ID. Sync keeps spaces, favorites, tabs and passwords the same on your Macs, through iCloud Drive or Google.",
             tryLabel: "Open Passwords", action: { m in m.openSettings(tab: .passwords) }),
        Stop(symbol: "hand.raised", title: "Privacy, on by default",
             detail: "Ads and trackers are blocked, sites open over HTTPS, and the Privacy Report shows what was stopped on each site.",
             tryLabel: "Privacy Report", action: { m in m.showPrivacyReport() }),
        Stop(symbol: "gauge.with.dots.needle.33percent", title: "Keep it light",
             detail: "Tabs you haven't used go to sleep. The Task Manager shows what each tab costs and puts any of them to sleep.",
             tryLabel: "Task Manager", action: { m in m.showTaskManager() }),
        Stop(symbol: "sparkles", title: "Ask Vega",
             detail: "The AI chat summarizes your tabs and can browse for you, asking before it acts. Use Apple Intelligence on your Mac or a provider you choose.",
             tryLabel: nil, action: nil),
    ]

    var body: some View {
        let stop = stops[page]
        VStack(spacing: NookDesign.Spacing.xl) {
            Spacer(minLength: 0)
            Image(systemName: stop.symbol)
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(height: 70)
                .accessibilityHidden(true)
            Text(stop.title).font(NookDesign.Font.display).multilineTextAlignment(.center)
            Text(stop.detail)
                .font(NookDesign.Font.bodyRegular)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
            if let label = stop.tryLabel, let action = stop.action {
                Button(label) { action(browserManager) }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Skip Tour") { finish() }.buttonStyle(.borderless)
                Spacer()
                HStack(spacing: NookDesign.Spacing.sm) {
                    ForEach(stops.indices, id: \.self) { i in
                        Circle().fill(i == page ? Color.primary : Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Page \(page + 1) of \(stops.count)")
                Spacer()
                if page > 0 { Button("Back") { page -= 1 } }
                Button(page == stops.count - 1 ? "Done" : "Next") {
                    if page == stops.count - 1 { finish() } else { page += 1 }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(NookDesign.Spacing.xxxl)
        .frame(width: 620, height: 520)
        .onAppear { UserDefaults.standard.set(true, forKey: Self.seenKey) }
    }

    private func finish() { VegaPanels.shared.close("featureTour") }
}

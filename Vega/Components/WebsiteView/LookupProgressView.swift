// Licensed under GPL-3.0. See LICENSE.
//
//  LookupProgressView.swift
//  Vega
//
//  What a tab shows while Look It Up works on its page: the request, the stage, the sites
//  being read and a way to stop. Native, so the page under it can neither draw nor press it.
//

import SwiftUI
import VegaDesign
import VegaUI
import VegaWeb

struct LookupProgressView: View {
    let session: PageSession

    @Environment(LookupManager.self) private var lookups
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The text keeps a reading width however wide the page is.
    private static let textWidth: CGFloat = 420, margin: CGFloat = 32

    var body: some View {
        if let stage = lookups.stage(forPage: session.url) {
            let hosts = lookups.hosts(forPage: session.url)
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xl) {
                Text(lookups.request(forPage: session.url) ?? "")
                    .font(VegaDesign.Font.titleLarge)
                    .lineLimit(3)
                    .accessibilityAddTraits(.isHeader)
                wave
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.md) {
                    line("Searching the web", current: stage == .searching)
                    if !hosts.isEmpty {
                        line(hosts.count == 1 ? "Reading 1 page" : "Reading \(hosts.count) pages", current: stage != .writing)
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            ForEach(Array(hosts.enumerated()), id: \.offset) { _, host in
                                Text(host)
                                    .font(VegaDesign.Font.bodyRegular)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, VegaDesign.Spacing.lg)
                    }
                    if stage == .writing {
                        line("Writing your page", current: true)
                    }
                }
                // No Return shortcut: it would take Return from the address bar.
                Button("Stop") { lookups.stop(page: session.url) }
                    .buttonStyle(RectNavButtonStyle())
                    .fixedSize()
            }
            .frame(maxWidth: Self.textWidth, alignment: .leading)
            .padding(Self.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            .animation(VegaDesign.Motion.settle, value: stage)
        }
    }

    private func line(_ text: String, current: Bool) -> some View {
        Text(text)
            .font(VegaDesign.Font.body)
            .foregroundStyle(current ? .primary : .secondary)
    }

    /// The rule that ripples while a model works, as the sidebar's separator does for the tab
    /// organizer. Reduce Motion leaves it a still rule.
    private var wave: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            WaveLine(
                amplitude: reduceMotion ? 0 : VegaDesign.Size.waveAmplitude,
                phase: timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: VegaDesign.Motion.wavePeriod)
                    / VegaDesign.Motion.wavePeriod * 2 * .pi
            )
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: VegaDesign.Size.hairlineWidth, lineCap: .round))
        }
        .frame(height: VegaDesign.Size.waveAmplitude * 4)
        .accessibilityHidden(true)
    }
}

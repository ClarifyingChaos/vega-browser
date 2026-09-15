//
//  YouTube.swift
//  Vega
//
//  Created by Claude on 26/03/2026.
//

import SwiftUI

struct SettingsYouTubeTab: View {
    @Environment(\.vegaSettings) var vegaSettings

    var body: some View {
        @Bindable var settings = vegaSettings
        Form {
            Section {
                Picker("Videos per row", selection: $settings.youTubeVideosPerRow) {
                    Text("Automatic").tag(0)
                    ForEach(YouTubeTweaks.videosPerRowRange, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Toggle("Frame thumbnails", isOn: $settings.youTubeFrameThumbnails)
                Toggle("Disable hover previews", isOn: $settings.youTubeNoHoverPreview)
            } header: {
                Text("Layout")
            } footer: {
                Text("Videos per row applies to Home, Subscriptions, and channel pages. Frame thumbnails show a still from the video instead of the uploader's thumbnail. Changes apply when a YouTube page next loads.")
            }

            Section("Hide") {
                Toggle("Shorts", isOn: $settings.youTubeHideShorts)
                ForEach(YouTubeHomeSection.allCases) { section in
                    Toggle("Home: \(section.displayName)", isOn: Binding(
                        get: { vegaSettings.youTubeHiddenHomeSections.contains(section.rawValue) },
                        set: { hidden in
                            vegaSettings.youTubeHiddenHomeSections.removeAll { $0 == section.rawValue }
                            if hidden { vegaSettings.youTubeHiddenHomeSections.append(section.rawValue) }
                        }
                    ))
                }
            }

            Section {
                Toggle("SponsorBlock", isOn: $settings.sponsorBlockEnabled)
            } footer: {
                Text("Skip sponsored segments, intros, and other non-content on YouTube using community data from SponsorBlock.")
            }

            if vegaSettings.sponsorBlockEnabled {
                Section("Categories") {
                    ForEach(SponsorBlockCategory.allCases) { category in
                        Picker(selection: Binding(
                            get: {
                                SponsorBlockSkipOption(rawValue: vegaSettings.sponsorBlockCategoryOptions[category.rawValue] ?? category.defaultSkipOption.rawValue) ?? category.defaultSkipOption
                            },
                            set: { newValue in
                                vegaSettings.sponsorBlockCategoryOptions[category.rawValue] = newValue.rawValue
                            }
                        )) {
                            ForEach(SponsorBlockSkipOption.allCases) { option in
                                Text(option.displayName).tag(option)
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                                    Text(category.displayName)
                                    Text(category.description)
                                        .font(VegaDesign.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Circle()
                                    .fill(sponsorBlockCategoryColor(category))
                                    .frame(
                                        width: VegaDesign.Size.statusDot,
                                        height: VegaDesign.Size.statusDot
                                    )
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sponsorBlockCategoryColor(_ category: SponsorBlockCategory) -> Color {
        switch category {
        case .sponsor: return .green
        case .selfpromo: return .yellow
        case .exclusive_access: return Color(red: 0, green: 0.54, blue: 0.36)
        case .interaction: return .purple
        case .intro: return .cyan
        case .outro: return .blue
        case .preview: return .teal
        case .filler: return .indigo
        case .music_offtopic: return .orange
        case .poi_highlight: return .pink
        }
    }
}

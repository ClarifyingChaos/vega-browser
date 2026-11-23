// Licensed under GPL-3.0. See LICENSE.
//
//  SpaceAccent.swift
//  NookUI
//
//  Preset accent colors for spaces. A space's accent is its gradient's
//  primary color; new spaces are written as a single-node gradient.
//

import Foundation

public enum SpaceAccent {
    public static let presets: [(name: String, hex: String)] = [
        // Apple's blue first: the default for a new space and for the app's own chrome.
        ("Blue", "#0A84FF"),
        ("Teal", "#3A8FA3"),
        ("Orange", "#D6603A"),
        ("Violet", "#6B5BD6"),
        ("Green", "#2F9E6A"),
        ("Red", "#D64545"),
        ("Deep Blue", "#2F6FDB"),
        ("Pink", "#C94F8E"),
        ("Graphite", "#6E6E73"),
    ]

    public static let defaultHex = presets[0].hex
}

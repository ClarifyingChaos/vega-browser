// Licensed under GPL-3.0. See LICENSE.
//
//  HoverAnchor.swift
//  Nook
//
//  FORK: a row or tile under the pointer reports its frame here, so the window can hang a page preview beside it.
//

import SwiftUI

/// The frame of the sidebar row or favorite the pointer is on, by item; empty when none is.
public struct TabHoverAnchorKey: PreferenceKey {
    public static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    public static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

//
//  Haptics.swift
//  VegaUI
//
//  The one platform split in VegaUI's own code: AppKit's alignment feedback has no
//  cross-platform spelling.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Haptics {
    /// The small click the sidebar plays when a selection snaps into place.
    @MainActor static func alignment() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #else
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

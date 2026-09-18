// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  VegaSettingsEnvironment.swift
//  VegaUI
//
//  The SwiftUI glue VegaSettings cannot carry: the settings service lives in a
//  Foundation-only package, so the environment key lives here, where the shared
//  settings bodies and both platforms' app targets all reach one key.
//

import VegaSettings
import SwiftUI

private struct VegaSettingsServiceKey: EnvironmentKey {
    @MainActor
    static var defaultValue: VegaSettingsService {
        // Never reached in either app: both targets inject the real service at
        // the root. EnvironmentKey requires a default, so this is it.
        return VegaSettingsService()
    }
}

extension EnvironmentValues {
    public var vegaSettings: VegaSettingsService {
        get { self[VegaSettingsServiceKey.self] }
        set { self[VegaSettingsServiceKey.self] = newValue }
    }
}

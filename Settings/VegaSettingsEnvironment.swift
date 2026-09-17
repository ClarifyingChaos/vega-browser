//
//  VegaSettingsEnvironment.swift
//  Vega
//
//  The SwiftUI glue VegaSettings cannot carry: the settings service lives in a
//  Foundation-only package, so the environment key and the SwiftUI-typed
//  conveniences over its value types stay here.
//

import VegaSettings
import SwiftUI

// MARK: - Environment Key

private struct VegaSettingsServiceKey: EnvironmentKey {
    @MainActor
    static var defaultValue: VegaSettingsService {
        // This should never be called since we always inject from VegaApp
        // But EnvironmentKey protocol requires a default value
        return VegaSettingsService()
    }
}

extension EnvironmentValues {
    var vegaSettings: VegaSettingsService {
        get { self[VegaSettingsServiceKey.self] }
        set { self[VegaSettingsServiceKey.self] = newValue }
    }
}

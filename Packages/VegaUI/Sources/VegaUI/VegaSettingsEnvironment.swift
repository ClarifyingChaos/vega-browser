// Licensed under GPL-3.0. See LICENSE.
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
    // SwiftUI evaluates defaults while resolving environment values, including
    // during updates to trees that inject the real service. Reuse one instance;
    // constructing a service here repeatedly registers and reads all settings.
    @MainActor
    static let defaultValue = VegaSettingsService()
}

extension EnvironmentValues {
    public var vegaSettings: VegaSettingsService {
        get { self[VegaSettingsServiceKey.self] }
        set { self[VegaSettingsServiceKey.self] = newValue }
    }
}

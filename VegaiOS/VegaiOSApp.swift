// Licensed under GPL-3.0. See LICENSE.
//
//  VegaiOSApp.swift
//  VegaiOS
//

import SwiftUI
import VegaUI

@main
struct VegaiOSApp: App {
    @StateObject private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .vegaEnvironment(model)
        }
    }
}

extension View {
    /// Everything the shared rows, menus and settings bodies read. Sheets do not
    /// inherit these, so the sheet contents apply the same modifier.
    func vegaEnvironment(_ model: BrowserModel) -> some View {
        self
            .environmentObject(model)
            .environment(model.tabs)
            .environment(model.window)
            .environment(model.windowRegistry)
            .environment(model.settings)
            .environment(\.vegaSettings, model.settings)
            .environment(\.tabActions, model)
            .environment(\.contentBlocker, model.blocker)
            .environment(\.siteRouting, model.siteRouting)
    }
}

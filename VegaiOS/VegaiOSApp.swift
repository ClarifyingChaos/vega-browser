// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  VegaiOSApp.swift
//  VegaiOS
//

import SwiftUI

@main
struct VegaiOSApp: App {
    @StateObject private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
        }
    }
}

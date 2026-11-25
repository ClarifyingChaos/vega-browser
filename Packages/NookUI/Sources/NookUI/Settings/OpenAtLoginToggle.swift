// Licensed under GPL-3.0. See LICENSE.
//
//  OpenAtLoginToggle.swift
//  NookUI
//
//  FORK: Settings › General › Open Vega at login, through macOS Login Items (SMAppService), so it also shows in
//  System Settings › General › Login Items and the person can turn it off there.
//

#if os(macOS)
import SwiftUI
import ServiceManagement

struct OpenAtLoginToggle: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled
    @State private var needsApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var failure: String?

    var body: some View {
        Toggle("Open Vega at login", isOn: Binding(get: { isOn }, set: set))
            .onAppear(perform: refresh)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        if needsApproval {
            Button("Allow in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
        }
        if let failure {
            Text(failure)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func set(_ on: Bool) {
        failure = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            failure = "macOS did not change the login item: \(error.localizedDescription)"
        }
        refresh()
    }

    /// The truth is what macOS reports: the person can change it in System Settings at any time.
    private func refresh() {
        let status = SMAppService.mainApp.status
        isOn = status == .enabled
        needsApproval = status == .requiresApproval
    }
}
#endif

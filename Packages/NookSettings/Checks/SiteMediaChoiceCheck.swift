// Licensed under GPL-3.0. See LICENSE.
//
//  SiteMediaChoiceCheck.swift
//  Vega
//
//  Auto-Play and sidebar video choices saved by 1.8.x in the permission records move to SitePreferences,
//  which playback reads. NookSettings has no test target, so this compiles the shipped source directly:
//
//    swiftc Packages/NookSettings/Sources/NookSettings/SitePermission.swift Packages/NookSettings/Sources/NookSettings/SitePreferences.swift \
//           Packages/NookSettings/Checks/SiteMediaChoiceCheck.swift -o /tmp/site-media-check && /tmp/site-media-check
//

import Foundation

@main
@MainActor
struct SiteMediaChoiceCheck {
    static func main() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("site-media-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let prefs = SitePreferences(directory: dir)
        prefs.update("both.test") { $0.autoplay = .stopMediaWithSound }

        var records: [String: SitePermissionRecord] = [:]
        records.update("www.Never.test") { $0.autoplay = .never; $0.policies[.camera] = .block }
        records.update("video.test") { $0.autoPictureInPicture = false }
        records.update("both.test") { $0.autoplay = .never }
        records.update("cam.test") { $0.policies[.microphone] = .allow }
        prefs.adopt(&records)

        precondition(prefs.prefs(for: "never.test").autoplay == .never, "a dead choice now applies")
        precondition(prefs.prefs(for: "video.test").autoPiP == false)
        precondition(prefs.prefs(for: "both.test").autoplay == .stopMediaWithSound, "the choice that applied wins")
        precondition(records.keys.sorted() == ["cam.test", "never.test"], "empty records are dropped")
        precondition(records["never.test"]?.policies[.camera] == .block && records["never.test"]?.autoplay == nil)

        let before = records
        prefs.adopt(&records)
        precondition(records == before, "running again changes nothing")
        precondition(SitePreferences(directory: dir).prefs(for: "never.test").autoplay == .never, "saved to disk")
        precondition(SiteAutoplay.allCases.map(\.label) == ["Allow All Auto-Play", "Stop Media with Sound", "Never Auto-Play"])
        print("SiteMediaChoiceCheck passed")
    }
}

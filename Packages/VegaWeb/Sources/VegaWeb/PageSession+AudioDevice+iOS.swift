// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  PageSession+AudioDevice+iOS.swift
//  VegaWeb
//
//  iOS has no hardware audio object API. Playing state comes from the page's media script alone.
//

#if os(iOS)
import Foundation

extension PageSession {
    func setupCoreAudioPropertyListeners() {}
    func removeCoreAudioPropertyListeners() {}
    func isDefaultAudioDeviceActive() -> Bool { false }
}
#endif

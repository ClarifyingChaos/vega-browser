// Licensed under GPL-3.0. See LICENSE.
//
//  EaselStoreCheck.swift
//  Nook
//
//  Easel limits: a file over 25 MB is refused, a huge picture is scaled to 2400 px on its long side, and a
//  tampered easel file cannot point an image outside the Easels folder. Compiles the shipped source:
//
//    swiftc -parse-as-library Nook/Components/Easel/EaselModel.swift scripts/tests/EaselStoreCheck.swift -o /tmp/easel-store-check && /tmp/easel-store-check

import AppKit
import Foundation

@main
struct EaselStoreCheck {
    @MainActor static func main() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("easel-check-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Over 25 MB: refused without being read. A real small picture: accepted.
        let big = dir.appendingPathComponent("big.png")
        FileManager.default.createFile(atPath: big.path, contents: nil)
        let handle = try! FileHandle(forWritingTo: big)
        try! handle.truncate(atOffset: 25_000_001)
        try! handle.close()
        precondition(EaselStore.loadImage(at: big) == nil, "a file over 25 MB is refused")
        precondition(EaselStore.loadImage(at: dir.appendingPathComponent("missing.png")) == nil, "a missing file is refused")
        let small = NSImage(size: NSSize(width: 40, height: 20), flipped: false) { NSColor.red.setFill(); $0.fill(); return true }
        let smallFile = dir.appendingPathComponent("small.png")
        try! NSBitmapImageRep(data: small.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: smallFile)
        precondition(EaselStore.loadImage(at: smallFile) != nil, "a small picture loads")

        // A 6000 x 3000 picture is stored at 2400 x 1200 at most; a small one is left alone.
        let store = EaselStore.shared
        let huge = NSImage(size: NSSize(width: 6000, height: 3000), flipped: false) { NSColor.blue.setFill(); $0.fill(); return true }
        let saved = store.saveImage(huge)
        precondition(saved != nil, "a huge picture still saves")
        let stored = NSBitmapImageRep(data: try! Data(contentsOf: store.imageURL(saved!.file)))!
        precondition(max(stored.pixelsWide, stored.pixelsHigh) <= 2400, "stored long side is at most 2400 px, was \(stored.pixelsWide)")
        precondition(saved!.size.width <= 360, "it lands on the canvas at card width")
        try? FileManager.default.removeItem(at: store.imageURL(saved!.file))

        // A tampered file name stays inside the folder.
        let url = store.imageURL("../../../etc/passwd")
        precondition(url.deletingLastPathComponent().standardizedFileURL == store.folder.standardizedFileURL && url.lastPathComponent == "passwd", "a path in a file name is cut to its last part")
        print("EaselStoreCheck ok")
    }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  EaselModel.swift
//  Vega
//
//  FORK: Easels, a freeform canvas for collecting notes, pages and images. Each easel is one JSON file in
//  the app's Easels folder, with its images beside it.
//

import AppKit
import SwiftUI

struct EaselItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case note, link, image }
    var id = UUID()
    var kind: Kind
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    /// A note's text, a link's title, an image's caption.
    var text = ""
    var url: String?
    /// An image's file name in the Easels folder.
    var file: String?
}

struct Easel: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var items: [EaselItem] = []
    var modified = Date()
}

@MainActor
final class EaselStore: ObservableObject {
    static let shared = EaselStore()
    @Published private(set) var easels: [Easel] = []
    private var pendingSave: [UUID: Task<Void, Never>] = [:]

    /// A picture from a file, refused when the file is over 25 MB.
    static func loadImage(at url: URL) -> NSImage? {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0, size <= 25_000_000 else { return nil }
        return NSImage(contentsOf: url)
    }

    let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Vega").appendingPathComponent("Easels", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let decoder = JSONDecoder()
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        easels = files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Easel.self, from: Data(contentsOf: $0)) }
            .sorted { $0.modified > $1.modified }
    }

    func easel(_ id: UUID) -> Easel? { easels.first { $0.id == id } }

    @discardableResult
    func create(named name: String) -> Easel {
        let easel = Easel(name: name)
        easels.insert(easel, at: 0)
        write(easel)
        return easel
    }

    func delete(_ id: UUID) {
        guard let easel = easel(id) else { return }
        for file in easel.items.compactMap(\.file) { try? FileManager.default.removeItem(at: imageURL(file)) }
        easels.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    /// Changes one easel and saves it a moment later (a drag changes it many times a second).
    func mutate(_ id: UUID, _ body: (inout Easel) -> Void) {
        guard let index = easels.firstIndex(where: { $0.id == id }) else { return }
        body(&easels[index])
        easels[index].modified = Date()
        let easel = easels[index]
        pendingSave[id]?.cancel()
        pendingSave[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.write(easel)
        }
    }

    /// Writes any change still waiting, at quit.
    func flush() {
        for easel in easels { write(easel) }
    }

    private func fileURL(_ id: UUID) -> URL { folder.appendingPathComponent("\(id.uuidString).json") }
    /// Only a bare file name: a tampered easel file cannot point outside the folder.
    func imageURL(_ file: String) -> URL { folder.appendingPathComponent((file as NSString).lastPathComponent) }

    private func write(_ easel: Easel) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(easel) { try? data.write(to: fileURL(easel.id), options: .atomic) }
    }

    /// Stores an image in the Easels folder and returns its file name and size on the canvas.
    func saveImage(_ image: NSImage) -> (file: String, size: CGSize)? {
        // A huge picture would fill the disk and memory: scale it so its long side is at most 2400 px.
        let longest = max(image.size.width, image.size.height)
        var image = image
        if longest > 2400, let rep = image.representations.first {
            let scale = 2400 / longest
            let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let small = NSImage(size: target)
            small.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
            small.unlockFocus()
            _ = rep
            image = small
        }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        let name = "\(UUID().uuidString).png"
        guard (try? data.write(to: imageURL(name), options: .atomic)) != nil else { return nil }
        let scale = min(1, 360 / max(image.size.width, 1))
        return (name, CGSize(width: image.size.width * scale, height: image.size.height * scale))
    }
}

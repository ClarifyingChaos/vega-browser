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
    func imageURL(_ file: String) -> URL { folder.appendingPathComponent(file) }

    private func write(_ easel: Easel) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(easel) { try? data.write(to: fileURL(easel.id), options: .atomic) }
    }

    /// Stores an image in the Easels folder and returns its file name and size on the canvas.
    func saveImage(_ image: NSImage) -> (file: String, size: CGSize)? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        let name = "\(UUID().uuidString).png"
        guard (try? data.write(to: imageURL(name), options: .atomic)) != nil else { return nil }
        let scale = min(1, 360 / max(image.size.width, 1))
        return (name, CGSize(width: image.size.width * scale, height: image.size.height * scale))
    }
}

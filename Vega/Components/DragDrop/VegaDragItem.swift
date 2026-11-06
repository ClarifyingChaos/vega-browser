// Licensed under GPL-3.0. See LICENSE.
//
//  VegaDragItem.swift
//  Vega
//

import Foundation
import AppKit
import VegaTabsCore
import UniformTypeIdentifiers

extension UTType {
    static let vegaTabItem = UTType(exportedAs: "com.vega.tab-drag-item")
}

extension NSPasteboard.PasteboardType {
    static let vegaTabItem = NSPasteboard.PasteboardType("com.vega.tab-drag-item")
}

// MARK: - Drop Zone Identity

/// A place a dragged item can land.
enum DropZoneID: Hashable {
    /// A space's favorites grid.
    case favorites(spaceID: UUID)
    /// The rows of a sidebar section (`.pinned` or `.tabs`).
    case section(Parent)
    /// A target without rows (space title, space switcher) that receives the item as a whole.
    case target(Parent)
}

// MARK: - Drag Item

struct VegaDragItem: Codable, Equatable {
    /// The dragged `Item` id (name kept for existing pasteboard readers).
    let tabId: UUID
    var title: String
    var urlString: String
    /// Tabs dragged together when the row is part of a multi-selection; nil for one.
    var count: Int?

    init(tabId: UUID, title: String, urlString: String = "", count: Int? = nil) {
        self.tabId = tabId
        self.title = title
        self.urlString = urlString
        self.count = count
    }
}

extension VegaDragItem {
    func writeToPasteboard(_ pasteboard: NSPasteboard) {
        pasteboard.declareTypes([.vegaTabItem, .string], owner: nil)
        do {
            let data = try JSONEncoder().encode(self)
            pasteboard.setData(data, forType: .vegaTabItem)
        } catch {
            NSLog("VegaDragItem encoding failed: %@", String(describing: error))
        }
        pasteboard.setString(tabId.uuidString, forType: .string)
    }

    static func fromPasteboard(_ pasteboard: NSPasteboard) -> VegaDragItem? {
        guard let data = pasteboard.data(forType: .vegaTabItem) else { return nil }
        return try? JSONDecoder().decode(VegaDragItem.self, from: data)
    }
}

//
//  VegaDragItem.swift
//  Vega
//

import Foundation
import AppKit
import UniformTypeIdentifiers

extension UTType {
    static let vegaTabItem = UTType(exportedAs: "com.vega.tab-drag-item")
}

extension NSPasteboard.PasteboardType {
    static let vegaTabItem = NSPasteboard.PasteboardType("com.vega.tab-drag-item")
}

// MARK: - Drop Zone Identity

enum DropZoneID: Hashable {
    case essentials
    case spacePinned(UUID)
    case spaceRegular(UUID)
    case folder(UUID)

    var asDragContainer: TabDragManager.DragContainer {
        switch self {
        case .essentials: return .essentials
        case .spacePinned(let id): return .spacePinned(id)
        case .spaceRegular(let id): return .spaceRegular(id)
        case .folder(let id): return .folder(id)
        }
    }

    var spaceId: UUID? {
        switch self {
        case .essentials: return nil
        case .spacePinned(let id): return id
        case .spaceRegular(let id): return id
        case .folder: return nil
        }
    }
}

// MARK: - Drag Item

struct VegaDragItem: Codable, Equatable {
    let tabId: UUID
    var title: String
    var urlString: String

    init(tabId: UUID, title: String, urlString: String = "") {
        self.tabId = tabId
        self.title = title
        self.urlString = urlString
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

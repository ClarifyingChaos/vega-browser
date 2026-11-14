// Licensed under GPL-3.0. See LICENSE.
//
//  SharedSpace.swift
//  NookWeb
//
//  FORK: the file format of a shared space (`.vegaspace`). See TabsController+Share.swift.
//

import Foundation

public struct SharedSpace: Codable, Equatable, Sendable {
    public static let formatVersion = 1
    public var format = SharedSpace.formatVersion
    public var name: String
    public var icon: String
    public var accentHex: String
    public var favorites: [Node]
    public var pinned: [Node]
    public var tabs: [Node]

    /// A tab (with an address) or a folder (with children).
    public struct Node: Codable, Equatable, Sendable {
        public var title: String
        public var url: String?
        public var children: [Node]
        public init(title: String, url: String? = nil, children: [Node] = []) {
            self.title = title; self.url = url; self.children = children
        }
    }

    public var tabCount: Int {
        func count(_ nodes: [Node]) -> Int { nodes.reduce(0) { $0 + ($1.url == nil ? 0 : 1) + count($1.children) } }
        return count(favorites) + count(pinned) + count(tabs)
    }

    /// The most items one file may bring in, so a bad or hostile file cannot flood the tree.
    static let limit = 600
    static let titleLimit = 200
}

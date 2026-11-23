// Licensed under GPL-3.0. See LICENSE.
//
//  EaselView.swift
//  Vega
//
//  FORK: one easel: a big scrolling canvas of cards you drag and resize, with a tool rail down the left side, as in
//  Milanote. Notes, to-do lists, pictures and page cards (with the page's picture on them). Drop images, links or
//  text on it, paste, or use the rail. A page card opens its page in a new tab.
//

import SwiftUI
import UniformTypeIdentifiers

/// The easel's colours: a light grey desk with white cards, or a dark one with raised grey cards.
private enum EaselPalette {
    static let desk = Color(nsColor: NSColor(name: nil) { $0.isDark ? NSColor(white: 0.13, alpha: 1) : NSColor(white: 0.935, alpha: 1) })
    static let card = Color(nsColor: NSColor(name: nil) { $0.isDark ? NSColor(white: 0.21, alpha: 1) : .white })
    static let chrome = Color(nsColor: NSColor(name: nil) { $0.isDark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.985, alpha: 1) })
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

struct EaselView: View {
    let easelID: UUID
    /// The page in front, a picture of it, and how to open a card's page.
    let currentPage: () -> (title: String, url: URL)?
    let currentThumbnail: () async -> NSImage?
    let openPage: (URL) -> Void
    @ObservedObject private var store = EaselStore.shared
    @State private var selection: UUID?
    private let canvasSize = CGSize(width: 4000, height: 3000)

    private var easel: Easel? { store.easel(easelID) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The canvas starts under the top bar, so its scroll bar does too.
            VStack(spacing: 0) {
                topBar
                canvas
            }
            toolRail.padding(.leading, 14).padding(.top, 76)
        }
        .frame(minWidth: 640, minHeight: 440)
        .ignoresSafeArea(.container, edges: .top)
        .onPasteCommand(of: [.image, .url, .plainText]) { providers in
            _ = handleDrop(providers, at: nextSpot())
        }
    }

    private var canvas: some View {
        ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    DotGrid().frame(width: canvasSize.width, height: canvasSize.height)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = nil }
                    ForEach(easel?.items ?? []) { item in
                        EaselCard(item: item, selected: selection == item.id,
                                  select: { selection = item.id },
                                  update: { change in store.mutate(easelID) { easel in
                                      if let i = easel.items.firstIndex(where: { $0.id == item.id }) { change(&easel.items[i]) } } },
                                  remove: { remove(item) },
                                  open: openPage)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                .onDrop(of: [.fileURL, .url, .plainText], isTargeted: nil) { providers, location in
                    handleDrop(providers, at: location)
                }
            }
            // No scroll bars: the canvas is bigger than the window both ways, and old-style scrollers leave a white square
            // in the corner. Trackpad, wheel and shift-wheel still pan it.
            .scrollIndicators(.hidden)
            .background(EaselPalette.desk)
    }

    // MARK: - Chrome

    private var topBar: some View {
        ZStack {
            TextField("Untitled Easel", text: Binding(get: { easel?.name ?? "" }, set: { name in store.mutate(easelID) { $0.name = name } }))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .frame(maxWidth: 360)
            HStack {
                Spacer()
                let count = easel?.items.count ?? 0
                Text(count == 1 ? "1 card" : "\(count) cards").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.trailing, 18)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(EaselPalette.chrome)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5) }
    }

    private var toolRail: some View {
        VStack(spacing: 4) {
            RailButton(title: "Note", symbol: "text.alignleft") { addNote() }
            Menu {
                Button("Add This Page") { addCurrentPage() }.disabled(currentPage() == nil)
                Button("Add Link from Clipboard") { addClipboardLink() }
            } label: { RailLabel(title: "Link", symbol: "link") }
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            RailButton(title: "To-do", symbol: "checklist") { addTodo() }
            RailButton(title: "Image", symbol: "photo") { chooseImage() }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(EaselPalette.chrome, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    // MARK: - Adding

    /// Where the next card goes, stepped so a run of them does not stack exactly.
    private func nextSpot() -> CGPoint {
        let n = Double(easel?.items.count ?? 0)
        return CGPoint(x: 140 + n.truncatingRemainder(dividingBy: 8) * 28, y: 110 + n.truncatingRemainder(dividingBy: 8) * 28)
    }

    private func add(_ item: EaselItem) {
        store.mutate(easelID) { $0.items.append(item) }
        selection = item.id
    }

    private func addNote(text: String = "", at point: CGPoint? = nil) {
        let p = point ?? nextSpot()
        add(EaselItem(kind: .note, x: p.x, y: p.y, w: 240, h: 170, text: text))
    }

    private func addTodo() {
        let p = nextSpot()
        add(EaselItem(kind: .todo, x: p.x, y: p.y, w: 260, h: 200, todos: [EaselTodo(text: "")]))
    }

    /// A page card; the picture comes a moment later, from the snapshot given or from the page's own share picture.
    private func addLink(title: String, url: URL, at point: CGPoint? = nil, snapshot: NSImage? = nil, fetchPicture: Bool = true) {
        let p = point ?? nextSpot()
        let item = EaselItem(kind: .link, x: p.x, y: p.y, w: 280, h: 230, text: title, url: url.absoluteString)
        add(item)
        Task { @MainActor in
            let picture: NSImage?
            if let snapshot { picture = snapshot } else if fetchPicture { picture = await EaselThumbnails.fetch(for: url) } else { picture = nil }
            if let picture { store.attachThumbnail(picture, to: item.id, in: easelID) }
        }
    }

    private func addCurrentPage() {
        guard let page = currentPage() else { return }
        let point = nextSpot()
        Task { @MainActor in
            let snapshot = await currentThumbnail()
            addLink(title: page.title, url: page.url, at: point, snapshot: snapshot)
        }
    }

    private func addClipboardLink() {
        guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else { return }
        addLink(title: url.host() ?? text, url: url)
    }

    private func addImage(_ image: NSImage, at point: CGPoint? = nil) {
        guard let saved = store.saveImage(image) else { return }
        let p = point ?? nextSpot()
        add(EaselItem(kind: .image, x: p.x, y: p.y, w: saved.size.width, h: saved.size.height, file: saved.file))
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { if let image = EaselStore.loadImage(at: url) { addImage(image) } }
    }

    private func remove(_ item: EaselItem) {
        if let file = item.file { try? FileManager.default.removeItem(at: store.imageURL(file)) }
        store.mutate(easelID) { $0.items.removeAll { $0.id == item.id } }
    }

    /// Images become image cards, web addresses become page cards, other text becomes a note.
    private func handleDrop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var spot = location
        for provider in providers {
            let here = spot
            spot.x += 24; spot.y += 24
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async { addImage(image, at: here) }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        if let image = EaselStore.loadImage(at: url) { addImage(image, at: here) }
                        else { addNote(text: url.lastPathComponent, at: here) }
                    }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { addLink(title: url.host() ?? url.absoluteString, url: url, at: here) }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text, !text.isEmpty else { return }
                    DispatchQueue.main.async {
                        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil {
                            addLink(title: url.host() ?? text, url: url, at: here)
                        } else { addNote(text: text, at: here) }
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Rail

private struct RailLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 15, weight: .regular)).frame(height: 18)
            Text(title).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.primary.opacity(0.78))
        .frame(width: 48, height: 46)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RailButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) { RailLabel(title: title, symbol: symbol) }
            .buttonStyle(.plain)
            .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .onHover { hovering = $0 }
    }
}

/// A faint dot grid, so the canvas reads as a surface you can place things on.
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 32
            var path = Path()
            for x in stride(from: step, to: size.width, by: step) {
                for y in stride(from: step, to: size.height, by: step) { path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)) }
            }
            context.fill(path, with: .color(.primary.opacity(0.10)))
        }
    }
}

// MARK: - Cards

struct EaselCard: View {
    let item: EaselItem
    let selected: Bool
    let select: () -> Void
    let update: (@escaping (inout EaselItem) -> Void) -> Void
    let remove: () -> Void
    let open: (URL) -> Void
    @State private var drag: CGSize = .zero
    @State private var resize: CGSize = .zero
    /// True from the first movement of a drag to its end: the pointer is a closed hand while the card is held.
    @State private var holding = false

    private var width: Double { max(140, item.w + resize.width) }
    private var height: Double { max(item.kind == .link ? 150 : 64, item.h + resize.height) }
    private let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    /// Page and picture cards move by any part of them; notes and lists hold text, so they move by the strip along the top.
    private var movesFromBody: Bool { item.kind == .link || item.kind == .image }

    /// In the window's space: the card moves under the pointer, so a gesture measured in the card's own space would
    /// shrink as it went and the card would stall.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { holding = true; drag = $0.translation; select() }
            .onEnded { value in
                holding = false
                drag = .zero
                update { $0.x += value.translation.width; $0.y += value.translation.height }
            }
    }

    private var gripStrip: some View {
        Capsule().fill(Color.primary.opacity(selected ? 0.28 : 0.12)).frame(width: 30, height: 4)
            .frame(maxWidth: .infinity).frame(height: 16)
            .background(Color.clear)
            .contentShape(Rectangle())
            .pointerStyle(holding ? .grabActive : .grabIdle)
            .gesture(moveGesture)
    }

    var body: some View {
        content
            .frame(width: width, height: height)
            .background(EaselPalette.card, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 0.75))
            .shadow(color: .black.opacity(selected ? 0.22 : 0.10), radius: selected ? 10 : 5, y: 2)
            .overlay(alignment: .top) { if !movesFromBody { gripStrip } }
            .overlay(alignment: .bottomTrailing) { resizeHandle }
            .offset(x: item.x + drag.width, y: item.y + drag.height)
            .gesture(moveGesture, isEnabled: movesFromBody)
            .pointerStyle(holding ? .grabActive : (movesFromBody ? .grabIdle : nil))
            .contextMenu {
                if let text = item.url, let url = URL(string: text) {
                    Button("Open Page") { open(url) }
                    Button("Copy Link") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
                    Divider()
                }
                Button("Remove from Easel", role: .destructive, action: remove)
            }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .note:
            ZStack(alignment: .topLeading) {
                if item.text.isEmpty { Text("Write something…").foregroundStyle(.tertiary).padding(.top, 22).padding(.leading, 12).allowsHitTesting(false) }
                TextEditor(text: Binding(get: { item.text }, set: { text in update { $0.text = text } }))
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(.horizontal, 8).padding(.bottom, 8).padding(.top, 14)
            }
        case .todo:
            todoList
        case .link:
            linkCard
        case .image:
            if let file = item.file, let image = NSImage(contentsOf: EaselStore.shared.imageURL(file)) {
                Image(nsImage: image).resizable().scaledToFill()
            } else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
    }

    // MARK: Page card

    private var pageHost: String { URL(string: item.url ?? "")?.host()?.replacingOccurrences(of: "www.", with: "") ?? "" }

    // Not a Button: a button takes the press, and the card could not be dragged by its body.
    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(item.text.isEmpty ? (pageHost.isEmpty ? "Page" : pageHost) : item.text)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 9, weight: .semibold))
                    Text(pageHost).lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            select()
            if let text = item.url, let url = URL(string: text) { open(url) }
        }
        .accessibilityAddTraits(.isLink)
    }

    @ViewBuilder private var thumbnail: some View {
        if let file = item.file, let image = NSImage(contentsOf: EaselStore.shared.imageURL(file)) {
            Image(nsImage: image).resizable().scaledToFill().frame(minWidth: 0, minHeight: 0)
        } else {
            ZStack {
                LinearGradient(colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 6) {
                    Image(systemName: "globe").font(.system(size: 24, weight: .light)).foregroundStyle(Color.accentColor.opacity(0.8))
                    Text(pageHost).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    // MARK: To-do card

    private var todoList: some View {
        let todos = item.todos ?? []
        return VStack(alignment: .leading, spacing: 6) {
            TextField("To-do list", text: Binding(get: { item.text }, set: { text in update { $0.text = text } }))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold, design: .serif))
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(todos) { todo in
                        HStack(spacing: 7) {
                            Button {
                                update { change in if let i = change.todos?.firstIndex(where: { $0.id == todo.id }) { change.todos?[i].done.toggle() } }
                            } label: {
                                Image(systemName: todo.done ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 14)).foregroundStyle(todo.done ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Item", text: Binding(
                                get: { todo.text },
                                set: { text in update { change in if let i = change.todos?.firstIndex(where: { $0.id == todo.id }) { change.todos?[i].text = text } } }))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .strikethrough(todo.done)
                                .foregroundStyle(todo.done ? .secondary : .primary)
                                .onSubmit { addTodo(after: todo.id) }
                            Button {
                                update { $0.todos?.removeAll { $0.id == todo.id } }
                            } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary) }
                                .buttonStyle(.plain)
                        }
                    }
                    Button { addTodo(after: todos.last?.id) } label: {
                        Label("Add item", systemImage: "plus").font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).padding(.top, 2)
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 18)
    }

    private func addTodo(after id: UUID?) {
        update { change in
            var list = change.todos ?? []
            let index = id.flatMap { id in list.firstIndex { $0.id == id } }.map { $0 + 1 } ?? list.count
            list.insert(EaselTodo(text: ""), at: index)
            change.todos = list
        }
    }

    // MARK: Resize

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            .frame(width: 22, height: 22).contentShape(Rectangle())
            .pointerStyle(.frameResize(position: .bottomTrailing))
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { resize = $0.translation }.onEnded { value in
                resize = .zero
                update { $0.w = max(140, $0.w + value.translation.width); $0.h = max($0.kind == .link ? 150 : 64, $0.h + value.translation.height) }
            })
            .opacity(selected ? 1 : 0)
    }
}

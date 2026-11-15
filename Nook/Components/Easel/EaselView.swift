// Licensed under GPL-3.0. See LICENSE.
//
//  EaselView.swift
//  Nook
//
//  FORK: one easel: a big scrolling canvas of cards you drag and resize. Drop images, links or text on it,
//  paste, or use Add. A page card opens its page in a new tab.
//

import SwiftUI
import UniformTypeIdentifiers
import NookDesign

struct EaselView: View {
    let easelID: UUID
    /// The page in front, to add as a card, and how to open a card's page.
    let currentPage: () -> (title: String, url: URL)?
    let openPage: (URL) -> Void
    @ObservedObject private var store = EaselStore.shared
    @State private var selection: UUID?
    private let canvasSize = CGSize(width: 4000, height: 3000)

    private var easel: Easel? { store.easel(easelID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 440)
        .onPasteCommand(of: [.image, .url, .plainText]) { providers in
            _ = handleDrop(providers, at: CGPoint(x: 200 + Double(easel?.items.count ?? 0) * 18, y: 160 + Double(easel?.items.count ?? 0) * 18))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TextField("Easel name", text: Binding(get: { easel?.name ?? "" }, set: { name in store.mutate(easelID) { $0.name = name } }))
                .textFieldStyle(.plain)
                .font(NookDesign.Font.heading)
            Spacer()
            Button { addNote() } label: { Label("Note", systemImage: "note.text") }
            Button { addCurrentPage() } label: { Label("This Page", systemImage: "link") }.disabled(currentPage() == nil)
            Button { chooseImage() } label: { Label("Image", systemImage: "photo") }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Adding

    /// Where the next card goes, stepped so a run of them does not stack exactly.
    private func nextSpot() -> CGPoint {
        let n = Double(easel?.items.count ?? 0)
        return CGPoint(x: 120 + n.truncatingRemainder(dividingBy: 8) * 28, y: 100 + n.truncatingRemainder(dividingBy: 8) * 28)
    }

    private func add(_ item: EaselItem) {
        store.mutate(easelID) { $0.items.append(item) }
        selection = item.id
    }

    private func addNote(text: String = "", at point: CGPoint? = nil) {
        let p = point ?? nextSpot()
        add(EaselItem(kind: .note, x: p.x, y: p.y, w: 220, h: 160, text: text))
    }

    private func addLink(title: String, url: URL, at point: CGPoint? = nil) {
        let p = point ?? nextSpot()
        add(EaselItem(kind: .link, x: p.x, y: p.y, w: 260, h: 84, text: title, url: url.absoluteString))
    }

    private func addCurrentPage() {
        if let page = currentPage() { addLink(title: page.title, url: page.url) }
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

/// A faint dot grid, so the canvas reads as a surface you can place things on.
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 32
            var path = Path()
            for x in stride(from: step, to: size.width, by: step) {
                for y in stride(from: step, to: size.height, by: step) { path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)) }
            }
            context.fill(path, with: .color(.primary.opacity(0.12)))
        }
    }
}

struct EaselCard: View {
    let item: EaselItem
    let selected: Bool
    let select: () -> Void
    let update: (@escaping (inout EaselItem) -> Void) -> Void
    let remove: () -> Void
    let open: (URL) -> Void
    @State private var drag: CGSize = .zero
    @State private var resize: CGSize = .zero

    private var width: Double { max(120, item.w + resize.width) }
    private var height: Double { max(64, item.h + resize.height) }

    var body: some View {
        content
            .frame(width: width, height: height)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: selected ? 2 : 0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(selected ? 0.25 : 0.12), radius: selected ? 10 : 4, y: 2)
            .overlay(alignment: .bottomTrailing) { resizeHandle }
            .offset(x: item.x + drag.width, y: item.y + drag.height)
            .gesture(DragGesture().onChanged { drag = $0.translation; select() }.onEnded { value in
                drag = .zero
                update { $0.x += value.translation.width; $0.y += value.translation.height }
            })
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
            TextEditor(text: Binding(get: { item.text }, set: { text in update { $0.text = text } }))
                .font(NookDesign.Font.bodyRegular)
                .scrollContentBackground(.hidden)
                .padding(10)
        case .link:
            Button {
                if let text = item.url, let url = URL(string: text) { open(url) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text.isEmpty ? (URL(string: item.url ?? "")?.host() ?? "Page") : item.text)
                        .font(NookDesign.Font.body).foregroundStyle(.primary).lineLimit(3)
                    Text(URL(string: item.url ?? "")?.host() ?? "").font(NookDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .image:
            if let file = item.file, let image = NSImage(contentsOf: EaselStore.shared.imageURL(file)) {
                Image(nsImage: image).resizable().scaledToFill()
            } else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
    }

    private var background: Color {
        switch item.kind {
        case .note: return Color.yellow.opacity(0.22)
        case .link: return Color(nsColor: .controlBackgroundColor)
        case .image: return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            .frame(width: 22, height: 22).contentShape(Rectangle())
            .gesture(DragGesture().onChanged { resize = $0.translation }.onEnded { value in
                resize = .zero
                update { $0.w = max(120, $0.w + value.translation.width); $0.h = max(64, $0.h + value.translation.height) }
            })
            .opacity(selected ? 1 : 0)
    }
}

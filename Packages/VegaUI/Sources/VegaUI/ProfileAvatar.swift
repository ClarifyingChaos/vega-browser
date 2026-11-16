// Licensed under GPL-3.0. See LICENSE.
//
//  ProfileAvatar.swift
//  VegaUI
//
//  FORK: a picture for each profile, as Chrome profiles have: a photo the person picks, or a pixel icon in Vega's
//  style. The pixel icons are glyphs from pixelarticons (MIT, Gerrit Halfmann) turned into 24x24 masks, drawn cell by
//  cell so they stay crisp at any size. The choice stays on this Mac (UserDefaults, and a small PNG for a photo).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

public struct ProfileAvatarPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    let hex: String
    /// 24 rows, each a 24-bit mask, most significant bit on the left.
    let rows: [UInt32]

    typealias Preset = ProfileAvatarPreset

    public static let all: [ProfileAvatarPreset] = [
        Preset(id: "human", name: "Person", hex: "#0A84FF", rows: [0x000000,0x000000,0x003C00,0x003C00,0x003C00,0x003C00,0x000000,0x1FFFF8,0x1FFFF8,0x006600,0x006600,0x006600,0x006600,0x006600,0x007E00,0x007E00,0x006600,0x006600,0x006600,0x006600,0x006600,0x006600,0x000000,0x000000]),
        Preset(id: "alien", name: "Alien", hex: "#30B158", rows: [0x000000,0x000000,0x03FFC0,0x03FFC0,0x0C0030,0x0C0030,0x30000C,0x30000C,0x33C3CC,0x33C3CC,0x33E7CC,0x33E7CC,0x30E70C,0x30000C,0x0C0030,0x0C1830,0x0318C0,0x0300C0,0x00C300,0x00C300,0x003C00,0x003C00,0x000000,0x000000]),
        Preset(id: "robot-face-happy", name: "Robot", hex: "#8E5CF6", rows: [0x000000,0x000000,0x000780,0x000780,0x001800,0x001800,0x0FE7F0,0x0FE7F0,0x30000C,0x30000C,0x30C30C,0x30C30C,0xF0000F,0xF0000F,0x31FF8C,0x31FF8C,0x307E0C,0x307E0C,0x30000C,0x30000C,0x0FFFF0,0x0FFFF0,0x000000,0x000000]),
        Preset(id: "dog", name: "Dog", hex: "#FF9F0A", rows: [0x000000,0x000000,0x07FFE0,0x07FFE0,0x198198,0x198198,0x660066,0x660066,0x666666,0x666666,0x78661E,0x78661E,0x180018,0x180018,0x181818,0x181818,0x07FFE0,0x07FFE0,0x00C300,0x00C300,0x003C00,0x003C00,0x000000,0x000000]),
        Preset(id: "crown", name: "Crown", hex: "#FFC233", rows: [0x000000,0x000000,0x000000,0x001818,0x001818,0x1E6678,0x1E6678,0x198198,0x198198,0x180018,0x180018,0x180018,0x180018,0x180018,0x180018,0x07FFE0,0x07FFE0,0x000000,0x000000,0x1FFFF8,0x1FFFF8,0x000000,0x000000,0x000000]),
        Preset(id: "heart", name: "Heart", hex: "#FF375F", rows: [0x000000,0x000000,0x0781E0,0x0781E0,0x186618,0x186618,0x601806,0x601806,0x600006,0x600006,0x600006,0x600006,0x180018,0x180018,0x060060,0x060060,0x018180,0x018180,0x006600,0x006600,0x001800,0x001800,0x000000,0x000000]),
        Preset(id: "moon", name: "Moon", hex: "#5E5CE6", rows: [0x000000,0x000000,0x03FC00,0x03FC00,0x0C3000,0x0C3000,0x30C000,0x30C000,0x30C000,0x30C000,0x30C00C,0x30C00C,0x30303C,0x30303C,0x300FCC,0x300FCC,0x0C000C,0x0C000C,0x030030,0x030030,0x00FFC0,0x00FFC0,0x000000,0x000000]),
        Preset(id: "coffee", name: "Coffee", hex: "#A2845E", rows: [0x000000,0x000000,0x000000,0x000000,0x0FFFF0,0x0FFFF0,0x0C00CC,0x0C00CC,0x0C00CC,0x0C00CC,0x0C00F0,0x0C00F0,0x0C00C0,0x0C00C0,0x03FF00,0x03FF00,0x000000,0x000000,0x3FFFF0,0x3FFFF0,0x000000,0x000000,0x000000,0x000000]),
        Preset(id: "gamepad", name: "Gamepad", hex: "#FF6B3D", rows: [0x000000,0x000000,0x000000,0x000000,0x0FFFF0,0x0FFFF0,0x30000C,0x30000C,0x30000C,0x30C30C,0x30C30C,0x33300C,0x33300C,0x30C0CC,0x30C0CC,0x30000C,0x30000C,0x30000C,0x0FFFF0,0x0FFFF0,0x000000,0x000000,0x000000,0x000000]),
        Preset(id: "music", name: "Music", hex: "#32ADE6", rows: [0x000000,0x000000,0x000000,0x000000,0x003FC0,0x003FC0,0x00C030,0x00C030,0x00C030,0x00C030,0x00C030,0x00C030,0x0FC3F0,0x0FC3F0,0x30CC30,0x30CC30,0x30CC30,0x30CC30,0x0F03C0,0x0F03C0,0x000000,0x000000,0x000000,0x000000]),
        Preset(id: "leaf", name: "Leaf", hex: "#34C759", rows: [0x000000,0x000000,0x000060,0x000060,0x000798,0x000798,0x01F818,0x01F818,0x060018,0x060018,0x180018,0x180018,0x181818,0x181818,0x07E018,0x07E018,0x180060,0x180060,0x678780,0x678780,0x607800,0x607800,0x000000,0x000000]),
        Preset(id: "cloud-sun", name: "Sunny", hex: "#64D2FF", rows: [0x001800,0x001800,0x30180C,0x30180C,0x0C0030,0x0C0030,0x00FC00,0x00FC00,0x030300,0x030300,0x0000C0,0x0000CF,0x00F00F,0x00F000,0x0F0C00,0x0F0C00,0x30C300,0x30C300,0x300300,0x300300,0x0FFC00,0x0FFC00,0x000000,0x000000]),
    ]

    var color: Color {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0x0A84FF
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Which picture each profile has, kept on this Mac.
@MainActor @Observable
public final class ProfileAvatarStore {
    public static let shared = ProfileAvatarStore()

    public enum Choice: Equatable {
        case none
        case preset(ProfileAvatarPreset)
        case photo(URL)
    }

    /// Bumped on every change so views redraw a photo that kept its file name.
    public private(set) var version = 0

    private static func key(_ id: UUID) -> String { "fork.profile.avatar.\(id.uuidString)" }

    private let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Vega").appendingPathComponent("ProfilePictures", isDirectory: true)
    }()

    private func photoURL(_ id: UUID) -> URL { folder.appendingPathComponent("\(id.uuidString).png") }

    public func choice(for id: UUID) -> Choice {
        _ = version
        guard let value = UserDefaults.standard.string(forKey: Self.key(id)) else { return .none }
        if value == "photo" {
            let url = photoURL(id)
            return FileManager.default.fileExists(atPath: url.path) ? .photo(url) : .none
        }
        return ProfileAvatarPreset.all.first { "px:\($0.id)" == value }.map(Choice.preset) ?? .none
    }

    public func setPreset(_ preset: ProfileAvatarPreset, for id: UUID) {
        try? FileManager.default.removeItem(at: photoURL(id))
        UserDefaults.standard.set("px:\(preset.id)", forKey: Self.key(id))
        version += 1
    }

    public func remove(for id: UUID) {
        try? FileManager.default.removeItem(at: photoURL(id))
        UserDefaults.standard.removeObject(forKey: Self.key(id))
        version += 1
    }

    #if canImport(AppKit)
    /// A photo from a file: refused over 25 MB, stored as a 256-pixel square PNG cropped from its centre.
    @discardableResult
    public func setPhoto(from file: URL, for id: UUID) -> Bool {
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0, size <= 25_000_000, let image = NSImage(contentsOf: file),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        let side = min(cg.width, cg.height)
        guard side > 0, let square = cg.cropping(to: CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)),
              let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.interpolationQuality = .high
        context.draw(square, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        guard let small = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: small).representation(using: .png, properties: [:]) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard (try? png.write(to: photoURL(id), options: .atomic)) != nil else { return false }
        UserDefaults.standard.set("photo", forKey: Self.key(id))
        version += 1
        return true
    }
    #endif
}

/// A profile's picture in a circle: the photo, the pixel icon, or the person icon when none is chosen.
public struct ProfileAvatarView: View {
    let id: UUID
    let size: CGFloat
    @State private var store = ProfileAvatarStore.shared

    public init(id: UUID, size: CGFloat) {
        self.id = id
        self.size = size
    }

    public var body: some View {
        switch store.choice(for: id) {
        case .preset(let preset):
            PixelGlyph(preset: preset).frame(width: size, height: size)
        case .photo(let url):
            #if canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
                    .id(store.version)
            } else { fallback }
            #else
            fallback
            #endif
        case .none:
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: size, height: size)
    }
}

/// A pixel icon on its colour, drawn one cell at a time so its edges stay hard.
struct PixelGlyph: View {
    let preset: ProfileAvatarPreset

    var body: some View {
        Canvas { context, canvas in
            context.fill(Path(ellipseIn: CGRect(origin: .zero, size: canvas)), with: .color(preset.color))
            // The 24-cell glyph sits in the middle 70% of the circle, snapped to whole points where it can be.
            let cell = canvas.width * 0.7 / 24
            let origin = CGPoint(x: (canvas.width - cell * 24) / 2, y: (canvas.height - cell * 24) / 2)
            var path = Path()
            for (row, mask) in preset.rows.enumerated() {
                for column in 0..<24 where mask & (1 << UInt32(23 - column)) != 0 {
                    path.addRect(CGRect(x: origin.x + CGFloat(column) * cell, y: origin.y + CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(path, with: .color(.white))
        }
        .accessibilityLabel(preset.name)
    }
}

#if canImport(AppKit)
/// Choose a picture: a pixel icon, or a photo from a file.
public struct ProfileAvatarPicker: View {
    let id: UUID
    @State private var store = ProfileAvatarStore.shared
    @State private var failed = false

    public init(id: UUID) { self.id = id }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 10), count: 6), spacing: 10) {
                ForEach(ProfileAvatarPreset.all) { preset in
                    Button { store.setPreset(preset, for: id) } label: {
                        PixelGlyph(preset: preset)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: store.choice(for: id) == .preset(preset) ? 2.5 : 0).padding(-3))
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }
            HStack {
                Button("Choose Photo\u{2026}") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image]
                    panel.message = "Choose a picture for this profile."
                    if panel.runModal() == .OK, let url = panel.url { failed = !store.setPhoto(from: url, for: id) }
                }
                Spacer()
                if store.choice(for: id) != .none {
                    Button("Remove") { store.remove(for: id) }
                }
            }
            if failed {
                Text("That file isn't a picture Vega can use, or it's over 25 MB.").font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
#endif

// Licensed under GPL-3.0. See LICENSE.
//
//  Spaces.swift
//  Vega
//
//  Spaces and profiles. A profile is the spaces sharing one login context (cookies, site data,
//  history), so its data is inspected and cleared here too.
//

import VegaTabsCore
import SwiftUI
#if os(macOS)
import AppKit
#endif
import VegaDesign
import VegaWeb

private extension ProfileSummary {
    var rowKey: String { "profile-\(id.uuidString)" }
}

public struct SpacesSettingsView: View {
    @Environment(TabsController.self) private var tabs
    @Environment(\.tabActions) private var actions

    /// Data size per profile, filled in as each store answers.
    @State private var stats: [UUID: String] = [:]
    @State private var addingProfile = false
    @State private var addProfileError: String?
    @State private var newProfileName = ""
    /// The profile whose details sheet is open.
    @State private var detailsFor: UUID?
    /// The space being renamed and the name typed so far.
    @State private var renamingSpace: (id: UUID, name: String)?
    @State private var showAccentPickerFor: UUID?
    @State private var showIconPickerFor: UUID?
    /// The space row under the pointer.
    @State private var hoveredSpace: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// A move that would leave its profile empty, waiting on confirmation.
    @State private var pendingMove: (space: UUID, to: UUID?, profile: String)?
    /// FORK: the daily backups, and the one waiting on "Restore?".
    @State private var backups: [TabStore.BackupSummary] = []
    @State private var restoring: TabStore.BackupSummary?
    @State private var restoreError: String?

    public init() {}

    private var spaces: [SpaceRecord] { tabs.orderedSpaces.filter { !$0.isAgent } }

    public var body: some View {
        Form {
            SettingsHero(symbol: "square.on.square", title: "Spaces", detail: "Each profile keeps its own logins, cookies and history. Spaces in a profile share them.")

            Section {
                // A profile's id is its first space's id; keyed alike, the two rows collided and this
                // section lost its card. Profile rows get their own keys.
                ForEach(tabs.profiles, id: \.rowKey) { profile in
                    profileRow(profile)
                }
                Button("Add Profile\u{2026}", vegaIcon: "plus") { newProfileName = ""; addingProfile = true }
            } header: {
                Text("Profiles")
            } footer: {
                Text("Give each person their own profile, with their own spaces, passwords and sign-ins.")
            }

            Section {
                // The Agent space keeps its look and borrows another space's data, so it has no row.
                // A grouped Form's rows can't be dragged, so the spaces sit in a List of their own inside the card: its
                // drag lifts the row under the pointer and slides the others apart, as in Dia and System Settings.
                List {
                    ForEach(spaces) { space in
                        row(space)
                            .listRowSeparator(.visible)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            // A soft highlight under the pointer, edge to edge of the card (its rounded corners trim
                            // the first and last row). It fades in at once and out a little slower, so passing over rows
                            // does not flicker.
                            .listRowBackground(
                                Color.primary.opacity(hoveredSpace == space.id ? 0.06 : 0)
                                    .animation(reduceMotion ? nil : .easeOut(duration: hoveredSpace == space.id ? 0.1 : 0.22), value: hoveredSpace)
                            )
                    }
                    .onMove(perform: reorder)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(spaces.count) * spaceRowHeight)
                .animation(rowSpring, value: spaces.map(\.id))
                // The list runs to the card's edges, so a row's highlight does too; each row pads its own content.
                .listRowInsets(EdgeInsets())
                Button("New Space…", vegaIcon: "plus", action: showCreateDialog)
            } header: {
                Text("Spaces")
            } footer: {
                Text("Drag a space to change its place in the sidebar. Use … to rename it, change its icon or color, or move it to another profile.")
            }

            Section {
                if backups.isEmpty {
                    Text("No backups yet. Vega saves one each day you use it.").foregroundStyle(.secondary)
                }
                ForEach(backups) { backup in
                    HStack {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text(Self.title(for: backup))
                            Text("\(backup.spaceNames.count) \(backup.spaceNames.count == 1 ? "space" : "spaces") · \(backup.tabCount) tabs · \(backup.spaceNames.prefix(4).joined(separator: ", "))\(backup.spaceNames.count > 4 ? "…" : "")")
                                .font(VegaDesign.Font.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("Restore…") { restoring = backup }
                    }
                }
            } header: {
                Text("Backups")
            } footer: {
                Text(restoreError ?? "Vega keeps a copy of your spaces, favorites, pinned tabs and folders from each of the last 7 days. Restoring one restarts Vega; what you have now is kept as a backup first.")
            }
        }
        .formStyle(.grouped)
        .task { backups = tabs.backupSummaries() }
        .vegaConfirm(restoring.map { "Restore your spaces and tabs from \(Self.title(for: $0))?" } ?? "",
                     message: "Vega quits and opens again with those spaces and tabs. With Sync on, your other Macs get them too. What you have now is saved as a backup, so you can go back.",
                     confirm: "Restore and Restart Vega", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }), destructive: false) {
            guard let backup = restoring else { return }
            do {
                try tabs.scheduleRestore(backup.id)
                Self.relaunch()
            } catch {
                restoreError = "Couldn't restore that backup: \(error.localizedDescription)"
            }
        }
        .task(id: tabs.profiles.map(\.id)) { await refreshStats() }
        // System Settings' pattern: the ⓘ button opens a sheet with the profile's details and actions.
        .sheet(isPresented: Binding(get: { detailsFor != nil }, set: { if !$0 { detailsFor = nil } })) {
            if let id = detailsFor, let profile = tabs.profiles.first(where: { $0.id == id }) {
                ProfileDetailsSheet(
                    profile: profile,
                    spaceNames: profile.spaceIDs.compactMap { tabs.space($0)?.name },
                    dataSize: stats[profile.id],
                    rename: { tabs.renameProfile(profile.id, to: $0) },
                    clearData: { Task { await clearData(profile) } },
                    others: tabs.profiles.filter { $0.id != profile.id },
                    delete: { target in
                        // Its spaces join `target`; moving the last one out deletes this profile's data.
                        for space in profile.spaceIDs { tabs.setProfile(space, to: target) }
                        detailsFor = nil
                    },
                    done: { detailsFor = nil }
                )
            }
        }
        .alert("Add Profile", isPresented: $addingProfile) {
            TextField("Name", text: $newProfileName)
            Button("Add") {
                let name = newProfileName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                // A profile is the spaces sharing one set of sign-ins, so a new one starts with its own first space,
                // and opens in its own window, as a new Chrome profile does.
                if let space = tabs.createSpace(name: name, icon: "", accentHex: tabs.orderedSpaces.last?.accentHex ?? "#0A84FF",
                                                after: tabs.orderedSpaces.last?.id, profileName: name),
                   let storeID = tabs.profiles.first(where: { $0.spaceIDs.contains(space) })?.id {
                    actions?.openWindow(forProfile: storeID)
                }
            }
            // A profile that lives in a Google account: this Mac makes the account's own, or a new one for it.
            Button("Sign in with Google\u{2026}") {
                let name = newProfileName.trimmingCharacters(in: .whitespaces)
                Task {
                    do {
                        let outcome = try await ProfileAdoption.addFromGoogle(tabs: tabs, name: name.isEmpty ? "New Profile" : name)
                        switch outcome {
                        case .brought(let id, _), .created(let id), .alreadyHere(let id): actions?.openWindow(forProfile: id)
                        }
                    } catch { addProfileError = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A new profile starts with one space of its own, signed out of every website. Or sign in with a Google account to bring the profile it holds from another Mac.")
        }
        .alert("Couldn\u{2019}t Add the Profile", isPresented: Binding(get: { addProfileError != nil }, set: { if !$0 { addProfileError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addProfileError ?? "")
        }
        .alert("Rename Space", isPresented: Binding(get: { renamingSpace != nil }, set: { if !$0 { renamingSpace = nil } })) {
            TextField("Name", text: Binding(get: { renamingSpace?.name ?? "" }, set: { renamingSpace?.name = $0 }))
            Button("Rename") {
                if let renamingSpace, !renamingSpace.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    tabs.updateSpace(renamingSpace.id, name: renamingSpace.name, icon: nil, accentHex: nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Delete the \u{201C}\(pendingMove?.profile ?? "")\u{201D} profile?",
            isPresented: Binding(get: { pendingMove != nil }, set: { if !$0 { pendingMove = nil } })
        ) {
            Button("Move and Delete Profile", role: .destructive) {
                if let move = pendingMove { tabs.setProfile(move.space, to: move.to) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No other space uses it. Its logins, cookies and history will be deleted.")
        }
    }

    /// A profile as System Settings draws an account: avatar, name, a quiet summary, and ⓘ.
    private func profileRow(_ profile: ProfileSummary) -> some View {
        let count = profile.spaceIDs.count
        return HStack(spacing: VegaDesign.Spacing.lg) {
            ProfileAvatarView(id: profile.id, size: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                Text(profile.name)
                    .font(VegaDesign.Font.body)
                Text("\(count) \(count == 1 ? "space" : "spaces")")
                    .font(VegaDesign.Font.secondary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                detailsFor = profile.id
            } label: {
                VegaSymbol("info.circle", size: 19)
                    .font(.system(size: 15))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Profile Details")
            .accessibilityLabel("Details for \(profile.name)")
        }
        .padding(.vertical, VegaDesign.Spacing.xs)
    }

    private func profilePicker(_ space: SpaceRecord) -> some View {
        let current = tabs.profiles.first { $0.spaceIDs.contains(space.id) }
        // A nil selection is "New Profile"; every space is always in some profile.
        return Picker("Profile", selection: Binding<UUID?>(
            get: { current?.id },
            set: { move(space.id, to: $0, from: current) }
        )) {
            ForEach(tabs.profiles) { profile in
                Text(profile.name).tag(UUID?.some(profile.id))
            }
            Divider()
            Text("New Profile").tag(UUID?.none)
        }
        .labelsHidden()
        .accessibilityLabel("Profile")
        .fixedSize()
    }

    private func move(_ spaceID: UUID, to storeID: UUID?, from current: ProfileSummary?) {
        guard storeID != current?.id else { return }
        if let current, current.spaceIDs == [spaceID] {
            pendingMove = (spaceID, storeID, current.name)
        } else {
            tabs.setProfile(spaceID, to: storeID)
        }
    }

    /// Puts the dragged space after the one now above it, so the sidebar and the space switcher follow.
    static func title(for backup: TabStore.BackupSummary) -> String {
        if backup.id.hasSuffix("-before-restore") { return "Before the restore on \(backup.id.prefix(10))" }
        if let date = backup.savedAt { return date.formatted(date: .abbreviated, time: .shortened) }
        return backup.id
    }

    /// Quits and opens this copy of Vega again once it has fully quit.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.3; done; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        var ids = spaces.map(\.id)
        let moved = source.map { ids[$0] }
        ids.move(fromOffsets: source, toOffset: destination)
        withAnimation(rowSpring) {
            for id in moved {
                guard let index = ids.firstIndex(of: id) else { continue }
                tabs.moveSpace(id, after: index > 0 ? ids[index - 1] : nil)
            }
        }
    }

    private let spaceRowHeight: CGFloat = 56

    /// Rows slide with a critically damped spring (no overshoot), and stay interruptible; Reduce Motion cuts it short.
    private var rowSpring: Animation? { reduceMotion ? nil : .spring(duration: 0.34, bounce: 0) }

    @ViewBuilder
    private func row(_ space: SpaceRecord) -> some View {
        let tabCount = tabs.tabCount(inSpace: space.id)
        let hovered = hoveredSpace == space.id
        HStack(spacing: VegaDesign.Spacing.md) {
            // One badge: the space's colour behind its icon (or its first letter). Click to change the icon.
            Button { showIconPickerFor = space.id } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(space.accentColor.opacity(0.22))
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(space.accentColor.opacity(0.55), lineWidth: 1)
                    if space.icon.isEmpty {
                        Text(String(space.name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(space.accentColor)
                    } else {
                        SpaceIcon(space.icon)
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(spring: rowSpring))
            .help("Change Icon or Emoji…")
            .accessibilityLabel("Space icon for \(space.name)")
            .popover(isPresented: Binding(
                get: { showIconPickerFor == space.id },
                set: { if !$0 { showIconPickerFor = nil } }
            )) {
                SpaceIconPicker(icon: Binding(
                    get: { tabs.space(space.id)?.icon ?? space.icon },
                    set: { tabs.updateSpace(space.id, name: nil, icon: $0, accentHex: nil) }
                ), onSelect: { showIconPickerFor = nil })
            }

            // FORK: the name as text, renamed from the menu. A live field took focus when the page
            // opened, with its text selected, and the next keys typed anywhere replaced the name.
            Text(space.name)
                .font(VegaDesign.Font.body)
                .lineLimit(1)
                .popover(isPresented: Binding(
                    get: { showAccentPickerFor == space.id },
                    set: { if !$0 { showAccentPickerFor = nil } }
                )) {
                    SpaceAccentPicker(selectedHex: Binding(
                        get: { space.accentHex },
                        set: { tabs.updateSpace(space.id, name: nil, icon: nil, accentHex: $0) }
                    ))
                    .padding(VegaDesign.Spacing.lg)
                }
            Spacer(minLength: VegaDesign.Spacing.md)
            // With one profile every row would say the same thing; the picker only matters once there are two.
            if tabs.profiles.count > 1 {
                profilePicker(space)
            }
            Text("\(tabCount) \(tabCount == 1 ? "tab" : "tabs")")
                .font(VegaDesign.Font.secondary)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Menu {
                Button("Rename…", vegaIcon: "pencil") {
                    renamingSpace = (space.id, space.name)
                }
                Button("Change Icon…", systemImage: "face.smiling") { showIconPickerFor = space.id }
                Button("Change Color…", systemImage: "paintpalette") { showAccentPickerFor = space.id }
                if let index = spaces.firstIndex(where: { $0.id == space.id }) {
                    Divider()
                    Button("Move Up", systemImage: "arrow.up") { reorder(from: [index], to: index - 1) }
                        .disabled(index == 0)
                    Button("Move Down", systemImage: "arrow.down") { reorder(from: [index], to: index + 2) }
                        .disabled(index == spaces.count - 1)
                }
                if spaces.count > 1 {
                    Divider()
                    Button("Delete Space…", vegaIcon: "trash", role: .destructive) {
                        showDeleteDialog(space)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hovered ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            // A quiet "…": no circle until the pointer is on the row, and no disclosure arrow.
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More for \(space.name)")
        }
        // Content 10 pt from the card's edge, the same as the rows above, so the badges line up with the profile's picture.
        .padding(.horizontal, 10)
        .frame(height: spaceRowHeight)
        .animation(reduceMotion ? nil : .easeOut(duration: hovered ? 0.1 : 0.22), value: hovered)
        .onHover { inside in
            if inside { hoveredSpace = space.id } else if hoveredSpace == space.id { hoveredSpace = nil }
        }
    }

    // MARK: - Data

    private func refreshStats() async {
        for summary in tabs.profiles {
            guard let space = summary.spaceIDs.first, let profile = tabs.profile(forSpace: space) else { continue }
            await profile.refreshDataStoreStats()
            stats[summary.id] = profile.estimatedDataSize
        }
    }

    private func clearData(_ summary: ProfileSummary) async {
        guard let space = summary.spaceIDs.first, let profile = tabs.profile(forSpace: space) else { return }
        await profile.clearAllData()
        stats[summary.id] = profile.estimatedDataSize
    }

    // MARK: - Dialogs

    private func showCreateDialog() {
        actions?.presentSpaceCreation { name, accentHex in
            tabs.createSpace(
                name: name.isEmpty ? "New Space" : name,
                icon: "",
                accentHex: accentHex,
                after: tabs.orderedSpaces.last?.id,
                sharingLoginsWith: tabs.windowRegistry.activeWindow?.spaceID ?? tabs.regularWindows.first?.spaceID
            )
        }
    }

    private func showDeleteDialog(_ space: SpaceRecord) {
        actions?.confirmSpaceDeletion(
            spaceName: space.name,
            tabCount: tabs.tabCount(inSpace: space.id),
            isLastSpace: spaces.count <= 1,
            onDelete: { tabs.deleteSpace(space.id) }
        )
    }
}

/// The ⓘ sheet for a profile, laid out like an account sheet in System Settings: an editable name,
/// what uses it, how much it stores, and the destructive action last, behind a confirmation.
private struct ProfileDetailsSheet: View {
    let profile: ProfileSummary
    let spaceNames: [String]
    let dataSize: String?
    let rename: (String) -> Void
    let clearData: () -> Void
    /// The profiles its spaces can move to when it is deleted.
    let others: [ProfileSummary]
    let delete: (UUID) -> Void
    let done: () -> Void

    @State private var name = ""
    @State private var confirmingClear = false
    @State private var confirmingDelete = false
    @State private var choosingPicture = false
    @State private var moveTo: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar beside the name and a quiet summary, no card.
            HStack(spacing: VegaDesign.Spacing.lg) {
                // The picture is the button that changes it, as in Chrome and System Settings.
                Button { choosingPicture = true } label: {
                    ProfileAvatarView(id: profile.id, size: 48)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(.plain)
                .help("Change Picture")
                .accessibilityLabel("Change picture for \(profile.name)")
                #if os(macOS)
                .popover(isPresented: $choosingPicture, arrowEdge: .bottom) { ProfileAvatarPicker(id: profile.id) }
                #endif
                VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                    Text(name.isEmpty ? profile.name : name)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Profile")
                        .font(VegaDesign.Font.secondary)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, VegaDesign.Spacing.xxl)
            .padding(.top, VegaDesign.Spacing.xxl)

            Form {
                Section {
                    TextField("Name", text: $name)
                    LabeledContent("Used by") {
                        Text("\(spaceNames.count) \(spaceNames.count == 1 ? "space" : "spaces")")
                            .help(spaceNames.joined(separator: ", "))
                    }
                    // The amount under its label, and the button alone at the trailing edge.
                    HStack(spacing: VegaDesign.Spacing.lg) {
                        VStack(alignment: .leading, spacing: VegaDesign.Spacing.xxs) {
                            Text("Website data")
                            Text(dataSize ?? "Checking…")
                                .font(VegaDesign.Font.secondary)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: VegaDesign.Spacing.lg)
                        Button("Clear…") { confirmingClear = true }
                    }
                    .padding(.vertical, VegaDesign.Spacing.xxs)
                }
            }
            .formStyle(.grouped)
            // The sheet's own background behind the group, not a second, darker band.
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: 190)

            HStack {
                if !others.isEmpty {
                    Button("Delete Profile\u{2026}", role: .destructive) { moveTo = others.first?.id; confirmingDelete = true }
                }
                Spacer()
                Button("Done") { commit(); done() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, VegaDesign.Spacing.xxl)
            .padding(.bottom, VegaDesign.Spacing.xl)
        }
        .frame(width: 460)
        .onAppear {
            name = profile.name
            #if os(macOS)
            // A sheet focuses its first field with the text selected; leave it unfocused until clicked.
            // After the sheet has finished presenting; at once is too early and AppKit refocuses it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                for window in NSApp.windows where window.isSheet { window.makeFirstResponder(nil) }
            }
            #endif
        }
        .sheet(isPresented: $confirmingDelete) {
            VStack(alignment: .leading, spacing: VegaDesign.Spacing.lg) {
                Text("Delete \u{201C}\(profile.name)\u{201D}?").font(.headline)
                Text("Its \(spaceNames.count == 1 ? "space moves" : "\(spaceNames.count) spaces move") to the profile you pick, with their tabs. Its sign-ins, cookies and history are deleted. You can't undo this.")
                    .font(VegaDesign.Font.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Move spaces to", selection: $moveTo) {
                    ForEach(others) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { confirmingDelete = false }
                    Button("Delete Profile", role: .destructive) {
                        if let moveTo { confirmingDelete = false; delete(moveTo) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(VegaDesign.Spacing.xl)
            .frame(width: 400)
        }
        .vegaConfirm("Clear website data for \u{201C}\(profile.name)\u{201D}?", message: "Every space in this profile is signed out of all websites. You can't undo this.",
                     confirm: "Clear Website Data", isPresented: $confirmingClear, action: clearData)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != profile.name { rename(trimmed) }
    }
}


/// A press shrinks the control a little at once and lets go with a spring: feedback on touch-down, not on release.
private struct PressScaleStyle: ButtonStyle {
    let spring: Animation?
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(spring, value: configuration.isPressed)
    }
}

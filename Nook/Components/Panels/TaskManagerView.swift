// Licensed under GPL-3.0. See LICENSE.
//
//  TaskManagerView.swift
//  Nook
//
//  FORK: what each tab costs in memory, and a way to put tabs to sleep. A sleeping tab keeps its place, address and
//  back history; its page reloads when you open it.
//

import Darwin
import SwiftUI
import NookDesign
import NookWeb
import NookSettings

struct TaskManagerView: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @State private var rows: [Row] = []
    @State private var appFootprint: UInt64 = 0
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    struct Row: Identifiable {
        let id: UUID
        let title: String
        let host: String
        let pid: Int32
        let memory: UInt64?
        let sharesProcess: Bool
        let asleep: Bool
        let onScreen: Bool
        let audible: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: NookDesign.Spacing.xxs) {
                    Text("\(rows.filter { !$0.asleep }.count) awake · \(rows.filter(\.asleep).count) asleep").font(NookDesign.Font.label)
                    Text("Pages \(Self.format(totalPages)) · Vega itself \(Self.format(appFootprint))")
                        .font(NookDesign.Font.secondary).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sleep Background Tabs") { sleepBackground() }
                    .disabled(!rows.contains { !$0.asleep && !$0.onScreen && !$0.audible })
            }
            .padding(NookDesign.Spacing.xl)
            Table(rows) {
                TableColumn("Tab") { row in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.title.isEmpty ? row.host : row.title).lineLimit(1)
                        Text(row.host).font(NookDesign.Font.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                TableColumn("Memory") { row in
                    Text(row.asleep ? "Asleep" : row.memory.map { Self.format($0) + (row.sharesProcess ? " (shared)" : "") } ?? "–")
                        .monospacedDigit()
                        .foregroundStyle(row.asleep ? .secondary : .primary)
                }
                .width(min: 90, ideal: 110)
                TableColumn("") { row in
                    HStack {
                        if row.onScreen { Text("In view").font(NookDesign.Font.caption).foregroundStyle(.secondary) }
                        else if row.audible { Text("Playing").font(NookDesign.Font.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Sleep") { sleep(row.id) }
                            .disabled(row.asleep || row.onScreen)
                            .controlSize(.small)
                    }
                }
                .width(min: 120, ideal: 140)
            }
            HStack {
                Picker("Put tabs to sleep", selection: Binding(
                    get: { browserManager.nookSettings?.tabManagementMode ?? .standard },
                    set: { browserManager.nookSettings?.tabManagementMode = $0 })) {
                    ForEach(TabManagementMode.allCases) { Text($0.displayName).tag($0) }
                }
                .fixedSize()
                Spacer()
                Text("A sleeping tab reloads when you open it.").font(NookDesign.Font.caption).foregroundStyle(.secondary)
            }
            .padding(NookDesign.Spacing.lg)
        }
        .frame(minWidth: 520, minHeight: 360)
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private var totalPages: UInt64 {
        var seen = Set<Int32>()
        return rows.reduce(0) { sum, row in
            guard !row.asleep, row.pid > 0, let m = row.memory, seen.insert(row.pid).inserted else { return sum }
            return sum + m
        }
    }

    private func refresh() {
        let tabs = browserManager.tabs
        let sessions = tabs.sessions
        let pids = sessions.map(\.webProcessID)
        var perPID: [Int32: Int] = [:]
        for pid in pids where pid > 0 { perPID[pid, default: 0] += 1 }
        var memory: [Int32: UInt64] = [:]
        for pid in perPID.keys { memory[pid] = Self.footprint(pid) }
        rows = sessions.map { s in
            let pid = s.webProcessID
            return Row(id: s.itemID, title: s.title, host: s.url.host() ?? s.url.absoluteString, pid: pid,
                       memory: pid > 0 ? memory[pid] : nil, sharesProcess: (perPID[pid] ?? 0) > 1,
                       asleep: s.isUnloaded, onScreen: tabs.isOnScreen(s.itemID), audible: s.hasPlayingAudio || s.hasPiPActive)
        }
        .sorted { ($0.asleep ? 0 : ($0.memory ?? 0)) > ($1.asleep ? 0 : ($1.memory ?? 0)) }
        appFootprint = Self.footprint(getpid()) ?? 0
    }

    private func sleep(_ id: UUID) {
        guard !browserManager.tabs.isOnScreen(id) else { return }
        browserManager.tabs.session(for: id)?.unload()
        refresh()
    }

    private func sleepBackground() {
        for row in rows where !row.asleep && !row.onScreen && !row.audible { browserManager.tabs.session(for: row.id)?.unload() }
        refresh()
    }

    /// Physical footprint, as Activity Monitor's Memory column shows it.
    static func footprint(_ pid: Int32) -> UInt64? {
        var info = rusage_info_v4()
        let ok = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        return ok == 0 ? info.ri_phys_footprint : nil
    }

    static func format(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

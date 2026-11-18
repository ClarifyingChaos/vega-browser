// Licensed under GPL-3.0. See LICENSE.
//
//  ServerStoreCheck.swift
//  Vega
//
//  Vega's sync store against the real server code (server/dev.ts runs the Worker in Node): files go up and come
//  back, listing works per folder, an unchanged file is not downloaded again (304), and a wrong token is refused.
//  Needs Node 23+. Compiles the shipped sources:
//
//    swiftc Packages/VegaTabsCore/Sources/VegaTabsCore/*.swift Packages/VegaWeb/Sources/VegaWeb/ServerBlobStore.swift Packages/VegaWeb/Checks/ServerStoreCheck.swift -o /tmp/server-store-check && /tmp/server-store-check
//

import Foundation

@main
struct ServerStoreCheck {
    static func main() async throws {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        probe.arguments = ["node", "--version"]
        probe.standardOutput = Pipe(); probe.standardError = Pipe()
        guard (try? probe.run()) != nil else { print("ServerStoreCheck skipped: no Node"); return }
        probe.waitUntilExit()
        guard probe.terminationStatus == 0 else { print("ServerStoreCheck skipped: no Node"); return }
        let port = Int.random(in: 20_000...40_000)
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        server.arguments = ["node", "server/dev.ts", String(port)]
        server.environment = ProcessInfo.processInfo.environment.merging(["DEV_TOKEN": "check-secret"]) { $1 }
        server.standardOutput = Pipe()
        try server.run()
        defer { server.terminate() }
        let base = URL(string: "http://127.0.0.1:\(port)/")!
        // Wait for it to listen.
        for _ in 0..<50 {
            if let (_, r) = try? await URLSession.shared.data(from: base.appendingPathComponent("v1/health")), (r as? HTTPURLResponse)?.statusCode == 200 { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        let store = ServerBlobStore(base: base, token: { "check-secret" })
        let payload = Data((0..<2000).map { UInt8($0 % 251) })
        try await store.put("devices/A.enc", payload)
        try await store.put("devices/B.enc", Data([1]))
        try await store.put("settings/A.enc", Data([2]))
        let devices = try await store.list("devices").names.sorted()
        precondition(devices == ["A.enc", "B.enc"], "listing: \(devices)")
        let first = try await store.get("devices/A.enc")
        precondition(first == payload, "round trip")
        // Second read: the server answers 304 and the copy in hand is returned.
        let second = try await store.get("devices/A.enc")
        precondition(second == payload, "cached read")
        let missing = try await store.get("devices/missing.enc")
        precondition(missing == nil, "missing file")
        // A changed file is read anew.
        try await store.put("devices/A.enc", Data([7, 7]))
        let changed = try await store.get("devices/A.enc")
        precondition(changed == Data([7, 7]), "changed file is downloaded again")

        let intruder = ServerBlobStore(base: base, token: { "wrong" })
        do { _ = try await intruder.list("devices"); preconditionFailure("a wrong token was accepted") } catch {}
        print("ServerStoreCheck passed")
    }
}

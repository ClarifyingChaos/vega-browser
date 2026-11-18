// Licensed under GPL-3.0. See LICENSE.
//
//  FolderWatcher.swift
//  VegaWeb
//
//  FORK: tells sync when a file in the sync folder changes, so a change another Mac made reaches iCloud Drive's
//  folder here and is picked up within seconds, not at the next timed check. macOS only (FSEvents); elsewhere the
//  timed check does the work.
//

import Foundation
#if os(macOS)
import CoreServices

final class FolderWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let onChange: @Sendable () -> Void

    /// Calls `onChange` (off the main thread) a moment after files under `url` change. Nil when the folder can't be watched.
    init?(url: URL, latency: TimeInterval = 1.5, onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        // The folder is created on first write; a stream on a path that doesn't exist yet would never fire.
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(nil, callback, &context, [url.path] as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags) else { return nil }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        guard FSEventStreamStart(stream) else { FSEventStreamInvalidate(stream); FSEventStreamRelease(stream); return nil }
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
#else
final class FolderWatcher: @unchecked Sendable {
    init?(url: URL, latency: TimeInterval = 1.5, onChange: @escaping @Sendable () -> Void) { return nil }
    func stop() {}
}
#endif

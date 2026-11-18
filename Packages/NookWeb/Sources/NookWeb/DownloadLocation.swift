// Licensed under GPL-3.0. See LICENSE.
//
//  DownloadLocation.swift
//  NookWeb
//
//  FORK: where downloads go (Settings › General › Downloads): a folder the person picks, the Downloads folder until
//  then, or a Save panel for each file.
//

import Foundation

public enum DownloadLocation {
    public static let folderKey = "settings.downloadFolder"
    public static let askKey = "settings.askWhereToSave"

    /// The chosen folder while it still exists, else the Downloads folder.
    public static var folder: URL {
        if let path = UserDefaults.standard.string(forKey: folderKey), !path.isEmpty {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    /// Whether every download asks where to save it.
    public static var asksEachTime: Bool { UserDefaults.standard.bool(forKey: askKey) }
}

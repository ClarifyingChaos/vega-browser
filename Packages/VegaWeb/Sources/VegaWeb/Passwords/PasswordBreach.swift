// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordBreach.swift
//  VegaWeb
//
//  FORK: "has this password leaked?" by the k-anonymity method of Have I Been Pwned: only the first 5
//  characters of the password's SHA-1 leave this Mac, never the password or its full hash, and the answer
//  comes back as a list of the matching tails, padded so its size says nothing.
//

import CryptoKit
import Foundation

public enum PasswordBreach {
    /// The 5-character prefix that is sent, and the tail that is looked up in the answer.
    public static func split(_ password: String) -> (prefix: String, suffix: String) {
        let hex = Insecure.SHA1.hash(data: Data(password.utf8)).map { String(format: "%02X", $0) }.joined()
        return (String(hex.prefix(5)), String(hex.dropFirst(5)))
    }

    /// How many times the tail appears in a range answer ("TAIL:COUNT" per line). Padding lines count 0.
    public static func count(of suffix: String, in body: String) -> Int {
        for line in body.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":")
            if parts.count == 2, parts[0].uppercased() == suffix.uppercased() { return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0 }
        }
        return 0
    }

    /// nil when the service could not be reached.
    public static func timesSeen(_ password: String) async -> Int? {
        let (prefix, suffix) = split(password)
        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("true", forHTTPHeaderField: "Add-Padding")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return count(of: suffix, in: String(decoding: data, as: UTF8.self))
    }
}

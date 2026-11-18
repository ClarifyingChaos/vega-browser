// Licensed under GPL-3.0. See LICENSE.
//
//  TOTP.swift
//  VegaWeb
//
//  FORK: verification codes (RFC 6238), as an authenticator app makes them, from the setup key a site shows or an
//  otpauth:// link. The secret stays in this Mac's Keychain.
//

import CryptoKit
import Foundation

public struct TOTP: Equatable, Sendable {
    public enum Algorithm: String, Sendable { case sha1 = "SHA1", sha256 = "SHA256", sha512 = "SHA512" }

    public let secret: Data
    public var digits = 6
    public var period: TimeInterval = 30
    public var algorithm: Algorithm = .sha1

    public init(secret: Data, digits: Int = 6, period: TimeInterval = 30, algorithm: Algorithm = .sha1) {
        self.secret = secret
        self.digits = digits
        self.period = period
        self.algorithm = algorithm
    }

    /// A setup key ("JBSW Y3DP EHPK 3PXP", any case, spaces and dashes allowed) or an otpauth://totp/… link.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("otpauth://") {
            guard let parts = URLComponents(string: trimmed), parts.host?.lowercased() == "totp",
                  let items = parts.queryItems,
                  let secret = items.first(where: { $0.name.lowercased() == "secret" })?.value.flatMap(Self.base32) else { return nil }
            self.secret = secret
            if let d = items.first(where: { $0.name.lowercased() == "digits" })?.value.flatMap(Int.init), (6...8).contains(d) { digits = d }
            if let p = items.first(where: { $0.name.lowercased() == "period" })?.value.flatMap(Double.init), p >= 10, p <= 300 { period = p }
            if let a = items.first(where: { $0.name.lowercased() == "algorithm" })?.value.flatMap({ Algorithm(rawValue: $0.uppercased()) }) { algorithm = a }
        } else {
            guard let secret = Self.base32(trimmed) else { return nil }
            self.secret = secret
        }
        guard secret.count >= 10 else { return nil }
    }

    /// The code for `date`.
    public func code(at date: Date = Date()) -> String {
        var counter = UInt64(date.timeIntervalSince1970 / period).bigEndian
        let message = Data(bytes: &counter, count: 8)
        let key = SymmetricKey(data: secret)
        let mac: [UInt8]
        switch algorithm {
        case .sha1: mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: mac = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: mac = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(mac[mac.count - 1] & 0x0f)
        let value = (UInt32(mac[offset] & 0x7f) << 24) | (UInt32(mac[offset + 1]) << 16) | (UInt32(mac[offset + 2]) << 8) | UInt32(mac[offset + 3])
        let modulo = UInt32(pow(10, Double(digits)))
        let number = String(value % modulo)
        return String(repeating: "0", count: max(0, digits - number.count)) + number
    }

    /// Seconds until the code changes.
    public func secondsLeft(at date: Date = Date()) -> Int {
        Int(period - date.timeIntervalSince1970.truncatingRemainder(dividingBy: period))
    }

    /// The form stored in the Keychain.
    public var stored: String {
        var parts = URLComponents()
        parts.scheme = "otpauth"
        parts.host = "totp"
        parts.path = "/Vega"
        parts.queryItems = [.init(name: "secret", value: Self.base32Encode(secret)), .init(name: "digits", value: String(digits)),
                            .init(name: "period", value: String(Int(period))), .init(name: "algorithm", value: algorithm.rawValue)]
        return parts.string ?? ""
    }

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    static func base32(_ text: String) -> Data? {
        let cleaned = text.uppercased().filter { !" -=\t\n".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        var bits = 0, value = 0
        var out = Data()
        for ch in cleaned {
            guard let index = alphabet.firstIndex(of: ch) else { return nil }
            value = (value << 5) | index
            bits += 5
            if bits >= 8 {
                out.append(UInt8((value >> (bits - 8)) & 0xff))
                bits -= 8
            }
        }
        return out
    }

    static func base32Encode(_ data: Data) -> String {
        var out = "", bits = 0, value = 0
        for byte in data {
            value = (value << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[(value >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { out.append(alphabet[(value << (5 - bits)) & 31]) }
        return out
    }
}

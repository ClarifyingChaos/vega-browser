// Licensed under GPL-3.0. See LICENSE.
//
//  TOTPCheck.swift
//  Vega
//
//  Verification codes match RFC 6238's test vectors, setup keys and otpauth:// links parse, and a stored code
//  reads back the same. Compiles the shipped source:
//
//    swiftc Packages/VegaWeb/Sources/VegaWeb/Passwords/TOTP.swift Packages/VegaWeb/Checks/TOTPCheck.swift -o /tmp/totp-check && /tmp/totp-check
//

import Foundation

@main
struct TOTPCheck {
    static func main() {
        // RFC 6238 appendix B, 8 digits; the SHA-1 seed is "12345678901234567890".
        let sha1 = TOTP(secret: Data("12345678901234567890".utf8), digits: 8)
        let sha256 = TOTP(secret: Data("12345678901234567890123456789012".utf8), digits: 8, algorithm: .sha256)
        let sha512 = TOTP(secret: Data("1234567890123456789012345678901234567890123456789012345678901234".utf8), digits: 8, algorithm: .sha512)
        let vectors: [(TimeInterval, String, String, String)] = [
            (59, "94287082", "46119246", "90693936"),
            (1111111109, "07081804", "68084774", "25091201"),
            (1234567890, "89005924", "91819424", "93441116"),
            (20000000000, "65353130", "77737706", "47863826"),
        ]
        for (t, a, b, c) in vectors {
            let date = Date(timeIntervalSince1970: t)
            precondition(sha1.code(at: date) == a, "SHA1 at \(t): \(sha1.code(at: date))")
            precondition(sha256.code(at: date) == b, "SHA256 at \(t): \(sha256.code(at: date))")
            precondition(sha512.code(at: date) == c, "SHA512 at \(t): \(sha512.code(at: date))")
        }

        // A setup key as sites show it, and the same as a link.
        let key = TOTP("gezd gnbv gy3t qojq gezd gnbv gy3t qojq")
        precondition(key?.secret == Data("12345678901234567890".utf8), "setup key with spaces and lower case")
        let link = TOTP("otpauth://totp/Site:amy@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Site&digits=8&period=30&algorithm=SHA1")
        precondition(link?.digits == 8 && link?.code(at: Date(timeIntervalSince1970: 59)) == "94287082", "otpauth link")
        precondition(TOTP("not a key!") == nil && TOTP("ABC") == nil, "junk and too-short keys are refused")
        precondition(TOTP("otpauth://hotp/x?secret=GEZDGNBVGY3TQOJQ") == nil, "counter-based codes are not supported")

        // What is stored reads back as the same generator.
        let stored = TOTP(sha256.stored)
        precondition(stored == sha256, "stored form round-trips")
        precondition(sha1.secondsLeft(at: Date(timeIntervalSince1970: 59)) == 1, "seconds left")
        print("TOTPCheck passed")
    }
}

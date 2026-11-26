// Licensed under GPL-3.0. See LICENSE.
//
//  CRXVerifier.swift
//  Nook
//
//  FORK: checks a store package's signature before it is installed. A CRX3 names its extension by the hash of the
//  developer's public key, so a package signed by that key over these bytes is that developer's package, whatever
//  server or proxy delivered it.
//

import CryptoKit
import Foundation
import Security

enum CRXVerifier {
    /// The zip inside `crx`, only when the developer key that `extensionID` is derived from signed it.
    static func verifiedZip(_ crx: Data, extensionID: String) -> Data? {
        let bytes = [UInt8](crx)
        guard bytes.count > 12, Array(bytes[0..<4]) == Array("Cr24".utf8), le32(bytes, 4) == 3 else { return nil }
        let headerSize = le32(bytes, 8)
        guard headerSize > 0, headerSize < bytes.count - 12,
              let header = fields(Array(bytes[12..<(12 + headerSize)])),
              let signedHeader = header.first(where: { $0.number == 10_000 })?.bytes,
              let crxID = fields(signedHeader)?.first(where: { $0.number == 1 })?.bytes,
              crxID.count == 16, name(of: crxID) == extensionID else { return nil }
        let zip = Data(bytes[(12 + headerSize)...])

        var signed = Data("CRX3 SignedData\u{0}".utf8)
        withUnsafeBytes(of: UInt32(signedHeader.count).littleEndian) { signed.append(contentsOf: $0) }
        signed.append(contentsOf: signedHeader)
        signed.append(zip)

        // Field 2 holds RSA proofs, field 3 ECDSA ones. Only the proof by the ID's own key counts.
        for field in header where field.number == 2 || field.number == 3 {
            guard let proof = fields(field.bytes),
                  let key = proof.first(where: { $0.number == 1 })?.bytes,
                  let signature = proof.first(where: { $0.number == 2 })?.bytes,
                  Array(SHA256.hash(data: Data(key)).prefix(16)) == crxID else { continue }
            let valid = field.number == 2
                ? verifyRSA(signed, signature: Data(signature), spki: Data(key))
                : verifyECDSA(signed, signature: Data(signature), spki: Data(key))
            if valid { return zip }
        }
        return nil
    }

    /// The store's spelling of an ID: each hex digit of the 16 bytes written a-p.
    static func name(of id: [UInt8]) -> String {
        String(id.flatMap { [$0 >> 4, $0 & 15] }.map { Character(UnicodeScalar(UInt8(ascii: "a") + $0)) })
    }

    private static func verifyRSA(_ message: Data, signature: Data, spki: Data) -> Bool {
        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary
        guard let key = SecKeyCreateWithData(spki as CFData, attributes, nil) else { return false }
        return SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, signature as CFData, nil)
    }

    private static func verifyECDSA(_ message: Data, signature: Data, spki: Data) -> Bool {
        guard let key = try? P256.Signing.PublicKey(derRepresentation: spki),
              let signature = try? P256.Signing.ECDSASignature(derRepresentation: signature) else { return false }
        return key.isValidSignature(signature, for: message)
    }

    private static func le32(_ bytes: [UInt8], _ at: Int) -> Int {
        (0..<4).reduce(0) { $0 | Int(bytes[at + $1]) << (8 * $1) }
    }

    /// The length-delimited fields of a protobuf message; nil for anything malformed.
    private static func fields(_ bytes: [UInt8]) -> [(number: Int, bytes: [UInt8])]? {
        var at = 0
        var found: [(number: Int, bytes: [UInt8])] = []
        func varint() -> Int? {
            var value = 0, shift = 0
            while at < bytes.count, shift < 35 {
                let byte = bytes[at]
                at += 1
                value |= Int(byte & 0x7F) << shift
                if byte < 0x80 { return value }
                shift += 7
            }
            return nil
        }
        while at < bytes.count {
            guard let tag = varint(), tag & 7 == 2, let length = varint(), length <= bytes.count - at else { return nil }
            found.append((tag >> 3, Array(bytes[at..<(at + length)])))
            at += length
        }
        return found
    }
}

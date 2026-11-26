// Store package signatures: a package passes only when the key its ID comes from signed these bytes.
// swiftc -parse-as-library Nook/Utils/CRXVerifier.swift scripts/tests/CRXVerifierCheck.swift -o /tmp/crxcheck && /tmp/crxcheck
// With real packages: /tmp/crxcheck <file.crx> <extension id> ...

import CryptoKit
import Foundation
import Security

@main
struct CRXVerifierCheck {
    static func field(_ number: Int, _ bytes: [UInt8]) -> [UInt8] {
        func varint(_ value: Int) -> [UInt8] { value < 128 ? [UInt8(value)] : [UInt8(value & 0x7F | 0x80)] + varint(value >> 7) }
        return varint(number << 3 | 2) + varint(bytes.count) + bytes
    }

    static func le32(_ value: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) } }

    static func package(proofField: Int, spki: Data, zip: Data, sign: (Data) -> Data) -> (crx: Data, id: String) {
        let crxID = Array(SHA256.hash(data: spki).prefix(16))
        let signedHeader = field(1, crxID)
        let message = Data("CRX3 SignedData\u{0}".utf8) + Data(le32(signedHeader.count) + signedHeader) + zip
        let header = field(proofField, field(1, [UInt8](spki)) + field(2, [UInt8](sign(message)))) + field(10_000, signedHeader)
        let crx = Data(Array("Cr24".utf8) + le32(3) + le32(header.count) + header) + zip
        return (crx, CRXVerifier.name(of: crxID))
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        for pair in stride(from: 0, to: arguments.count - 1, by: 2) {
            let data = try Data(contentsOf: URL(fileURLWithPath: arguments[pair]))
            precondition(CRXVerifier.verifiedZip(data, extensionID: arguments[pair + 1]) != nil, "rejected \(arguments[pair])")
            var broken = data
            broken[broken.count - 1] ^= 1
            precondition(CRXVerifier.verifiedZip(broken, extensionID: arguments[pair + 1]) == nil, "accepted altered \(arguments[pair])")
            print("verified \(arguments[pair])")
        }

        let zip = Data("PK pretend zip".utf8)

        let ec = P256.Signing.PrivateKey()
        let good = package(proofField: 3, spki: ec.publicKey.derRepresentation, zip: zip) {
            try! ec.signature(for: $0).derRepresentation
        }
        precondition(CRXVerifier.verifiedZip(good.crx, extensionID: good.id) == zip, "a signed package passes")
        precondition(CRXVerifier.verifiedZip(good.crx, extensionID: String(repeating: "a", count: 32)) == nil, "another ID is refused")
        precondition(CRXVerifier.verifiedZip(good.crx + Data([0]), extensionID: good.id) == nil, "altered contents are refused")
        precondition(CRXVerifier.verifiedZip(good.crx.prefix(40), extensionID: good.id) == nil, "a cut-off header is refused")
        precondition(CRXVerifier.verifiedZip(Data("PK".utf8), extensionID: good.id) == nil, "a bare zip is refused")
        let other = P256.Signing.PrivateKey()
        let forged = package(proofField: 3, spki: ec.publicKey.derRepresentation, zip: zip) {
            try! other.signature(for: $0).derRepresentation
        }
        precondition(CRXVerifier.verifiedZip(forged.crx, extensionID: forged.id) == nil, "a signature by another key is refused")

        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary
        let rsa = SecKeyCreateRandomKey(attributes, nil)!
        let pkcs1 = SecKeyCopyExternalRepresentation(SecKeyCopyPublicKey(rsa)!, nil)! as Data
        // The fixed wrapper that turns a 2048-bit PKCS#1 key into the SubjectPublicKeyInfo a CRX carries.
        let wrapper: [UInt8] = [0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
                                0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00]
        let signedRSA = package(proofField: 2, spki: Data(wrapper) + pkcs1, zip: zip) {
            SecKeyCreateSignature(rsa, .rsaSignatureMessagePKCS1v15SHA256, $0 as CFData, nil)! as Data
        }
        precondition(CRXVerifier.verifiedZip(signedRSA.crx, extensionID: signedRSA.id) == zip, "an RSA-signed package passes")
        print("CRXVerifierCheck passed")
    }
}

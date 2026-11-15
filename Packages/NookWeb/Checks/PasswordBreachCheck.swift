// Licensed under GPL-3.0. See LICENSE.
//
//  PasswordBreachCheck.swift
//  Nook
//
//  Only a 5-character hash prefix is ever sent, and a range answer is read right, padding included.
//
//    swiftc Packages/NookWeb/Sources/NookWeb/Passwords/PasswordBreach.swift \
//           Packages/NookWeb/Checks/PasswordBreachCheck.swift -o /tmp/password-breach-check && /tmp/password-breach-check

import Foundation

@main
struct PasswordBreachCheck {
    static func main() {
        // The well-known example: SHA-1("password") = 5BAA61E4C9B93F3F0682250B6CF8331B7EE68FD8
        let (prefix, suffix) = PasswordBreach.split("password")
        precondition(prefix == "5BAA6" && suffix == "1E4C9B93F3F0682250B6CF8331B7EE68FD8", "prefix and tail split the hash")
        precondition(prefix.count == 5 && !suffix.hasPrefix(prefix), "only five characters are sent")
        let body = "0018A45C4D1DEF81644B54AB7F969B88D65:0\r\n1E4C9B93F3F0682250B6CF8331B7EE68FD8:10434004\r\n011053FD0102E94D6AE2F8B83D76FAF94F6:1\r\n"
        precondition(PasswordBreach.count(of: suffix, in: body) == 10_434_004, "a leaked tail is counted")
        precondition(PasswordBreach.count(of: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", in: body) == 0, "a missing tail is zero")
        precondition(PasswordBreach.count(of: "0018A45C4D1DEF81644B54AB7F969B88D65", in: body) == 0, "padding lines count zero")
        print("PasswordBreachCheck ok")
    }
}

// Licensed under GPL-3.0. See LICENSE.
//
//  AIAddressCheck.swift
//  Vega
//
//  An API key goes only to an https:// address or to this Mac, and a saved provider from before the
//  "send page content" switch reads back with it on. Compiles the shipped source:
//
//    swiftc Packages/VegaSettings/Sources/VegaSettings/AIModels.swift Packages/VegaSettings/Sources/VegaSettings/MCPServerConfig.swift \
//           Packages/VegaSettings/Checks/AIAddressCheck.swift -o /tmp/ai-address-check && /tmp/ai-address-check

import Foundation

@main
struct AIAddressCheck {
    static func main() throws {
        precondition(AIAddress.isSafe("https://api.example.com/v1"), "https is fine")
        precondition(AIAddress.isSafe("http://localhost:20128/v1") && AIAddress.isSafe("http://127.0.0.1:1234") && AIAddress.isSafe("http://[::1]:8080/v1"), "this Mac is fine")
        precondition(!AIAddress.isSafe("http://192.168.1.20:1234/v1"), "another machine over http is not")
        precondition(!AIAddress.isSafe("http://localhost.evil.com/v1"), "a lookalike host is not this Mac")
        precondition(!AIAddress.isSafe("ftp://example.com") && !AIAddress.isSafe("not a url") && !AIAddress.isSafe(""), "other schemes and junk are not")

        let old = #"{"id":"x","displayName":"Old","providerType":"openai_compatible","baseURL":"https://a.b","isEnabled":true,"customHeaders":{}}"#
        let provider = try JSONDecoder().decode(AIProviderConfig.self, from: Data(old.utf8))
        precondition(provider.sendsPageContent, "a provider saved before the switch sends the page, as it always did")
        print("AIAddressCheck ok")
    }
}

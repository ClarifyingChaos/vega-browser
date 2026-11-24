// Licensed under GPL-3.0. See LICENSE.
//
//  PublicSuffix.swift
//  VegaWeb
//
//  FORK: which part of a host name is the site, by the Public Suffix List (Resources/public_suffix_list.dat, MPL-2.0,
//  from publicsuffix.org), as Safari, Chrome and Firefox decide it. A short hand-made list treated alice.github.io and
//  mallory.github.io as one site, so a password saved on one was offered on the other.
//

import Foundation

public struct PublicSuffixList: Sendable {
    private let rules: Set<String>
    private let wildcards: Set<String>     // "*.ck" kept as "ck"
    private let exceptions: Set<String>    // "!www.ck" kept as "www.ck"
    /// False when the list could not be read: every host is then its own site, so nothing is shared by mistake.
    public let isLoaded: Bool

    public init(text: String) {
        var rules = Set<String>(), wildcards = Set<String>(), exceptions = Set<String>()
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            guard !line.isEmpty, !line.hasPrefix("//") else { continue }
            let rule = line.lowercased()
            if rule.hasPrefix("!") { exceptions.insert(String(rule.dropFirst())) }
            else if rule.hasPrefix("*.") { wildcards.insert(String(rule.dropFirst(2))) }
            else { rules.insert(rule) }
        }
        self.rules = rules
        self.wildcards = wildcards
        self.exceptions = exceptions
        isLoaded = !rules.isEmpty
    }

    /// The site a host belongs to: its public suffix and one label more (example.co.uk for a.b.example.co.uk). A host
    /// that is itself a public suffix, an IP address or a single label is its own site.
    public func registrable(_ host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard isLoaded, labels.count > 1, !host.allSatisfy({ $0.isNumber || $0 == "." || $0 == ":" }) else { return host }
        // The longest matching rule wins; an exception rule beats it and gives back one label.
        var suffixLength = 1
        for i in 0..<labels.count {
            let candidate = labels[i...].joined(separator: ".")
            if exceptions.contains(candidate) { suffixLength = labels.count - i - 1; break }
            if rules.contains(candidate) { suffixLength = max(suffixLength, labels.count - i) }
            if i > 0, wildcards.contains(candidate) { suffixLength = max(suffixLength, labels.count - i + 1) }
        }
        guard suffixLength < labels.count else { return host }
        return labels.suffix(suffixLength + 1).joined(separator: ".")
    }

    /// Read once, from Vega's resource bundle, else (a check built from the sources) from the file beside them.
    public static let shared: PublicSuffixList = {
        let name = "public_suffix_list"
        var candidates: [URL] = []
        if let bundle = Bundle.main.url(forResource: "VegaWeb_VegaWeb", withExtension: "bundle").flatMap(Bundle.init(url:)) {
            candidates += [bundle.url(forResource: name, withExtension: "dat", subdirectory: "Resources"),
                           bundle.url(forResource: name, withExtension: "dat")].compactMap { $0 }
        }
        candidates.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/\(name).dat"))
        let text = candidates.lazy.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.first
        return PublicSuffixList(text: text ?? "")
    }()
}

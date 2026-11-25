// Licensed under GPL-3.0. See LICENSE.
// swiftc Packages/NookSettings/Sources/NookSettings/KeepSignedIn.swift Packages/NookSettings/Checks/KeepSignedInCheck.swift -o /tmp/ksi && /tmp/ksi

@main
struct KeepSignedInCheck {
    static func main() {
        precondition(KeepSignedIn.normalize(" https://www.GitHub.com/login ") == "github.com")
        precondition(KeepSignedIn.normalize("mail.google.com") == "mail.google.com")
        precondition(KeepSignedIn.normalize("notion.so:443") == "notion.so")
        precondition(KeepSignedIn.normalize("hello") == nil && KeepSignedIn.normalize("") == nil)
        let sites = ["mail.google.com", "github.com"]
        precondition(KeepSignedIn.keeps("google.com", sites: sites), "the sign-in for mail.google.com lives at google.com")
        precondition(KeepSignedIn.keeps("github.com", sites: sites))
        precondition(!KeepSignedIn.keeps("notgithub.com", sites: sites), "a look-alike domain is not kept")
        precondition(!KeepSignedIn.keeps("example.com", sites: sites))
        precondition(!KeepSignedIn.keeps("google.com", sites: []))
        print("KeepSignedInCheck passed")
    }
}

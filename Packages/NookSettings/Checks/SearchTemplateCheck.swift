// Licensed under GPL-3.0. See LICENSE.
//
//  swiftc Packages/NookSettings/Sources/NookSettings/SiteSearch.swift Packages/NookSettings/Checks/SearchTemplateCheck.swift -o /tmp/search-template && /tmp/search-template
//
//  A custom search engine is saved only with an https address, a placeholder and a fixed host.

import Foundation

@main
struct SearchTemplateCheck {
    static func main() {
        func result(_ s: String) -> Result<String, CustomSearchEngine.TemplateError> { CustomSearchEngine.template(from: s) }
        precondition(result(" https://a.test/?q=%s ") == .success("https://a.test/?q=%@"))
        precondition(result("https://a.test/search/%@") == .success("https://a.test/search/%@"))
        precondition(result("http://a.test/?q=%s") == .failure(.notHTTPS))
        precondition(result("a.test/?q=%s") == .failure(.notHTTPS))
        precondition(result("javascript:alert(%s)") == .failure(.notHTTPS))
        precondition(result("https://a.test/search") == .failure(.noPlaceholder))
        for bad in ["https://%s.test/", "https:///?q=%s", "https://user@a.test/?q=%s", "https://a.test/?q=%s two"] {
            precondition(result(bad) == .failure(.invalid), bad)
        }
        for engine in CustomSearchEngine.popular {
            if case .failure = result(engine.template) { preconditionFailure(engine.name) }
        }
        print("SearchTemplateCheck passed")
    }
}

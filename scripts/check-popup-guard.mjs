// Licensed under GPL-3.0. See LICENSE.
// Runs the pop-up guard exactly as BrowserConfig.swift ships it: node scripts/check-popup-guard.mjs
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const swift = readFileSync(new URL("../Packages/NookWeb/Sources/NookWeb/BrowserConfig.swift", import.meta.url), "utf8");
const start = swift.indexOf("// Nook popup guard");
const source = swift.slice(start, swift.indexOf('"""', start)).replaceAll("\\\\", "\\");

/** A page at `from` that was just clicked, on a link to `link` or on something that is not a link. */
function page(from, link, reports = [], clicked = true) {
    const clicks = [];
    const handler = { postMessage: (body) => { if (body) reports.push(body.blocked); return Promise.resolve(false); } };
    const window = { open: () => "opened", webkit: { messageHandlers: { vegaPopupPolicy: handler } } };
    const context = {
        window, location: new URL(from), URL, Date, innerWidth: 1000, innerHeight: 800,
        addEventListener: (_, listener) => clicks.push(listener), document: { addEventListener() {} },
        HTMLAnchorElement: Object.assign(function () {}, { prototype: { click() {}, dispatchEvent() {} } }),
    };
    vm.runInNewContext(source, context);
    const anchor = link ? { href: link, getBoundingClientRect: () => ({ width: 1, height: 1 }) } : null;
    if (clicked) clicks[0]({ isTrusted: true, target: { closest: () => anchor } });
    return (to) => window.open(to) === "opened";
}

const drive = page("https://drive.google.com/drive/my-drive");
for (const url of [
    "https://drive.usercontent.google.com/download?id=1",
    "https://docs.google.com/uc?export=download",
    "https://doc-0s-1s-docs.googleusercontent.com/docs/x",
]) {
    assert(drive(url), `Drive may open ${url}`);
    assert(page("https://docs.google.com/document/d/1")(url), `Docs may open ${url}`);
    assert(!page("https://example.com/")(url), `another site may not open ${url} from a plain click`);
}
for (const url of [
    "https://ads.example.net/x",
    "http://drive.usercontent.google.com/download",
    "https://googleusercontent.com.evil.test/",
    "https://evilgoogleusercontent.com/",
    "https://drive.google.com.evil.test/",
    "https://sites.google.com/view/x",
]) {
    assert(!drive(url), `Drive may not open ${url}`);
}
assert(!page("https://sites.google.com/view/x")("https://drive.usercontent.google.com/download"), "only Drive and Docs");
assert(page("https://example.com/", "https://other.test/")("https://other.test/"), "the clicked link still opens");
assert(!page("https://example.com/")("https://ads.example.net/"), "a plain click still opens no other site");
// A refusal after a click is reported with the full address; an allowed window and one nobody clicked for are not.
const told = [];
page("https://example.com/", null, told)("//files.example.net/a?b=1");
assert.deepEqual(told, ["https://files.example.net/a?b=1"]);
page("https://example.com/", null, told)("https://example.com/same");
page("https://example.com/", null, told, false)("https://ads.example.net/");
assert.equal(told.length, 1, "nothing else is reported");
console.log("popup guard: all checks passed");

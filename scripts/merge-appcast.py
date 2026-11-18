#!/usr/bin/env python3
"""Merges a new appcast item into the published feed, keeping the other channel's newest item.

    scripts/merge-appcast.py published.xml new.xml out.xml
    scripts/merge-appcast.py --self-test

A beta item (with <sparkle:channel>beta</sparkle:channel>) keeps the newest regular item, so regular users still
see it. A regular item keeps the newest beta only when that beta is newer, so beta users never go back.
"""
import re, sys

ITEM = re.compile(r"<item>.*?</item>", re.S)

def items(xml):
    return ITEM.findall(xml)

def build(item):
    m = re.search(r"<sparkle:version>(\d+)</sparkle:version>", item)
    return int(m.group(1)) if m else 0

def is_beta(item):
    return "<sparkle:channel>beta</sparkle:channel>" in item

def merge(published, new):
    new_items = items(new)
    assert len(new_items) == 1, "the new feed has exactly one item"
    fresh = new_items[0]
    old = items(published)
    if is_beta(fresh):
        keep = [i for i in old if not is_beta(i)]
    else:
        keep = [i for i in old if is_beta(i) and build(i) > build(fresh)]
    keep = sorted(keep, key=build, reverse=True)[:1]
    merged = sorted([fresh] + keep, key=build, reverse=True)
    return ITEM.sub("@@ITEMS@@", new, count=1).replace("@@ITEMS@@", "\n    ".join(merged))

def item(build_no, beta=False):
    channel = "\n      <sparkle:channel>beta</sparkle:channel>" if beta else ""
    return f"<item>\n      <sparkle:version>{build_no}</sparkle:version>{channel}\n    </item>"

def feed(*its):
    return "<rss><channel>\n    " + "\n    ".join(its) + "\n  </channel></rss>"

def self_test():
    stable = feed(item(139))
    # A beta keeps the regular release beside it.
    m = merge(stable, feed(item(140, beta=True)))
    assert build(items(m)[0]) == 140 and is_beta(items(m)[0]) and build(items(m)[1]) == 139 and len(items(m)) == 2, m
    # The next regular release drops the older beta.
    m2 = merge(m, feed(item(141)))
    assert len(items(m2)) == 1 and build(items(m2)[0]) == 141, m2
    # A regular release older than a newer beta keeps the beta.
    m3 = merge(feed(item(142, beta=True), item(139)), feed(item(141)))
    assert [build(i) for i in items(m3)] == [142, 141], m3
    # A first feed (nothing published) is just the new item.
    assert len(items(merge("", feed(item(1))))) == 1
    print("merge-appcast self-test passed")

if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        published, new, out = sys.argv[1:4]
        try:
            old = open(published).read()
        except FileNotFoundError:
            old = ""
        open(out, "w").write(merge(old, open(new).read()))

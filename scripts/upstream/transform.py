#!/usr/bin/env python3
"""Rewrites a clone of the upstream project into Vega's names, deterministically.

    python3 scripts/upstream/transform.py <clone-dir>

Every commit in the clone is rewritten with the same rules: the project's old name becomes Vega in file and folder
names and in text, commit messages lose lines naming an AI tool, and files that only record such a tool are dropped.
Because each rewritten commit depends only on the commit it came from, running this on an older and a newer copy of the
upstream history gives the same hashes for the shared commits. That is what lets `develop` fast-forward every day and
lets its commits merge into `main` with ordinary three-way merges.

Needs git-filter-repo (pin the version in CI: the hashes depend on it). Rewrites <clone-dir> in place.

Left alone on purpose: links to the upstream project, its legal files (LICENSE, CHANGELOG.md, TRADEMARK.md), the
migration from its old app ids, third-party data (filter lists, the Public Suffix List, uBlock Origin's scriptlet
sources), the gh-pages feed and pages, and binary files' contents (their names are still renamed).
"""
import subprocess
import sys
from pathlib import Path

CALLBACK_SETUP = r'''
import re
OLD = re.compile(r"NOOK|Nook|nook")
SWAP = {"NOOK": "VEGA", "Nook": "Vega", "nook": "vega"}
KEEP_EXACT = {"LICENSE", "CHANGELOG.md", "TRADEMARK.md", "App/LegacyDataMigration.swift", "appcast.xml", "index.html", "privacy.html", "site.css"}
KEEP_PREFIX = (
    "Packages/NookBlocker/ThirdParty/",
    "Packages/NookBlocker/Sources/NookBlocker/Resources/easylist.txt",
    "Packages/NookBlocker/Sources/NookBlocker/Resources/easyprivacy.txt",
    "Packages/NookBlocker/Sources/NookBlocker/Resources/ublock-",
    "Packages/NookBlocker/Sources/NookBlocker/Resources/urlhaus-filter.txt",
    "Packages/NookBlocker/Sources/NookBlocker/Resources/adguard-url-tracking.txt",
    "Packages/NookWeb/Sources/NookWeb/Resources/public_suffix_list.dat",
)
PROTECT = r"(github\.com/nook-browser[A-Za-z0-9_./-]*|nook-browser(?:/Nook)?(?:\.git)?|browsewithnook(?:\.com)?)"
TOKEN = re.compile(PROTECT + r"|(NOOK|Nook|nook)")
TOOL_PHRASES = [
    (re.compile(r"(?i)claude code"), "the coding assistant"),
    (re.compile(r"CLAUDE\.(?:codebase\.|sessions\.)?md"), "the maintainer notes"),
    (re.compile(r"claude mcp add"), "mcp add"),
]
IGNORE_LINES = {".claude", "Nook/.claude", "CLAUDE.md", "Nook/Managers/ExtensionManager/CLAUDE.md"}

def conv_text(path, text):
    if path == ".gitignore":
        text = "\n".join(l for l in text.split("\n") if l.strip() not in IGNORE_LINES)
    for pattern, replacement in TOOL_PHRASES:
        text = pattern.sub(replacement, text)
    return TOKEN.sub(lambda m: m.group(1) if m.group(1) else SWAP[m.group(2)], text)

def conv_path(path):
    return OLD.sub(lambda m: SWAP[m.group(0)], path)

def keep(path):
    return path in KEEP_EXACT or path.startswith(KEEP_PREFIX)
'''

FILE_INFO = CALLBACK_SETUP + r'''
name = filename.decode("utf-8", "surrogateescape")
new_name = conv_path(name)
if mode in (b"100644", b"100755") and not keep(name):
    contents = value.get_contents_by_identifier(blob_id)
    if b"\0" not in contents:
        try:
            text = contents.decode("utf-8")
        except UnicodeDecodeError:
            text = None
        if text is not None:
            new_text = conv_text(name, text)
            if new_text != text:
                blob_id = value.insert_file_with_contents(new_text.encode("utf-8"))
return (new_name.encode("utf-8", "surrogateescape"), mode, blob_id)
'''

MESSAGE = r'''
import re
text = message
text = re.sub(rb"CLAUDE\.(?:codebase|sessions)\.md", b"the maintainer notes", text)
text = text.replace(b"CLAUDE.md", b"the maintainer notes").replace(b"docs(claude):", b"docs:")
kept = []
for line in text.split(b"\n"):
    low = line.lower()
    if b"claude" in low or b"anthropic" in low:
        continue
    kept.append(line)
return b"\n".join(kept).rstrip(b"\n ") + b"\n"
'''

DROP_PATHS = ["CLAUDE.md", "CLAUDE.codebase.md", "CLAUDE.sessions.md",
              "Nook/Managers/ExtensionManager/CLAUDE.md", "docs/superpowers"]


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    clone = Path(sys.argv[1]).resolve()
    cmd = ["git", "-C", str(clone), "filter-repo", "--force", "--invert-paths"]
    for p in DROP_PATHS:
        cmd += ["--path", p]
    cmd += ["--file-info-callback", FILE_INFO, "--message-callback", MESSAGE]
    subprocess.check_call(cmd)


if __name__ == "__main__":
    main()

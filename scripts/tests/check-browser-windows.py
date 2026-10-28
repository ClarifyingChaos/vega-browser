#!/usr/bin/env python3
"""Run window lifecycle checks against a built Debug app, with isolated application data."""
import pathlib
import plistlib
import shutil
import subprocess
import sys
import tempfile
import uuid

root = pathlib.Path(__file__).resolve().parents[2]
derived = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root / "build-prototype").resolve()
products = derived / "Build/Products/Debug"
bundle_id = "com.vega.window-check." + uuid.uuid4().hex
support = pathlib.Path.home() / "Library/Application Support" / bundle_id

with tempfile.TemporaryDirectory(prefix="vega-window-check-") as temporary:
    folder = pathlib.Path(temporary)
    contents = folder / "WindowCheck.app/Contents"
    binaries = contents / "MacOS"
    binaries.mkdir(parents=True)
    (contents / "Resources").symlink_to(products / "Vega.app/Contents/Resources")
    (contents / "Frameworks").symlink_to(products / "Vega.app/Contents/Frameworks")
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump({"CFBundleIdentifier": bundle_id, "CFBundleExecutable": "WindowCheck",
                      "CFBundlePackageType": "APPL", "CFBundleName": "Vega Window Check"}, stream)
    library = binaries / "Vega.debug.dylib"
    shutil.copy2(products / "Vega.app/Contents/MacOS/Vega.debug.dylib", library)
    command = [
        "swiftc", "-parse-as-library", "-I", str(products), "-I", str(products / "include"),
        "-I", str(derived / "SourcePackages/checkouts/swift-atomics/Sources/_AtomicsShims/include"),
        "-Xcc", "-fmodule-map-file=" + str(derived / "Build/Intermediates.noindex/GeneratedModuleMaps/MuteableWKWebView.modulemap"),
        "-F", str(products), "-F", str(contents / "Frameworks"),
        str(root / "scripts/tests/BrowserWindowOpeningCheck.swift"), str(library),
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
        "-o", str(binaries / "WindowCheck"),
    ]
    try:
        subprocess.run(command, check=True)
        for executable in (library, binaries / "WindowCheck"):
            subprocess.run(["codesign", "--force", "--sign", "-", str(executable)], check=True)
        subprocess.run([str(binaries / "WindowCheck"), "-VegaStateDir", str(folder / "state")], check=True, timeout=60)
    finally:
        shutil.rmtree(support, ignore_errors=True)

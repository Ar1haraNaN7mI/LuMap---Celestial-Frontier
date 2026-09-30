#!/usr/bin/env python3
"""Stage and verify a local, ad-hoc-signed Mac build. This is not notarization."""

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


def run(*args):
    subprocess.run(args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("built_app", type=Path)
    parser.add_argument("destination", type=Path, help="Must not already exist")
    args = parser.parse_args()
    source = args.built_app.resolve()
    destination = args.destination.absolute()
    if destination.exists():
        parser.error("Destination already exists; choose a staging path first.")
    with (source / "Contents/Info.plist").open("rb") as handle:
        if plistlib.load(handle).get("CFBundleIdentifier") != "com.local.lumap":
            parser.error("Expected the Lumap macOS app bundle.")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lumap-package-", dir=destination.parent) as work:
        staged = Path(work) / "Lumap.app"
        shutil.copytree(source, staged, symlinks=True)
        framework = staged / "Contents/Frameworks/onnxruntime.framework"
        # Some sherpa-onnx binary distributions contain these redundant nested
        # aliases. Remove only the exact malformed links, never real contents.
        for relative, target in (("Versions/A/A", "A"),
                                 ("Versions/A/Resources/Resources", "Versions/Current/Resources")):
            link = framework / relative
            if link.is_symlink() and os.readlink(link) == target:
                link.unlink()
        for dependency in sorted((staged / "Contents/Frameworks").glob("*.framework")):
            run("codesign", "--force", "--sign", "-", "--timestamp=none", str(dependency))
        entitlements = Path(__file__).resolve().parents[1] / "Lumap/Lumap.entitlements"
        run("codesign", "--force", "--sign", "-", "--timestamp=none", "--options", "runtime",
            "--entitlements", str(entitlements), str(staged))
        run("codesign", "--verify", "--deep", "--strict", str(staged))
        staged.rename(destination)
    print(f"Verified local app: {destination}")


if __name__ == "__main__":
    main()

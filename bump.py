"""Rewrite Formula/samong.rb for the newest upstream release.

A formula that has to be edited by hand is a formula that sits on an old version;
`brew install` then quietly gives people something months out of date.

Reads the checksums from the `.sha256` files each release already publishes rather
than downloading and hashing the archives — those files are the release's own claim
about its contents, and the archives are 30-40 MB each.

Exits 0 with no changes when the formula is already current, so the scheduled run
is silent on the ordinary day.

Usage: bump.py [--version X.Y.Z] [--check]
"""

import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = "waanvar/samong"
FORMULA = Path(__file__).parent / "Formula" / "samong.rb"
TIMEOUT = 60

# (formula block, archive suffix)
TARGETS = [
    ("macos_arm", "aarch64-macos.tar.gz"),
    ("macos_intel", "x86_64-macos.tar.gz"),
    ("linux_intel", "x86_64-linux.tar.gz"),
]
SHA256 = re.compile(r"^[a-f0-9]{64}$")


def get(url: str) -> bytes:
    """Fetch a URL, authenticating API calls when a token is in the environment.

    Unauthenticated GitHub API requests are limited to **60 per hour per IP**, and
    a shared Actions runner burns that between jobs belonging to other people
    entirely. Every scheduled run of this workflow failed with
    `403: rate limit exceeded` for five runs straight — so the formula sat at the
    previous release and `brew install samong` quietly handed people an old
    version, which is precisely the failure this script exists to prevent. With
    `GITHUB_TOKEN` the limit is 5,000/hour and no secret has to be stored.

    The header goes only to `api.github.com`. The `.sha256` URLs redirect to
    `objects.githubusercontent.com`, which rejects an Authorization header it did
    not expect — so sending it everywhere would trade an intermittent 403 for a
    reliable 400.
    """
    headers = {"User-Agent": "homebrew-samong-bump"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:  # noqa: S310
        return response.read()


def latest_tag() -> str:
    data = json.loads(get(f"https://api.github.com/repos/{REPO}/releases/latest"))
    return data["tag_name"]


def checksum(tag: str, suffix: str) -> str:
    version = tag.lstrip("v")
    name = f"samong-v{version}-{suffix}"
    url = f"https://github.com/{REPO}/releases/download/{tag}/{name}.sha256"
    text = get(url).decode("utf-8").strip()
    digest = text.split()[0]
    if not SHA256.match(digest):
        raise SystemExit(f"{url} did not contain a sha256: {text!r}")
    return digest


def current_version() -> str:
    match = re.search(r'^  version "([^"]+)"', FORMULA.read_text(encoding="utf-8"), re.M)
    if not match:
        raise SystemExit("could not find the version line in the formula")
    return match.group(1)


def main() -> int:
    args = sys.argv[1:]
    check_only = "--check" in args
    tag = None
    if "--version" in args:
        tag = "v" + args[args.index("--version") + 1].lstrip("v")

    tag = tag or latest_tag()
    version = tag.lstrip("v")
    have = current_version()

    if version == have:
        print(f"formula is already at {version}")
        return 0
    print(f"{have} -> {version}")
    if check_only:
        return 1

    text = FORMULA.read_text(encoding="utf-8")
    text = re.sub(r'^  version "[^"]+"', f'  version "{version}"', text, count=1, flags=re.M)

    for _, suffix in TARGETS:
        digest = checksum(tag, suffix)
        name = f"samong-v{version}-{suffix}"
        url = f"https://github.com/{REPO}/releases/download/{tag}/{name}"
        # Anchor on the suffix so each of the three blocks is rewritten in place;
        # matching on "url" alone would rewrite the first block three times.
        pattern = re.compile(
            r'url "https://github\.com/' + re.escape(REPO) + r'/releases/download/[^"]*'
            + re.escape(suffix) + r'"\n(\s*)sha256 "[a-f0-9]{64}"'
        )
        replacement = f'url "{url}"\n\\g<1>sha256 "{digest}"'
        text, count = pattern.subn(replacement, text, count=1)
        if count != 1:
            raise SystemExit(f"could not find the block for {suffix} in the formula")

    FORMULA.write_text(text, encoding="utf-8")

    # Prove the rewrite left nothing stale before anything is committed.
    written = FORMULA.read_text(encoding="utf-8")
    if current_version() != version:
        raise SystemExit("the version line was not updated")
    stale = [line for line in written.splitlines() if "/download/v" in line and f"/v{version}/" not in line]
    if stale:
        raise SystemExit("a url still points at another version:\n" + "\n".join(stale))
    if len(set(re.findall(r'sha256 "([a-f0-9]{64})"', written))) != len(TARGETS):
        raise SystemExit("expected three distinct checksums")

    print(f"formula rewritten for {version}")
    # Only when there is a repository to diff against — this also runs from a
    # scratch directory during development.
    if (Path(__file__).parent / ".git").exists():
        subprocess.run(["git", "--no-pager", "diff", "--stat"], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())

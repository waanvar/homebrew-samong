# homebrew-samong

A Homebrew tap for [Samong](https://github.com/waanvar/samong) — a local-first,
Obsidian-compatible knowledge base. Notes are Markdown files in a folder you
already have, and nothing leaves your machine.

```sh
brew tap waanvar/samong
brew install samong
```

Installs four binaries: `samong` (CLI), `samong-server` (local web UI and API),
`samong-mcp` (MCP server for AI agents), and `samong-app` (double-click launcher).

## Why install this way

Samong's binaries are not code-signed, and a certificate costs money the project
does not have. Download the same archive in a browser and **macOS Gatekeeper
refuses to open it** — not a warning, a refusal.

Homebrew fetches with `curl`, which does not set the `com.apple.quarantine`
attribute that Gatekeeper acts on. So installing from here avoids the problem
entirely, at no cost and with nothing to click through.

That is not an assumption: the CI in this repo installs the formula on a real
macOS runner and fails if the installed binary carries the attribute.

## What is verified, and what is not

| Platform | Verified by CI |
|---|---|
| macOS arm64 (Apple Silicon) | yes — installed, tested, quarantine checked |
| Linux x86_64 | yes — installed and tested |
| macOS x86_64 (Intel) | **no** — GitHub has no hosted Intel Mac runner. The formula is published for it and the archive is the same one the upstream release builds and checksums, but nothing installs it before you do. |
| Linux arm64 | not published — upstream builds no `aarch64-linux` archive, so `brew` will say there is no formula for your platform rather than install something that cannot run |

The formula's `test do` block does more than check `--version`: it writes two
notes, searches for a word inside one of them, follows a `[[wikilink]]`, and
searches a Thai sentence — which only works if the word-segmentation dictionary
was packaged into the binary. That last one is the assertion that would fail if a
release were built wrong.

## How it stays current

`bump.py` reads the newest upstream release and rewrites the version, the three
URLs and the three checksums, taking the digests from the `.sha256` files each
release already publishes. `.github/workflows/bump.yml` runs it every six hours,
**installs and tests the result on the runner, and only then commits**.

Run it now instead of waiting: Actions → **Bump** → Run workflow. An explicit
version can be pinned there too.

There is deliberately no cross-repo `repository_dispatch` from the upstream
release: that would need a long-lived personal access token stored in two places,
and a formula lagging by a few hours is a much smaller problem than a leaked token.

## Reporting problems

Formula problems here. Anything about Samong itself —
[waanvar/samong](https://github.com/waanvar/samong/issues).

The tap is Apache-2.0, like the project. The name "Samong" and the logo are not
covered by that licence.

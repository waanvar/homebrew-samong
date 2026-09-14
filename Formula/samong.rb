# A binary formula: it downloads the release archive rather than building from
# source, so installing needs no Rust toolchain.
#
# Why this tap exists at all: Samong's binaries are not code-signed, so a browser
# download is refused outright by macOS Gatekeeper. Homebrew fetches with curl,
# which does not set the com.apple.quarantine attribute, so an install through
# here has nothing for Gatekeeper to object to. The CI in this repo asserts that
# — see .github/workflows/test.yml.
#
# Every platform Homebrew can simulate needs a url. `brew tap` runs a readall
# across all of them, and a block with no url fails it with "formula requires at
# least a URL" — reported as "invalid syntax in tap", after which brew deletes the
# clone. Leaving aarch64-linux out to make brew say "no available formula" made
# the tap untappable on every machine instead, including the Macs it installs on.
#
# Generated fields (version, url, sha256) are rewritten by .github/workflows/bump.yml
# from the .sha256 files each release publishes. Editing them by hand means the
# formula goes stale the next time upstream releases.
class Samong < Formula
  desc "Local-first, Obsidian-compatible knowledge base with Thai full-text search"
  homepage "https://samong.dev"
  version "0.6.0"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.6.0/samong-v0.6.0-aarch64-macos.tar.gz"
      sha256 "095d0ae10543e6ff6850dc460c935834c3de5747df185d2fedb60c9ab968d6d5"
    end
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.6.0/samong-v0.6.0-x86_64-macos.tar.gz"
      sha256 "f67e51955031220c3fd010592803deb7ba274957c5c36809e2c5ea63a30800a3"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.6.0/samong-v0.6.0-x86_64-linux.tar.gz"
      sha256 "a63b9af5f51ec6bce8aa6f39e677870158627a057c814795e7a0e84815c67ce9"
    end
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.6.0/samong-v0.6.0-aarch64-linux.tar.gz"
      sha256 "7bace87111721f8ab48340d8eb0d695c618b44e90846aed9687a71410d74b1f2"
    end
  end

  def install
    # Homebrew usually strips the archive's single top-level directory, but this
    # formula cannot be tested from the machine that writes it, so it does not
    # depend on that: it works whether the binaries are at the root or one level
    # down in samong-v<version>-<target>/.
    root = Dir["samong-v*"].find { |path| File.directory?(path) } || "."
    cd root do
      bin.install "samong", "samong-server", "samong-mcp", "samong-app"
    end
  end

  def caveats
    <<~EOS
      Notes live in a folder you choose; nothing leaves this machine.

      Point it at a folder and open the interface:
        samong vault add notes ~/Documents/Notes
        samong-server start

      Or run samong-app for the same thing with no arguments — it creates
      ~/Documents/Samong on first use and opens your browser.
    EOS
  end

  test do
    # Never the real registry at ~/.config/samong: a test that writes there would
    # fight redb's lock and could modify vaults the user actually relies on.
    ENV["SAMONG_CONFIG_DIR"] = testpath/"config"

    assert_match version.to_s, shell_output("#{bin}/samong --version")
    assert_match version.to_s, shell_output("#{bin}/samong-server --version")

    vault = testpath/"vault"
    vault.mkpath
    (vault/"Runbook.md").write "# Runbook\n\nwhen the queue backs up, drain it\n\nSee [[Escalation]].\n"
    (vault/"Escalation.md").write "# Escalation\n\nwake the on-call\n"

    cd vault do
      # Search, not just --version: the point of the program is finding a note by
      # a word inside it.
      assert_match "Runbook", shell_output("#{bin}/samong search queue")

      # The wikilink resolves, so the graph was built.
      assert_match "Escalation", shell_output("#{bin}/samong links Runbook")

      # Thai has no spaces between words, and the dictionary that segments it is
      # embedded in the binary. If the archive were packaged without it this is
      # the assertion that fails.
      (vault/"Thai.md").write "# Thai\n\nสถาบันวิจัยแห่งประเทศไทยประกาศผลการศึกษา\n"
      assert_match "Thai", shell_output("#{bin}/samong search ประเทศไทย")
    end
  end
end

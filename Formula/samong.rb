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
  version "0.6.1"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.6.1/samong-v0.6.1-aarch64-macos.tar.gz"
      sha256 "702093563c88fd510b1c85e31917ca994932652159333755dfdcb9c19f51d43d"
    end
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.6.1/samong-v0.6.1-x86_64-macos.tar.gz"
      sha256 "7749e3c07147748866102706ec907db7c32cf3a7302568f27d1ccaf80226336b"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.6.1/samong-v0.6.1-x86_64-linux.tar.gz"
      sha256 "60ba434d8ebcdd3d7bf244a32db1585725b46f991cd0fa63b7aeaabfbd20eca6"
    end
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.6.1/samong-v0.6.1-aarch64-linux.tar.gz"
      sha256 "e0adeb8cb3057a0c459a9e9d47b610a3d8b06f6767b0a2b8e33ffa99aa609e31"
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

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
  version "0.7.0"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.7.0/samong-v0.7.0-aarch64-macos.tar.gz"
      sha256 "cbcefdd4d68afcc4c5283558e2e9a0edddffaa45347e39129bd36f09e44a6119"
    end
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.7.0/samong-v0.7.0-x86_64-macos.tar.gz"
      sha256 "e6ce2ed0bc75dfc92d0d1938b1c8aef1e3fe207eb5697d6c4e72160c2ee830a1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.7.0/samong-v0.7.0-x86_64-linux.tar.gz"
      sha256 "c00135b7845dec15449e8bdbd5a6d3ece5446031623f16717b003acbbc7bfc72"
    end
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.7.0/samong-v0.7.0-aarch64-linux.tar.gz"
      sha256 "63a7f429feaa62499c70b4b0b21f0b0e560f4b018bba0c95edad24c9b8c65a09"
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

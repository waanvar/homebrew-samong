# A binary formula: it downloads the release archive rather than building from
# source, so installing needs no Rust toolchain.
#
# Why this tap exists at all: Samong's binaries are not code-signed, so a browser
# download is refused outright by macOS Gatekeeper. Homebrew fetches with curl,
# which does not set the com.apple.quarantine attribute, so an install through
# here has nothing for Gatekeeper to object to. The CI in this repo asserts that
# — see .github/workflows/test.yml.
#
# Generated fields (version, url, sha256) are rewritten by .github/workflows/bump.yml
# from the .sha256 files each release publishes. Editing them by hand means the
# formula goes stale the next time upstream releases.
class Samong < Formula
  desc "Local-first, Obsidian-compatible knowledge base with Thai full-text search"
  homepage "https://samong.dev"
  version "0.3.9"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/waanvar/samong/releases/download/v0.3.9/samong-v0.3.9-aarch64-macos.tar.gz"
      sha256 "50a4d225f867b3f8f1be255c77e28eda1bbdd86e8cd9bf5aa1057da17a12bfcb"
    end
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.3.9/samong-v0.3.9-x86_64-macos.tar.gz"
      sha256 "fc6b43a3087d7a7088c6b6888c681ffe73fd8b62f66107e474a2de6c50d209a9"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/waanvar/samong/releases/download/v0.3.9/samong-v0.3.9-x86_64-linux.tar.gz"
      sha256 "f943abce6ebeca885530729fb98dab48b52774bc5a065a8ada91d46aa3748d07"
    end
    # No aarch64-linux build is published upstream, so there is deliberately no
    # on_arm block: brew refusing with "no available formula" is clearer than
    # installing an x86_64 binary that cannot run.
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

class Reviewbar < Formula
  desc "CLI for AI-powered code reviews"
  homepage "https://github.com/zymawy/reviewBar"
  version "1.0.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/zymawy/reviewBar/releases/download/v#{version}/ReviewBarCLI-v#{version}-macos.tar.gz"
      sha256 :no_check # Update after first release
    end
    on_intel do
      url "https://github.com/zymawy/reviewBar/releases/download/v#{version}/ReviewBarCLI-v#{version}-macos.tar.gz"
      sha256 :no_check
    end
  end

  def install
    bin.install "reviewbar"
  end

  test do
    system "#{bin}/reviewbar", "--version"
  end
end

cask "reviewbar" do
  version "1.0.0"
  sha256 :no_check # Update this with actual SHA256 after first release

  url "https://github.com/zymawy/reviewBar/releases/download/v#{version}/ReviewBar.dmg"
  name "ReviewBar"
  desc "AI-powered code reviews in your menu bar"
  homepage "https://github.com/zymawy/reviewBar"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "ReviewBar.app"

  zap trash: [
    "~/Library/Application Support/ReviewBar",
    "~/Library/Caches/ReviewBar",
    "~/Library/Preferences/com.reviewbar.ReviewBar.plist",
  ]
end

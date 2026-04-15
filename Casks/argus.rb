cask "argus" do
  version "1.0"
  sha256 "14737786d820f8506976d65f7f0ff5383510e632a798e51ab6b47ca835e34f59"

  url "https://github.com/cnrture/Argus/releases/download/v#{version}/Argus.dmg"
  name "Argus"
  desc "Turn your MacBook notch into a real-time AI coding agent control panel"
  homepage "https://github.com/cnrture/Argus"

  depends_on macos: ">= :sequoia"

  app "Argus.app"

  zap trash: [
    "~/Library/Preferences/com.cnrture.Argus.plist",
    "~/Library/Application Support/Argus",
    "~/.argus",
  ]
end

cask "argus" do
  version "1.0"
  sha256 "36213891279dbf0b34338e712a676cfeae45b0bb61b08eff3b803dde5fa661ef"

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

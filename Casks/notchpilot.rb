cask "notchpilot" do
  version :latest
  sha256 :no_check

  url "https://github.com/cnrture/NotchPilot/releases/latest/download/NotchPilot.dmg"
  name "NotchPilot"
  desc "Turn your MacBook notch into a real-time AI coding agent control panel"
  homepage "https://github.com/cnrture/NotchPilot"

  depends_on macos: ">= :sequoia"

  app "NotchPilot.app"

  zap trash: [
    "~/Library/Preferences/com.cnrture.NotchPilot.plist",
    "~/.notchpilot",
  ]
end

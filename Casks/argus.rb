cask "argus" do
  version :latest
  sha256 :no_check

  url "https://github.com/cnrture/Argus/releases/latest/download/Argus.dmg"
  name "Argus"
  desc "Turn your MacBook notch into a real-time AI coding agent control panel"
  homepage "https://github.com/cnrture/Argus"

  depends_on macos: ">= :sequoia"

  app "Argus.app"

  zap trash: [
    "~/Library/Preferences/com.cnrture.Argus.plist",
    "~/.argus",
  ]
end

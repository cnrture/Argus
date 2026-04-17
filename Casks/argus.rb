cask "argus" do
  version "1.0"
  sha256 "e9508f0bd0c2e5cc05415ee854ae4beac015e138c3690dae293e8659879d8db9"

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

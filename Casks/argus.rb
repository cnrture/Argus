cask "argus" do
  version "1.0"
  sha256 "d2bec64145e493002e0d0105beb1ab077a355666e1e9654bb1da1f33b09c4724"

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

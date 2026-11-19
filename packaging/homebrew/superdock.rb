# Homebrew cask for SuperDock. scripts/release.sh fills in version and sha256; copy this file into the
# apurvamukherjee/homebrew-superdock tap repo (Casks/superdock.rb) after each release. See docs/releasing.md.
cask "superdock" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/apurvamukherjee/SuperDoc/releases/download/v#{version}/SuperDock-#{version}.dmg"
  name "SuperDock"
  desc "Free companion bar for the Dock with widgets, AI usage limits and a coding-agents board"
  homepage "https://github.com/apurvamukherjee/SuperDoc"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "SuperDock.app"

  # Quitting first lets SuperDock put the system Dock back if Dock replacement mode was on.
  uninstall quit: "dev.superdock.SuperDock"

  zap trash: [
    "~/Library/Application Support/SuperDock",
    "~/Library/Preferences/dev.superdock.SuperDock.plist",
  ]
end

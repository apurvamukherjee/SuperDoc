# Homebrew cask for SuperDock. scripts/release.sh fills in version and sha256; copy this file into the
# apurvamukherjee/homebrew-superdock tap repo (Casks/superdock.rb) after each release. See docs/releasing.md.
cask "superdock" do
  version "0.1.2"
  sha256 "e0b87feae31613bf62b1fd3070de9d2864c1309ea42a1ab59394bc3f6df53939"

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

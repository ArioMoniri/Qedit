cask "qedit" do
  version "0.4.1"
  sha256 "82b6c5e77289bf6cfe9694c0efcf424f1a47c4c10cd05056267281b715bf2c40"

  url "https://github.com/ArioMoniri/Qedit/releases/download/v#{version}/Qedit.dmg",
      verified: "github.com/ArioMoniri/Qedit/"
  name "Qedit"
  desc "Non-destructive find/edit for any file + Quick Look extension manager"
  homepage "https://github.com/ArioMoniri/Qedit"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Qedit.app"

  zap trash: [
    "~/Library/Preferences/com.ariomoniri.Qedit.plist",
    "~/Library/Caches/com.ariomoniri.Qedit",
    "~/Library/HTTPStorages/com.ariomoniri.Qedit",
    "~/Library/Containers/com.ariomoniri.Qedit.QuickLook",
    "~/Library/Containers/com.ariomoniri.Qedit.QuickAction",
  ]
end

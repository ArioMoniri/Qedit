cask "qedit" do
  version "0.2.0"
  sha256 "10267f2f219df1bc0371f927ea4a23e61b7822096981d82ef8a7dd35ab4df66d"

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

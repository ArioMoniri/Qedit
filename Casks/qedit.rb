cask "qedit" do
  version "0.3.0"
  sha256 "501d7b37840d8615be30c694cc5617073f45a70daaf21c419bd54bc9eb21a483"

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

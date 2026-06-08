cask "qedit" do
  version "0.7.3"
  sha256 "276a6ab003dee28bf81889704fd12cdef4e4484286f8bd567e05e61e43bd47c5"

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

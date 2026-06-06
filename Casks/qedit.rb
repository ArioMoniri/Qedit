cask "qedit" do
  version "0.5.1"
  sha256 "ca4b18201955732d830c9bcf6eba8637b0ab4af8aa54d2427f144ecd5d0af8f9"

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

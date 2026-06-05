import AppKit

/// A Spotlight/Quick-Look-style panel: borderless-looking, non-activating, but still able to
/// become KEY so the embedded editor receives typing and ⌘F. The whole `styleMask` (including
/// `.nonactivatingPanel`) is set ONCE in the designated initializer and never mutated — mutating
/// it afterwards leaves the window-server "prevents activation" tag wrong and typing silently dies.
final class QuickPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 580),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        minSize = NSSize(width: 480, height: 320)
    }

    // Required so the embedded NSTextView/PDFView can become first responder and take keys,
    // WITHOUT activating the owning app (Finder stays frontmost — no app-switch flash).
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc closes the panel — but only as the responder-chain fallback, so an open find bar
    /// (whose own field handles Esc first) closes before the panel does.
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

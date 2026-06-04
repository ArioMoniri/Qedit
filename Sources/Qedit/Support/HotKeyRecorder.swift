import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A small click-to-record field for capturing a global hotkey combination.
struct HotKeyRecorder: NSViewRepresentable {
    @Binding var config: HotKeyConfig

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.config = config
        view.onCapture = { config = $0 }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        if !nsView.isRecording { nsView.config = config }
    }

    final class RecorderView: NSView {
        var onCapture: ((HotKeyConfig) -> Void)?
        var config: HotKeyConfig = .default { didSet { needsDisplay = true } }
        private(set) var isRecording = false { didSet { needsDisplay = true } }

        override var acceptsFirstResponder: Bool { true }
        override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 24) }

        override func becomeFirstResponder() -> Bool { isRecording = true; return true }
        override func resignFirstResponder() -> Bool { isRecording = false; return true }
        override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

        override func keyDown(with event: NSEvent) {
            guard isRecording else { super.keyDown(with: event); return }
            if event.keyCode == UInt16(kVK_Escape) {
                window?.makeFirstResponder(nil); return
            }
            let mods = HotKeyConfig.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { NSSound.beep(); return } // require a modifier
            let cfg = HotKeyConfig(keyCode: UInt32(event.keyCode),
                                   carbonModifiers: mods,
                                   keyLabel: Self.label(for: event))
            config = cfg
            onCapture?(cfg)
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            let radius: CGFloat = 6
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                    xRadius: radius, yRadius: radius)
            (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                         : NSColor.controlBackgroundColor).setFill()
            path.fill()
            (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = isRecording ? "Type a shortcut…" : config.displayString
            let style = NSMutableParagraphStyle(); style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
                .paragraphStyle: style
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let rect = NSRect(x: 0, y: (bounds.height - size.height) / 2,
                              width: bounds.width, height: size.height)
            (text as NSString).draw(in: rect, withAttributes: attrs)
        }

        static func label(for event: NSEvent) -> String {
            switch Int(event.keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return, kVK_ANSI_KeypadEnter: return "↩"
            case kVK_Tab: return "⇥"
            case kVK_Delete: return "⌫"
            case kVK_ForwardDelete: return "⌦"
            case kVK_LeftArrow: return "←"
            case kVK_RightArrow: return "→"
            case kVK_UpArrow: return "↑"
            case kVK_DownArrow: return "↓"
            case kVK_F1: return "F1"; case kVK_F2: return "F2"; case kVK_F3: return "F3"
            case kVK_F4: return "F4"; case kVK_F5: return "F5"; case kVK_F6: return "F6"
            case kVK_F7: return "F7"; case kVK_F8: return "F8"; case kVK_F9: return "F9"
            case kVK_F10: return "F10"; case kVK_F11: return "F11"; case kVK_F12: return "F12"
            default:
                if let chars = event.charactersIgnoringModifiers, !chars.isEmpty,
                   chars.rangeOfCharacter(from: .alphanumerics) != nil || chars.count == 1 {
                    return chars.uppercased()
                }
                return "Key \(event.keyCode)"
            }
        }
    }
}

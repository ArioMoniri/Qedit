import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey via Carbon's RegisterEventHotKey (dependency-free).
/// Firing on the main run loop, it opens the current Finder selection in the editor.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x51454454 // 'QEDT'

    /// Install the event handler once, then (re)register the current hotkey.
    func start() {
        guard handlerRef == nil else { reregister(); return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.fire() }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handlerRef)
        reregister()
    }

    func reregister() {
        unregisterHotKey()
        let store = HotKeyStore.shared
        guard store.enabled, store.config.hasModifier else { return }
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(store.config.keyCode,
                            store.config.carbonModifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func fire() {
        EditorLauncher.shared.openFinderSelection()
    }
}

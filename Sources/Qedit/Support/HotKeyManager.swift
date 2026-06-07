import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey via Carbon's RegisterEventHotKey (dependency-free).
/// Firing on the main run loop, it opens the current Finder selection in the editor.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var selectionRef: EventHotKeyRef?   // id 1: open the Finder selection
    private var browserRef: EventHotKeyRef?      // id 2: open the Browser
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x51454454 // 'QEDT'

    /// Install the event handler once, then (re)register the current hotkeys.
    func start() {
        guard handlerRef == nil else { reregister(); return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, _ in
            var hkID = EventHotKeyID()
            if let event {
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            }
            let id = hkID.id
            DispatchQueue.main.async { HotKeyManager.shared.fire(id: id) }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handlerRef)
        reregister()
    }

    func reregister() {
        unregister(&selectionRef)
        unregister(&browserRef)
        let store = HotKeyStore.shared
        if store.enabled, store.config.hasModifier {
            register(store.config, id: 1, into: &selectionRef)
        }
        if store.browserEnabled, store.browserConfig.hasModifier {
            register(store.browserConfig, id: 2, into: &browserRef)
        }
    }

    private func register(_ config: HotKeyConfig, id: UInt32, into ref: inout EventHotKeyRef?) {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        RegisterEventHotKey(config.keyCode, config.carbonModifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
    }

    private func unregister(_ ref: inout EventHotKeyRef?) {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
    }

    private func fire(id: UInt32) {
        switch id {
        case 2:
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            EditorLauncher.shared.openBrowser?()
        default:
            EditorLauncher.shared.openFinderSelection()
        }
    }
}

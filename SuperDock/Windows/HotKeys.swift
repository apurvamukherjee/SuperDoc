import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "hotkeys")

/// System-wide hotkeys via Carbon's RegisterEventHotKey: still the only public API for global shortcuts,
/// and it needs no extra permission. (The KeyboardShortcuts package wraps the same call.)
@MainActor
final class HotKeys {
    static let shared = HotKeys()

    struct Shortcut: Hashable {
        var keyCode: Int
        var modifiers: Int   // Carbon masks: optionKey, shiftKey, controlKey, cmdKey
    }

    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1

    private init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            // Carbon delivers hotkey events on the main thread's event loop.
            MainActor.assumeIsolated { HotKeys.shared.actions[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
        if status != noErr { log.error("InstallEventHandler failed: \(status)") }
    }

    /// Returns an id for `unregister`, or nil if another app already owns the shortcut.
    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(shortcut.keyCode), UInt32(shortcut.modifiers),
                                         EventHotKeyID(signature: OSType(0x53_44_4B_31), id: id),   // "SDK1"
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            log.error("Couldn't register hotkey \(shortcut.keyCode)/\(shortcut.modifiers): \(status)")
            return nil
        }
        refs[id] = ref
        actions[id] = action
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        actions[id] = nil
    }
}

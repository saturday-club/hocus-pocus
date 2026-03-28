import AppKit
import Carbon

@MainActor
final class HotkeyManager {
    typealias HotkeyAction = @MainActor () -> Void

    private var registeredHotkeys: [EventHotKeyRef] = []
    private static var actions: [UInt32: HotkeyAction] = [:]
    private static var nextID: UInt32 = 1

    func registerDefaults(
        toggle: @escaping HotkeyAction,
        cycleMode: @escaping HotkeyAction,
        excludeCurrentApp: @escaping HotkeyAction
    ) {
        // Cmd+Shift+F: Toggle overlay
        register(
            keyCode: UInt32(kVK_ANSI_F),
            modifiers: UInt32(cmdKey | shiftKey),
            action: toggle
        )

        // Cmd+Shift+M: Cycle mode
        register(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(cmdKey | shiftKey),
            action: cycleMode
        )

        // Cmd+Shift+E: Exclude current app
        register(
            keyCode: UInt32(kVK_ANSI_E),
            modifiers: UInt32(cmdKey | shiftKey),
            action: excludeCurrentApp
        )

        installEventHandler()
    }

    private func register(keyCode: UInt32, modifiers: UInt32, action: @escaping HotkeyAction) {
        let id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action

        let signature = OSType(0x4155_544F)  // "AUTO"
        let hotkeyID = EventHotKeyID(signature: signature, id: id)
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            registeredHotkeys.append(ref)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                if let action = HotkeyManager.actions[hotkeyID.id] {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            action()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    func unregisterAll() {
        for ref in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()
        Self.actions.removeAll()
    }
}

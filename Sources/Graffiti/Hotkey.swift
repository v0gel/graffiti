// The ⌃⌘V shortcut.

import Carbon
import AppKit

final class Hotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static var current: Hotkey?

    private static let keyCodes: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "g": 5, "h": 4
    ]

    init(spec: String, action: @escaping () -> Void) {
        self.action = action
        Self.current = self
        var mods: UInt32 = 0, key: UInt32 = 9
        for part in spec.lowercased().split(separator: "+") {
            switch part {
            case "cmd", "command": mods |= UInt32(cmdKey)
            case "ctrl", "control": mods |= UInt32(controlKey)
            case "opt", "option", "alt": mods |= UInt32(optionKey)
            case "shift": mods |= UInt32(shiftKey)
            default: if let c = part.first, let k = Self.keyCodes[c] { key = k }
            }
        }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Hotkey.current?.action() }
            return noErr
        }, 1, &type, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x47524654), id: 1)
        let st = RegisterEventHotKey(key, mods, id, GetApplicationEventTarget(), 0, &ref)
    }
}

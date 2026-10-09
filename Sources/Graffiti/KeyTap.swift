// Catches number keys while the wall is open, since the wall never takes focus from what you're typing in.

import AppKit

final class KeyTap {
    static var handler: ((UInt16, Bool) -> Bool)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { return Unmanaged.passUnretained(event) }
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let shift = event.flags.contains(.maskShift)
            if let h = KeyTap.handler, h(code, shift) { return nil }
            return Unmanaged.passUnretained(event)
        }, userInfo: nil)
        guard let tap else { return }
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
}

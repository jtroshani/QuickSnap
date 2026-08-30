import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide keyboard shortcut using Carbon's
/// `RegisterEventHotKey`. Unlike a `CGEventTap`, this needs **no** Accessibility
/// permission — it just works after launch.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("QSNP"), id: 1)

    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }
            let handler = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            var firedID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &firedID)
            if firedID.id == handler.hotKeyID.id {
                DispatchQueue.main.async { handler.action?() }
            }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        RegisterEventHotKey(keyCode, Self.carbonModifiers(from: modifiers),
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift)   { value |= UInt32(shiftKey) }
        if flags.contains(.option)  { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }
}

private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) | (OSType(scalar.value) & 0xFF)
    }
    return result
}

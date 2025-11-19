#if os(macOS)
import Foundation
import Carbon.HIToolbox

final class ShortcutManager {
    static let shared = ShortcutManager()

    private var temporaryRef: EventHotKeyRef?
    private var mainRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: ((RecordingMode) -> Void)?

    private init() {}

    func configure(temporary: RecordingShortcut, main: RecordingShortcut, handler: @escaping (RecordingMode) -> Void) {
        callback = handler
        unregister()
        installHandlerIfNeeded()
        temporaryRef = register(shortcut: temporary, id: 1)
        mainRef = register(shortcut: main, id: 2)
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handle(event: event)
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
    }

    private func register(shortcut: RecordingShortcut, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("LUMA".fourCharCodeValue), id: id)
        let result = RegisterEventHotKey(shortcut.carbonKeyCode, shortcut.carbonFlags, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if result != noErr {
            return nil
        }
        return ref
    }

    private func unregister() {
        if let temp = temporaryRef {
            UnregisterEventHotKey(temp)
            temporaryRef = nil
        }
        if let main = mainRef {
            UnregisterEventHotKey(main)
            mainRef = nil
        }
    }

    private func handle(event: EventRef?) -> OSStatus {
        guard let event = event else { return noErr }
        var hotKeyID = EventHotKeyID()
        var size = MemoryLayout<EventHotKeyID>.size
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, size, &size, &hotKeyID)
        guard status == noErr else { return noErr }
        guard hotKeyID.signature == OSType("LUMA".fourCharCodeValue) else { return noErr }
        switch hotKeyID.id {
        case 1:
            callback?(.temporaryPrompt)
        case 2:
            callback?(.mainContent)
        default:
            break
        }
        return noErr
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for scalar in unicodeScalars {
            result = (result << 8) + UInt32(scalar.value)
        }
        return result
    }
}
#endif

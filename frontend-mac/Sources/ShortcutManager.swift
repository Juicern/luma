#if os(macOS)
import Cocoa
import Carbon.HIToolbox

final class ShortcutManager {
    static let shared = ShortcutManager()

    private var temporaryShortcut: RecordingShortcut?
    private var mainShortcut: RecordingShortcut?
    private var cancelHandler: (() -> Void)?
    private var handler: ((RecordingMode) -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    func configure(temporary: RecordingShortcut, main: RecordingShortcut, cancel: (() -> Void)? = nil, handler: @escaping (RecordingMode) -> Void) {
        temporaryShortcut = temporary
        mainShortcut = main
        cancelHandler = cancel
        self.handler = handler
        installTapIfNeeded()
    }

    private func installTapIfNeeded() {
        guard eventTap == nil else { return }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            NSLog("Luma needs Accessibility permissions to register global shortcuts. Please grant them in System Settings > Privacy & Security > Accessibility.")
            return
        }

        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            // Auto-reenable if the system temporarily disables the tap.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon = refcon {
                    let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
                return Unmanaged.passUnretained(event)
            }
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handle(event: event, type: type)
            return Unmanaged.passUnretained(event)
        }
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        guard let eventTap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func handle(event: CGEvent, type: CGEventType) {
        guard let handler else { return }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        // Modifier-only shortcuts fire on flagsChanged; key+modifier fire on keyDown.
        if let shortcut = temporaryShortcut {
            if shortcut.isModifierOnly, type == .flagsChanged, shortcut.matches(keyCode: nil, flags: flags) {
                DispatchQueue.main.async { handler(.temporaryPrompt) }
                return
            } else if !shortcut.isModifierOnly, type == .keyDown, shortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { handler(.temporaryPrompt) }
                return
            }
        }

        if let shortcut = mainShortcut {
            if shortcut.isModifierOnly, type == .flagsChanged, shortcut.matches(keyCode: nil, flags: flags) {
                DispatchQueue.main.async { handler(.mainContent) }
                return
            } else if !shortcut.isModifierOnly, type == .keyDown, shortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { handler(.mainContent) }
                return
            }
        }

        if type == .keyDown && keyCode == CGKeyCode(kVK_Escape) {
            DispatchQueue.main.async { [weak self] in
                self?.cancelHandler?()
            }
        }
    }
}
#endif

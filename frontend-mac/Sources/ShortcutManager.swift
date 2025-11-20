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
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard type == .keyDown, let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(refcon).takeUnretainedValue()
            manager.handle(event: event)
            return Unmanaged.passUnretained(event)
        }
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
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

    private func handle(event: CGEvent) {
        guard let handler else { return }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        if let shortcut = temporaryShortcut, shortcut.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { handler(.temporaryPrompt) }
        } else if let shortcut = mainShortcut, shortcut.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { handler(.mainContent) }
        } else if keyCode == CGKeyCode(kVK_Escape) {
            DispatchQueue.main.async { [weak self] in
                self?.cancelHandler?()
            }
        }
    }
}
#endif

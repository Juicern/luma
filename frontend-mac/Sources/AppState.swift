import Foundation
import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SessionSummary: Identifiable, Hashable {
    let id: UUID
    var title: String
    var promptPreview: String
    var updatedAt: Date
    var status: String
}

struct RecordingShortcut: Hashable {
    var key: String
    private var modifiersRaw: UInt

    init(key: String, modifiersRaw: UInt = 0) {
        self.key = key
        self.modifiersRaw = modifiersRaw
    }

    #if os(macOS)
    init(key: String, modifiers: NSEvent.ModifierFlags) {
        self.key = key
        self.modifiersRaw = modifiers.rawValue
    }
    #endif

    var displayText: String {
        #if os(macOS)
        let flags = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.control) { parts.append("⌃") }
        #else
        let parts: [String] = []
        #endif
        return (parts + [key.uppercased()]).joined()
    }

    #if os(macOS)
    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key.lowercased()))
    }

    var eventModifiers: EventModifiers {
        var mods: EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }
        return mods
    }
    #endif

    #if os(macOS)
    var nsFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRaw) }
    #endif
}

enum RecordingMode {
    case idle
    case temporaryPrompt
    case mainContent
}

final class AppState: ObservableObject {
    @Published var microphoneAuthorized = false
    @Published var apiKey: String = ""
    @Published var apiKeyStatus: String = ""
    @Published var userPrompt: String = "Write concise professional replies."
    @Published var systemPrompt: String = "Rewrite the transcript as an informal message..."
    @Published var sessions: [SessionSummary] = []
    @Published var recordingMode: RecordingMode = .idle
    @Published var temporaryShortcut = RecordingShortcut(key: "R", modifiers: [.command, .option])
    @Published var mainShortcut = RecordingShortcut(key: "M", modifiers: [.option])
    @Published var allowSharedShortcut = true
    @Published var clipboardEnabled = true
    @Published var contextText: String = ""

    private var recorder = AudioPermissionManager()

    func bootstrap() {
        sessions = demoSessions()
        requestMicrophonePermission()
    }

    func requestMicrophonePermission() {
        recorder.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneAuthorized = granted
            }
        }
    }

    func startRecording(_ mode: RecordingMode) {
        guard microphoneAuthorized else { return }
        recordingMode = mode
        // TODO: hook into actual audio capture and backend streaming.
    }

    func stopRecording() {
        recordingMode = .idle
    }

    func saveAPIKey() {
        // TODO: post to backend. For now we only show optimistic feedback.
        apiKeyStatus = "API key cached locally at \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
    }

    func updateShortcut(_ shortcut: RecordingShortcut, forTemporary: Bool) {
        if forTemporary {
            temporaryShortcut = shortcut
            if allowSharedShortcut {
                mainShortcut = shortcut
            }
        } else {
            mainShortcut = shortcut
        }
    }

    private func demoSessions() -> [SessionSummary] {
        (0..<3).map { index in
            SessionSummary(
                id: UUID(),
                title: "Draft #\(index + 1)",
                promptPreview: userPrompt,
                updatedAt: Date().addingTimeInterval(Double(-index) * 3600),
                status: index == 0 ? "Ready" : "Edited"
            )
        }
    }
}

final class AudioPermissionManager {
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}

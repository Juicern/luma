import Foundation
import AVFoundation
import SwiftUI

struct PromptPreset: Identifiable, Hashable {
    let id: UUID
    var name: String
    var details: String
}

struct SessionSummary: Identifiable, Hashable {
    let id: UUID
    var title: String
    var presetName: String
    var updatedAt: Date
    var status: String
}

struct RecordingShortcut: Hashable {
    var description: String
    var canShareWithOther: Bool = true
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
    @Published var selectedPreset: PromptPreset?
    @Published var presets: [PromptPreset] = [
        .init(id: UUID(), name: "Professional", details: "Tidy business replies"),
        .init(id: UUID(), name: "Casual", details: "Playful tone"),
        .init(id: UUID(), name: "CN → EN", details: "Translate to English")
    ]
    @Published var sessions: [SessionSummary] = []
    @Published var recordingMode: RecordingMode = .idle
    @Published var temporaryShortcut = RecordingShortcut(description: "⌘⌥")
    @Published var mainShortcut = RecordingShortcut(description: "⌥")
    @Published var allowSharedShortcut = true
    @Published var clipboardEnabled = true
    @Published var contextText: String = ""

    private var recorder = AudioPermissionManager()

    func bootstrap() {
        selectedPreset = presets.first
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
                presetName: presets[min(index, presets.count - 1)].name,
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

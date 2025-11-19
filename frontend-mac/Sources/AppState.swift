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

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let email: String
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
    @Published var backendBaseURL = "http://localhost:8080"
    @Published var userName = ""
    @Published var userEmail = ""
    @Published var userPassword = ""
    @Published var userID: String = ""
    @Published var userStatus: String = ""
    @Published var users: [UserProfile] = []
    @Published var selectedUser: UserProfile?
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
    @Published var recordingIndicator: String = ""

    private var recorder = AudioPermissionManager()
#if os(macOS)
    private var localMonitor: Any?
    private var globalMonitor: Any?
#endif

    func bootstrap() {
        sessions = demoSessions()
        requestMicrophonePermission()
#if os(macOS)
        startShortcutMonitors()
#endif
        loadUsers()
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
        switch mode {
        case .temporaryPrompt:
            recordingIndicator = "Listening for temporary prompt…"
        case .mainContent:
            recordingIndicator = "Listening for main content…"
        case .idle:
            recordingIndicator = ""
        }
        // TODO: hook into actual audio capture and backend streaming.
    }

    func stopRecording() {
        recordingMode = .idle
        recordingIndicator = ""
    }

    func saveAPIKey() {
        guard !userID.isEmpty else {
            apiKeyStatus = "Create user first"
            return
        }
        guard let url = URL(string: "\(backendBaseURL)/api/v1/api-keys/openai") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["user_id": userID, "api_key": apiKey]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.apiKeyStatus = "Failed: \(error.localizedDescription)"
                } else if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    self?.apiKeyStatus = "API key saved at \(Self.timestamp())"
                } else {
                    self?.apiKeyStatus = "Unexpected response"
                }
            }
        }.resume()
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

    func registerUser() {
        guard let url = URL(string: "\(backendBaseURL)/api/v1/users") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["name": userName, "email": userEmail, "password": userPassword]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.userStatus = "Failed: \(error.localizedDescription)"
                    return
                }
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let id = json["id"] as? String
                else {
                    self.userStatus = "Invalid response"
                    return
                }
                self.userID = id
                self.userStatus = "User created"
                self.loadUsers()
            }
        }.resume()
    }

    func loadUsers() {
        guard let url = URL(string: "\(backendBaseURL)/api/v1/users") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                    if let error = error {
                        self.userStatus = "Failed fetching users: \(error.localizedDescription)"
                        return
                    }
                    guard
                        let data = data,
                        let profiles = try? JSONDecoder().decode([UserProfile].self, from: data)
                    else {
                        self.userStatus = "Failed parsing users"
                        return
                    }
                    self.users = profiles
                    if let current = profiles.first(where: { $0.id == self.userID }) {
                        self.select(user: current)
                    }
            }
        }.resume()
    }

    func select(user: UserProfile) {
        selectedUser = user
        userID = user.id
        userName = user.name
        userEmail = user.email
        userStatus = "Loaded existing user"
    }

#if os(macOS)
    func refreshClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            contextText = string
        }
    }

    private func startShortcutMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handle(event: event) == true {
                return nil
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event: event)
        }
    }

    private func handle(event: NSEvent) -> Bool {
        guard microphoneAuthorized else { return false }
        if matches(event, shortcut: temporaryShortcut) {
            toggle(mode: .temporaryPrompt)
            return true
        }
        if matches(event, shortcut: mainShortcut) {
            toggle(mode: .mainContent)
            return true
        }
        return false
    }

    private func toggle(mode: RecordingMode) {
        if recordingMode == mode {
            stopRecording()
        } else {
            startRecording(mode)
        }
    }

    private func matches(_ event: NSEvent, shortcut: RecordingShortcut) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.uppercased() else { return false }
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        return chars == shortcut.key.uppercased() && flags == shortcut.nsFlags
    }
#endif

    static func timestamp() -> String {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    }
}

final class AudioPermissionManager {
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}

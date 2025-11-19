import Foundation
import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
import Carbon.HIToolbox
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

    var eventModifiers: SwiftUI.EventModifiers {
        var mods: SwiftUI.EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.control) }
        return mods
    }

    var nsFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRaw) }

    var carbonKeyCode: UInt32 {
        let uppercase = key.uppercased()
        if let code = RecordingShortcut.keyCodes[uppercase] {
            return code
        }
        return UInt32(kVK_ANSI_A)
    }

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        let nsFlags = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        if nsFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if nsFlags.contains(.option) { flags |= UInt32(optionKey) }
        if nsFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        if nsFlags.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    private static let keyCodes: [String: UInt32] = {
        var dict: [String: UInt32] = [:]
        for (index, letter) in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ").enumerated() {
            dict[String(letter)] = UInt32(kVK_ANSI_A + index)
        }
        for (index, digit) in ("0123456789").enumerated() {
            dict[String(digit)] = UInt32(kVK_ANSI_0 + index)
        }
        dict[";"] = UInt32(kVK_ANSI_Semicolon)
        dict[","] = UInt32(kVK_ANSI_Comma)
        dict["."] = UInt32(kVK_ANSI_Period)
        return dict
    }()
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
    @Published var apiKeys: [String: String] = [:]
    @Published var providerOptions = ["openai", "gemini"]
    @Published var selectedProvider: String = "openai" {
        didSet { updateActiveAPIKey() }
    }
    @Published var userPrompt: String = "Write concise professional replies."
    @Published var systemPrompt: String = "Rewrite the transcript as an informal message..."
    @Published var sessions: [SessionSummary] = []
    @Published var recordingMode: RecordingMode = .idle
    @Published var temporaryShortcut = RecordingShortcut(key: "R", modifiers: [.command, .option])
    @Published var mainShortcut = RecordingShortcut(key: "M", modifiers: [.option])
    @Published var allowSharedShortcut = true {
        didSet { rebindShortcuts() }
    }
    @Published var clipboardEnabled = true
    @Published var contextText: String = ""
    @Published var recordingIndicator: String = ""

    private var recorder = AudioPermissionManager()
#if os(macOS)
    private let shortcutManager = ShortcutManager.shared
#endif
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var activeRecordingMode: RecordingMode?

    func bootstrap() {
        sessions = demoSessions()
        requestMicrophonePermission()
        rebindShortcuts()
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
        activeRecordingMode = mode
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("luma-\(UUID().uuidString).m4a")
        currentRecordingURL = fileURL
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
        } catch {
            recordingIndicator = "Recording failed: \(error.localizedDescription)"
            currentRecordingURL = nil
        }
    }

    func stopRecording() {
        recordingMode = .idle
        recordingIndicator = ""
        audioRecorder?.stop()
        audioRecorder = nil
        let mode = activeRecordingMode
        activeRecordingMode = nil
        if let url = currentRecordingURL, let mode = mode {
            uploadRecording(fileURL: url, mode: mode)
        }
        currentRecordingURL = nil
    }

    func saveAPIKey() {
        guard !userID.isEmpty else {
            apiKeyStatus = "Create user first"
            return
        }
        guard let url = URL(string: "\(backendBaseURL)/api/v1/api-keys/\(selectedProvider)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["user_id": userID, "api_key": apiKey]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.apiKeyStatus = "Failed: \(error.localizedDescription)"
                } else if let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    self.apiKeyStatus = "API key saved at \(Self.timestamp())"
                    self.apiKeys[self.selectedProvider] = self.apiKey
                    self.loadAPIKeys()
                } else {
                    self.apiKeyStatus = "Unexpected response"
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
                self.loadAPIKeys()
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
        loadAPIKeys()
    }

#if os(macOS)
    func refreshClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            contextText = string
        }
    }
#endif

    static func timestamp() -> String {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    }

    private func uploadRecording(fileURL: URL, mode: RecordingMode) {
        guard !userID.isEmpty, let url = URL(string: "\(backendBaseURL)/api/v1/transcriptions") else { return }
        guard let audioData = try? Data(contentsOf: fileURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n\(userID)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"mode\"\r\n\r\n\(mode == .temporaryPrompt ? "prompt" : "content")\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n")
        body.appendString("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n--\(boundary)--\r\n")
        URLSession.shared.uploadTask(with: request, from: body) { _, _, _ in
            try? FileManager.default.removeItem(at: fileURL)
        }.resume()
    }

    private func rebindShortcuts() {
#if os(macOS)
        shortcutManager.configure(temporary: temporaryShortcut, main: mainShortcut) { [weak self] mode in
            DispatchQueue.main.async {
                self?.handleShortcut(mode: mode)
            }
        }
#endif
    }

#if os(macOS)
    private func handleShortcut(mode: RecordingMode) {
        if recordingMode == mode {
            stopRecording()
        } else {
            startRecording(mode)
        }
    }
#endif

    private func updateActiveAPIKey() {
        apiKey = apiKeys[selectedProvider] ?? ""
    }

    private func loadAPIKeys() {
        guard !userID.isEmpty, let url = URL(string: "\(backendBaseURL)/api/v1/api-keys?user_id=\(userID)") else {
            apiKeys = [:]
            apiKey = ""
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let data = data, let decoded = try? JSONDecoder().decode([APIKeyDTO].self, from: data) {
                    var dict: [String: String] = [:]
                    decoded.forEach { dict[$0.providerName] = $0.apiKey }
                    self.apiKeys = dict
                    self.updateActiveAPIKey()
                }
            }
        }.resume()
    }
}

final class AudioPermissionManager {
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}

struct APIKeyDTO: Decodable {
    let providerName: String
    let apiKey: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case providerName = "provider_name"
        case apiKey = "api_key"
        case updatedAt = "updated_at"
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

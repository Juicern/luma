import Foundation
import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
import ApplicationServices
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
        dict["0"] = UInt32(kVK_ANSI_0)
        dict["1"] = UInt32(kVK_ANSI_1)
        dict["2"] = UInt32(kVK_ANSI_2)
        dict["3"] = UInt32(kVK_ANSI_3)
        dict["4"] = UInt32(kVK_ANSI_4)
        dict["5"] = UInt32(kVK_ANSI_5)
        dict["6"] = UInt32(kVK_ANSI_6)
        dict["7"] = UInt32(kVK_ANSI_7)
        dict["8"] = UInt32(kVK_ANSI_8)
        dict["9"] = UInt32(kVK_ANSI_9)
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
    @Published var currentUser: UserProfile?
    @Published var userID: String = ""
    @Published var loginEmail: String = ""
    @Published var loginPassword: String = ""
    @Published var loginStatus: String = ""
    @Published var isLoggedIn: Bool = false
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
    @Published var latestPromptText: String = ""
    @Published var latestContentText: String = ""
    @Published var captureStatus: String = ""

    private var recorder = AudioPermissionManager()
#if os(macOS)
    private let shortcutManager = ShortcutManager.shared
    private var accessibilityTimer: Timer?
#endif
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var activeRecordingMode: RecordingMode?

    func bootstrap() {
        sessions = demoSessions()
        requestMicrophonePermission()
        requestAccessibilityPermission()
#if os(macOS)
        refreshClipboard()
#endif
        rebindShortcuts()
        restoreSession()
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
        guard isLoggedIn else {
            captureStatus = "Log in to start recording."
            return
        }
        recordingMode = mode
        switch mode {
        case .temporaryPrompt:
            recordingIndicator = "Listening for temporary prompt…"
            captureStatus = "Recording temporary prompt…"
        case .mainContent:
            recordingIndicator = "Listening for main content…"
            captureStatus = "Recording main content…"
        case .idle:
            recordingIndicator = ""
        }
        updateRecordingHUD()
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
            updateRecordingHUD()
            currentRecordingURL = nil
        }
    }

    func stopRecording() {
        recordingMode = .idle
        recordingIndicator = ""
        captureStatus = "Processing audio…"
        updateRecordingHUD()
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
            apiKeyStatus = "Log in first"
            return
        }
        guard let url = URL(string: "\(backendBaseURL)/api/v1/api-keys/\(selectedProvider)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["api_key": apiKey]
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
        rebindShortcuts()
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

    func login() {
        guard let url = URL(string: "\(backendBaseURL)/api/v1/login") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["email": loginEmail, "password": loginPassword]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.loginStatus = "Login failed: \(error.localizedDescription)"
                    return
                }
                guard
                    let response = response as? HTTPURLResponse,
                    let data = data,
                    response.statusCode == 200,
                    let user = try? JSONDecoder().decode(UserProfile.self, from: data)
                else {
                    self.loginStatus = "Invalid email or password"
                    return
                }
                self.applyLoggedInUser(user)
                self.loginStatus = "Signed in"
                self.loginPassword = ""
                self.loadAPIKeys()
            }
        }.resume()
    }

    func restoreSession() {
        guard let url = URL(string: "\(backendBaseURL)/api/v1/session") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let http = response as? HTTPURLResponse else {
                    return
                }
                if http.statusCode == 200, let data = data, let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
                    self.applyLoggedInUser(user)
                    self.loadAPIKeys()
                } else if http.statusCode == 401 {
                    self.logoutLocal()
                }
            }
        }.resume()
    }

    func logout() {
        guard let url = URL(string: "\(backendBaseURL)/api/v1/logout") else {
            logoutLocal()
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.logoutLocal()
            }
        }.resume()
    }

    private func applyLoggedInUser(_ user: UserProfile) {
        currentUser = user
        userID = user.id
        isLoggedIn = true
        loginStatus = ""
        loginEmail = user.email
        rebindShortcuts()
    }

    private func logoutLocal() {
        currentUser = nil
        userID = ""
        isLoggedIn = false
        apiKeys = [:]
        apiKey = ""
        rebindShortcuts()
    }

    func requestAccessibilityPermission() {
#if os(macOS)
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
            startAccessibilityPolling()
        }
#endif
    }

#if os(macOS)
    func refreshClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            contextText = string
        }
    }

    private func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.rebindShortcuts()
            }
        }
    }
#endif

    static func timestamp() -> String {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    }

    private func uploadRecording(fileURL: URL, mode: RecordingMode) {
        guard !userID.isEmpty, let url = URL(string: "\(backendBaseURL)/api/v1/transcriptions") else {
            captureStatus = "Login required to upload audio."
            return
        }
        guard let audioData = try? Data(contentsOf: fileURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"mode\"\r\n\r\n\(mode == .temporaryPrompt ? "prompt" : "content")\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"provider\"\r\n\r\n\(selectedProvider)\r\n")
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n")
        body.appendString("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.appendString("\r\n--\(boundary)--\r\n")
        URLSession.shared.uploadTask(with: request, from: body) { [weak self] data, response, error in
            defer { try? FileManager.default.removeItem(at: fileURL) }
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.captureStatus = "Upload failed: \(error.localizedDescription)"
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    self.captureStatus = "No server response"
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    let serverMessage: String
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        serverMessage = body
                    } else {
                        serverMessage = "status \(http.statusCode)"
                    }
                    self.captureStatus = "Server error: \(serverMessage)"
                    return
                }
                guard
                    let data = data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let transcription = json["transcription"] as? String
                else {
                    self.captureStatus = "Unable to parse transcription response"
                    return
                }
                self.applyTranscription(transcription, mode: mode)
            }
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
        guard isLoggedIn else {
            captureStatus = "Log in to record audio."
            return
        }
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
        guard isLoggedIn, let url = URL(string: "\(backendBaseURL)/api/v1/api-keys") else {
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

    func copyLatestPromptToClipboard() {
        copyResultToClipboard(latestPromptText)
    }

    func copyLatestContentToClipboard() {
        copyResultToClipboard(latestContentText)
    }

    private func applyTranscription(_ text: String, mode: RecordingMode) {
        switch mode {
        case .temporaryPrompt:
            latestPromptText = text
            userPrompt = text
            captureStatus = "Temporary prompt captured."
        case .mainContent:
            latestContentText = text
            captureStatus = "Main content captured and copied."
            copyResultToClipboard(text)
            pasteClipboardToFrontmostApp()
        case .idle:
            captureStatus = "Capture complete."
        }
    }

#if os(macOS)
    private func copyResultToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        contextText = text
    }

    private func pasteClipboardToFrontmostApp() {
        guard AXIsProcessTrusted(), let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
#else
    private func copyResultToClipboard(_ text: String) {}
    private func pasteClipboardToFrontmostApp() {}
#endif

#if os(macOS)
    private func updateRecordingHUD() {
        if recordingIndicator.isEmpty {
            RecordingHUD.shared.hide()
        } else {
            RecordingHUD.shared.show(message: recordingIndicator)
        }
    }
#else
    private func updateRecordingHUD() {}
#endif
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

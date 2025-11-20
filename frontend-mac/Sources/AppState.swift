import Foundation
import AVFoundation
import SwiftUI
#if os(macOS)
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Carbon
#endif

#if os(macOS)
extension NSEvent.ModifierFlags {
    static let leftCommand = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELCMDKEYMASK))
    static let rightCommand = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERCMDKEYMASK))
    static let leftOption = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELALTKEYMASK))
    static let rightOption = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERALTKEYMASK))
    static let leftShift = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELSHIFTKEYMASK))
    static let rightShift = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERSHIFTKEYMASK))
    static let leftControl = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICELCTLKEYMASK))
    static let rightControl = NSEvent.ModifierFlags(rawValue: UInt(NX_DEVICERCTLKEYMASK))
}
#endif

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
        self.modifiersRaw = RecordingShortcut.normalizeModifiers(modifiers).rawValue
    }
    #endif

    var displayText: String {
#if os(macOS)
        let flags = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        var parts: [String] = []
        if flags.contains(.leftCommand) { parts.append("⌘L") }
        else if flags.contains(.rightCommand) { parts.append("⌘R") }
        else if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.leftOption) { parts.append("⌥L") }
        else if flags.contains(.rightOption) { parts.append("⌥R") }
        else if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.leftShift) { parts.append("⇧L") }
        else if flags.contains(.rightShift) { parts.append("⇧R") }
        else if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.leftControl) { parts.append("⌃L") }
        else if flags.contains(.rightControl) { parts.append("⌃R") }
        else if flags.contains(.control) { parts.append("⌃") }
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
        if flags.contains(.command) || flags.contains(.leftCommand) || flags.contains(.rightCommand) { mods.insert(.command) }
        if flags.contains(.option) || flags.contains(.leftOption) || flags.contains(.rightOption) { mods.insert(.option) }
        if flags.contains(.shift) || flags.contains(.leftShift) || flags.contains(.rightShift) { mods.insert(.shift) }
        if flags.contains(.control) || flags.contains(.leftControl) || flags.contains(.rightControl) { mods.insert(.control) }
        return mods
    }

    var nsFlags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRaw) }

    private var carbonKeyCode: UInt32 {
        let uppercase = key.uppercased()
        if let code = RecordingShortcut.keyCodes[uppercase] {
            return code
        }
        return UInt32(kVK_ANSI_A)
    }

    var cgKeyCode: CGKeyCode {
        CGKeyCode(carbonKeyCode)
    }

    func matches(keyCode: CGKeyCode, flags eventFlags: NSEvent.ModifierFlags) -> Bool {
        guard keyCode == cgKeyCode else { return false }
        let normalizedRequired = RecordingShortcut.normalizeModifiers(NSEvent.ModifierFlags(rawValue: modifiersRaw))
        let normalizedEvent = RecordingShortcut.normalizeModifiers(eventFlags)
        return ModifierSignature(flags: normalizedEvent).satisfies(required: ModifierSignature(flags: normalizedRequired))
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

    static func normalizeModifiers(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        var normalized = flags.intersection([
            .command, .option, .shift, .control,
            .leftCommand, .rightCommand,
            .leftOption, .rightOption,
            .leftShift, .rightShift,
            .leftControl, .rightControl
        ])
        if normalized.contains(.leftCommand) || normalized.contains(.rightCommand) {
            normalized.remove(.command)
        }
        if normalized.contains(.leftOption) || normalized.contains(.rightOption) {
            normalized.remove(.option)
        }
        if normalized.contains(.leftShift) || normalized.contains(.rightShift) {
            normalized.remove(.shift)
        }
        if normalized.contains(.leftControl) || normalized.contains(.rightControl) {
            normalized.remove(.control)
        }
        return normalized
    }

    private struct ModifierSignature {
        var anyCommand = false
        var leftCommand = false
        var rightCommand = false
        var anyOption = false
        var leftOption = false
        var rightOption = false
        var anyShift = false
        var leftShift = false
        var rightShift = false
        var anyControl = false
        var leftControl = false
        var rightControl = false

        init(flags: NSEvent.ModifierFlags) {
            anyCommand = flags.contains(.command)
            leftCommand = flags.contains(.leftCommand)
            rightCommand = flags.contains(.rightCommand)
            anyOption = flags.contains(.option)
            leftOption = flags.contains(.leftOption)
            rightOption = flags.contains(.rightOption)
            anyShift = flags.contains(.shift)
            leftShift = flags.contains(.leftShift)
            rightShift = flags.contains(.rightShift)
            anyControl = flags.contains(.control)
            leftControl = flags.contains(.leftControl)
            rightControl = flags.contains(.rightControl)
        }

        func satisfies(required: ModifierSignature) -> Bool {
            func check(any: Bool, left: Bool, right: Bool, eventAny: Bool, eventLeft: Bool, eventRight: Bool) -> Bool {
                if left && !eventLeft { return false }
                if right && !eventRight { return false }
                if any {
                    if !(eventLeft || eventRight || eventAny) { return false }
                } else if !left && !right {
                    if eventLeft || eventRight || eventAny { return false }
                }
                return true
            }
            return check(any: required.anyCommand, left: required.leftCommand, right: required.rightCommand, eventAny: anyCommand, eventLeft: leftCommand, eventRight: rightCommand)
                && check(any: required.anyOption, left: required.leftOption, right: required.rightOption, eventAny: anyOption, eventLeft: leftOption, eventRight: rightOption)
                && check(any: required.anyShift, left: required.leftShift, right: required.rightShift, eventAny: anyShift, eventLeft: leftShift, eventRight: rightShift)
                && check(any: required.anyControl, left: required.leftControl, right: required.rightControl, eventAny: anyControl, eventLeft: leftControl, eventRight: rightControl)
        }
    }
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
        didSet {
            updateActiveAPIKey()
            updateActiveModel()
        }
    }
    @Published var userPrompt: String = "Write concise professional replies."
    @Published var systemPrompt: String = "Rewrite the transcript as an informal message..."
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
    @Published var pasteStatus: String = ""
    @Published var accessibilityGranted: Bool = false
    @Published var providerModels: [String: [String]] = [
        "openai": ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini"],
        "gemini": ["gemini-1.5-pro", "gemini-1.5-flash"]
    ]
    @Published var selectedModel: String = ""
    @Published var presets: [PromptPresetModel] = []
    @Published var selectedPresetID: String?
    @Published var presetStatus: String = ""
    @Published var transcriptionHistory: [TranscriptionHistoryItem] = []
    @Published var transcriptionSearch: String = ""
    @Published var promptPreview: PromptPreviewState?
    @Published var isAddPromptPresented = false
    @Published var draftPromptName: String = ""
    @Published var draftPromptText: String = ""
    let defaultPromptTemplates: [PromptTemplate] = [
        PromptTemplate(
            name: "Default",
            description: "Balanced friendly reply.",
            text: "Rewrite the user's thoughts into a clear, friendly response. Keep it concise, positive, and easy to scan. Use short paragraphs, respond directly to the main question, and end with an encouraging tone."
        ),
        PromptTemplate(
            name: "Professional",
            description: "Formal, confident email tone.",
            text: "Transform the draft into a polished professional reply. Use a confident, respectful tone, stay concise, and emphasize next steps or outcomes. Avoid slang, use full sentences, and keep the message ready to send as an email."
        ),
        PromptTemplate(
            name: "Literal",
            description: "Mirror user's words exactly.",
            text: "Repeat the user's text verbatim with light cleanup. Fix obvious typos and punctuation, but do not change the meaning, tone, or add commentary. Output the cleaned transcript only."
        )
    ]

    private var recorder = AudioPermissionManager()
#if os(macOS)
    private let shortcutManager = ShortcutManager.shared
    private var accessibilityTimer: Timer?
    private var pendingPasteTarget: NSRunningApplication?
#endif
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var activeRecordingMode: RecordingMode?
    private var lastRecordingStartedAt: Date?

    func bootstrap() {
        requestMicrophonePermission()
        requestAccessibilityPermission()
#if os(macOS)
        refreshClipboard()
        refreshAccessibilityState()
#endif
        rebindShortcuts()
        restoreSession()
        updateActiveModel()
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
        lastRecordingStartedAt = Date()
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
        loadPresets()
    }

    private func logoutLocal() {
        currentUser = nil
        userID = ""
        isLoggedIn = false
        apiKeys = [:]
        apiKey = ""
        presets = []
        selectedPresetID = nil
        presetStatus = ""
        transcriptionHistory = []
        promptPreview = nil
        isAddPromptPresented = false
        rebindShortcuts()
    }

    func requestAccessibilityPermission() {
#if os(macOS)
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
            startAccessibilityPolling()
        } else {
            accessibilityGranted = true
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

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
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
                self.refreshAccessibilityState()
            }
        }
    }

    func refreshAccessibilityState() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func captureFrontmostApp() {
        guard let front = NSWorkspace.shared.frontmostApplication else {
            pendingPasteTarget = nil
            return
        }
        if front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            pendingPasteTarget = front
        } else {
            pendingPasteTarget = nil
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
            captureFrontmostApp()
            startRecording(mode)
        }
    }
#endif

    private func updateActiveAPIKey() {
        apiKey = apiKeys[selectedProvider] ?? ""
    }

    private func updateActiveModel() {
        let models = providerModels[selectedProvider] ?? []
        if models.contains(selectedModel) {
            return
        }
        selectedModel = models.first ?? ""
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

    func loadPresets() {
        guard isLoggedIn, !userID.isEmpty, let url = URL(string: "\(backendBaseURL)/api/v1/presets?user_id=\(userID)") else {
            presets = []
            selectedPresetID = nil
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let data = data, let decoded = try? JSONDecoder().decode([PromptPresetModel].self, from: data) {
                    self.presets = decoded
                    if let currentID = self.selectedPresetID, decoded.contains(where: { $0.id == currentID }) {
                        // keep current selection
                    } else {
                        self.selectedPresetID = nil
                    }
                }
            }
        }.resume()
    }

    func createPreset(name: String, text: String, completion: (() -> Void)? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presetStatus = "Preset name required"
            return
        }
        guard !trimmedText.isEmpty else {
            presetStatus = "Prompt text required"
            return
        }
        guard isLoggedIn, !userID.isEmpty else {
            presetStatus = "Log in to save presets"
            return
        }
        guard let url = URL(string: "\(backendBaseURL)/api/v1/presets") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "user_id": userID,
            "name": trimmedName,
            "prompt_text": trimmedText
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.presetStatus = "Failed: \(error.localizedDescription)"
                    return
                }
                guard
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 201,
                    let data = data,
                    let preset = try? JSONDecoder().decode(PromptPresetModel.self, from: data)
                else {
                    self.presetStatus = "Unexpected response"
                    return
                }
                self.presets.insert(preset, at: 0)
                self.selectedPresetID = preset.id
                self.userPrompt = preset.promptText
                self.presetStatus = "Preset saved"
                completion?()
            }
        }.resume()
    }

    func deletePreset(_ preset: PromptPresetModel) {
        guard isLoggedIn, !userID.isEmpty else {
            presetStatus = "Log in to manage presets"
            return
        }
        guard let url = URL(string: "\(backendBaseURL)/api/v1/presets/\(preset.id)?user_id=\(userID)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.presetStatus = "Delete failed: \(error.localizedDescription)"
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
                    self.presetStatus = "Delete failed"
                    return
                }
                self.presets.removeAll { $0.id == preset.id }
                if self.selectedPresetID == preset.id {
                    self.selectedPresetID = nil
                }
                self.presetStatus = "Preset removed"
            }
        }.resume()
    }

    func selectPreset(_ preset: PromptPresetModel) {
        presentPreset(preset)
    }

    func presentPreset(_ preset: PromptPresetModel) {
        promptPreview = PromptPreviewState(title: preset.name, text: preset.promptText, presetID: preset.id)
    }

    func presentTemplate(_ template: PromptTemplate) {
        selectedPresetID = nil
        promptPreview = PromptPreviewState(title: template.name, text: template.text, presetID: nil)
    }

    func applyPreview(_ preview: PromptPreviewState) {
        userPrompt = preview.text
        selectedPresetID = preview.presetID
        presetStatus = "Using \(preview.title)"
    }

    func beginAddPrompt() {
        draftPromptName = ""
        draftPromptText = userPrompt
        isAddPromptPresented = true
    }

    func submitNewPrompt() {
        createPreset(name: draftPromptName, text: draftPromptText) { [weak self] in
            self?.draftPromptName = ""
            self?.draftPromptText = ""
            self?.isAddPromptPresented = false
        }
    }

    func copyLatestPromptToClipboard() {
        copyResultToClipboard(latestPromptText)
    }

    func copyLatestContentToClipboard() {
        copyResultToClipboard(latestContentText)
    }

    private func applyTranscription(_ text: String, mode: RecordingMode) {
        let duration = recordingDuration()
        switch mode {
        case .temporaryPrompt:
            latestPromptText = text
            userPrompt = text
            captureStatus = "Temporary prompt captured."
        case .mainContent:
            latestContentText = text
            captureStatus = "Main content captured."
            insertTextIntoFrontmostApp(text)
        case .idle:
            captureStatus = "Capture complete."
        }
        logTranscriptionHistory(text: text, mode: mode, duration: duration)
        lastRecordingStartedAt = nil
    }

#if os(macOS)
    private func copyResultToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        contextText = text
    }

    private func insertTextIntoFrontmostApp(_ text: String) {
        guard AXIsProcessTrusted() else {
            updatePasteStatus("Cannot paste: Accessibility permission not granted.")
            return
        }
        guard let target = pendingPasteTarget else {
            updatePasteStatus("Cannot paste: target application missing.")
            return
        }
        target.activate(options: [.activateIgnoringOtherApps])
        pendingPasteTarget = nil
        usleep(150000)

        let pasteboard = NSPasteboard.general
        let snapshot = pasteboardSnapshot()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        updatePasteStatus("Clipboard staged for paste…")

        simulateCommandVPaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.restorePasteboard(from: snapshot)
            self.updatePasteStatus("Paste attempt finished; clipboard restored.")
        }
    }

    private func pasteboardSnapshot() -> [(NSPasteboard.PasteboardType, Data)] {
        let items = NSPasteboard.general.pasteboardItems ?? []
        var snapshot: [(NSPasteboard.PasteboardType, Data)] = []
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    snapshot.append((type, data))
                }
            }
        }
        return snapshot
    }

    private func restorePasteboard(from snapshot: [(NSPasteboard.PasteboardType, Data)]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.isEmpty else {
            updatePasteStatus("Clipboard was empty prior to paste; nothing to restore.")
            return
        }
        for (type, data) in snapshot {
            pasteboard.setData(data, forType: type)
        }
        updatePasteStatus("Clipboard restored to previous content.")
    }

    private func simulateCommandVPaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let cmdKeyCode: UInt16 = 0x37
        let vKeyCode: UInt16 = UInt16(kVK_ANSI_V)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        updatePasteStatus("Simulated ⌘V for pasted result.")
    }

    private func updatePasteStatus(_ message: String) {
        pasteStatus = message
        NSLog("[LumaPaste] %@", message)
    }
#else
    private func copyResultToClipboard(_ text: String) {}
    private func insertTextIntoFrontmostApp(_ text: String) {}
    private func updatePasteStatus(_ message: String) {}
#endif

    private func recordingDuration() -> TimeInterval {
        guard let start = lastRecordingStartedAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    private func logTranscriptionHistory(text: String, mode: RecordingMode, duration: TimeInterval) {
        let entry = TranscriptionHistoryItem(mode: mode, text: text, duration: duration, timestamp: Date())
        transcriptionHistory.insert(entry, at: 0)
        if transcriptionHistory.count > 100 {
            transcriptionHistory.removeLast(transcriptionHistory.count - 100)
        }
    }

#if os(macOS)
    func copyTextToClipboard(_ text: String) {
        copyResultToClipboard(text)
    }
#else
    func copyTextToClipboard(_ text: String) {}
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

struct PromptPresetModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let promptText: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case promptText = "prompt_text"
        case updatedAt = "updated_at"
    }
}

struct TranscriptionHistoryItem: Identifiable {
    let id = UUID()
    let mode: RecordingMode
    let text: String
    let duration: TimeInterval
    let timestamp: Date

    var preview: String {
        if text.count <= 80 {
            return text
        }
        return String(text.prefix(80)) + "…"
    }

    var durationLabel: String {
        String(format: "%.1fs", duration)
    }
}

struct PromptTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let text: String
}

struct PromptPreviewState: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let presetID: String?
}

extension RecordingMode {
    var displayName: String {
        switch self {
        case .temporaryPrompt:
            return "Prompt"
        case .mainContent:
            return "Content"
        case .idle:
            return "Idle"
        }
    }
}

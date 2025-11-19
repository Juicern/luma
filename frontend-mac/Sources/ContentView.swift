import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            VStack {
                if !state.microphoneAuthorized {
                    PermissionGateView()
                } else {
                    MainDashboardView()
                }
            }
            if !state.recordingIndicator.isEmpty {
                RecordingOverlay(message: state.recordingIndicator)
                    .transition(.opacity)
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 600)
    }
}

struct PermissionGateView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Luma Needs Microphone Access")
                .font(.title2)
            Text("We only listen when you trigger a shortcut. Your audio stays local until you confirm.")
                .multilineTextAlignment(.center)
            Button("Grant Access") {
                state.requestMicrophonePermission()
            }
            .buttonStyle(.borderedProminent)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: 360)
    }
}

struct MainDashboardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            TipsColumn()
                .frame(width: 280)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    UserCard()
                    APIKeyCard()
                    ShortcutCard()
                    PromptCard()
                    RecordingControls()
                    SessionList()
                }
            }
        }
    }
}

struct TipsColumn: View {
    private let tips = [
        "1. Paste your API key",
        "2. Customize your prompt",
        "3. Create or resume a session",
        "4. Use shortcuts to capture prompt & content",
        "5. Review the rewrite before sending"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tips")
                .font(.headline)
            ForEach(tips, id: \.self) { tip in
                Label(tip, systemImage: "info.circle")
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct UserCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account & Backend")
                .font(.headline)
            TextField("Backend URL", text: $state.backendBaseURL)
                .textFieldStyle(.roundedBorder)
            if state.isLoggedIn, let user = state.currentUser {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Signed in as \(user.name)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.subheadline)
                    Text(user.email)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("Refresh Session") { state.restoreSession() }
                        Button("Log Out") { state.logout() }
                    }
                    .buttonStyle(.borderedProminent)
                    if !state.userID.isEmpty {
                        Text("User ID stored locally.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in with your Luma account to sync presets and API keys.")
                        .font(.subheadline)
                    TextField("Email", text: $state.loginEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                    SecureField("Password", text: $state.loginPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    HStack {
                        Button("Log In") { state.login() }
                            .buttonStyle(.borderedProminent)
                        Button("Check Saved Session") { state.restoreSession() }
                        if !state.loginStatus.isEmpty {
                            Text(state.loginStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct APIKeyCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider API Key")
                .font(.headline)
            Picker("Provider", selection: $state.selectedProvider) {
                ForEach(state.providerOptions, id: \.self) { provider in
                    Text(provider.capitalized).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            SecureField("sk-...", text: $state.apiKey)
                .textFieldStyle(.roundedBorder)
                .disabled(!state.isLoggedIn)
            HStack {
                Button("Save Key") { state.saveAPIKey() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.isLoggedIn)
                if !state.apiKeyStatus.isEmpty {
                    Text(state.apiKeyStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !state.isLoggedIn {
                    Text("Log in first to sync keys.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ShortcutCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            Toggle("Allow prompt/content shortcuts to be the same", isOn: $state.allowSharedShortcut)
            HStack {
                ShortcutRecorder(title: "Temporary Prompt", shortcut: $state.temporaryShortcut) { shortcut in
                    state.updateShortcut(shortcut, forTemporary: true)
                }
                ShortcutRecorder(title: "Main Content", shortcut: $state.mainShortcut) { shortcut in
                    state.updateShortcut(shortcut, forTemporary: false)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ShortcutRecorder: View {
    var title: String
    @Binding var shortcut: RecordingShortcut
    var onChange: (RecordingShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
            ShortcutCaptureField(title: title, shortcut: $shortcut, onChange: onChange)
                .frame(width: 140, height: 32)
        }
    }
}

struct PromptCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt Composer")
                .font(.headline)
            Text("System Prompt")
                .font(.subheadline)
            TextEditor(text: $state.systemPrompt)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            Text("Your Prompt")
                .font(.subheadline)
            TextEditor(text: $state.userPrompt)
                .frame(minHeight: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            Toggle("Include clipboard context", isOn: $state.clipboardEnabled)
            HStack(alignment: .top) {
                TextField("Clipboard snippet", text: $state.contextText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
                    .disabled(true)
                #if os(macOS)
                Button("Refresh") { state.refreshClipboard() }
                #endif
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct RecordingControls: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture Controls")
                .font(.headline)
            HStack(spacing: 12) {
                Button(state.recordingMode == .temporaryPrompt ? "Stop Prompt" : "Record Temporary Prompt") {
                    toggle(mode: .temporaryPrompt)
                }
                .disabled(!state.isLoggedIn)
                Button(state.recordingMode == .mainContent ? "Stop Main" : "Record Main Content") {
                    toggle(mode: .mainContent)
                }
                .disabled(!state.isLoggedIn)
            }
            .buttonStyle(.borderedProminent)
            if !state.isLoggedIn {
                Text("Log in to enable capture shortcuts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if state.recordingMode != .idle {
                Text("Listening… press the shortcut again or click stop.")
                    .font(.caption)
            }
            if !state.captureStatus.isEmpty {
                Text(state.captureStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !state.latestPromptText.isEmpty {
                TranscriptionPreview(
                    title: "Last Temporary Prompt",
                    text: state.latestPromptText,
                    copyAction: state.copyLatestPromptToClipboard
                )
            }
            if !state.latestContentText.isEmpty {
                TranscriptionPreview(
                    title: "Last Main Content",
                    text: state.latestContentText,
                    copyAction: state.copyLatestContentToClipboard
                )
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func toggle(mode: RecordingMode) {
        if state.recordingMode == mode {
            state.stopRecording()
        } else {
            state.startRecording(mode)
        }
    }
}

struct SessionList: View {
    @EnvironmentObject private var state: AppState
    private let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Button("New Session") {
                    let session = SessionSummary(
                        id: UUID(),
                        title: "Session \(state.sessions.count + 1)",
                        promptPreview: state.userPrompt,
                        updatedAt: Date(),
                        status: "Recording"
                    )
                    state.sessions.insert(session, at: 0)
                }
            }
            Table(state.sessions) {
                TableColumn("Title", value: \.title)
                TableColumn("Prompt") { session in
                    Text(session.promptPreview.prefix(40) + (session.promptPreview.count > 40 ? "…" : ""))
                }
                TableColumn("Updated") { session in
                    Text(formatter.string(from: session.updatedAt))
                }
                TableColumn("Status", value: \.status)
            }
            .frame(minHeight: 160)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension SessionSummary {
    var titleKey: LocalizedStringKey { LocalizedStringKey(title) }
}

struct RecordingOverlay: View {
    var message: String

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(message)
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                Spacer()
            }
            Spacer()
        }
    }
}

struct TranscriptionPreview: View {
    var title: String
    var text: String
    var copyAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Spacer()
#if os(macOS)
                if let copyAction = copyAction {
                    Button("Copy") { copyAction() }
                        .buttonStyle(.bordered)
                }
#endif
            }
            Text(text)
                .font(.body)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
        }
    }
}

#if os(macOS)
struct ShortcutCaptureField: NSViewRepresentable {
    var title: String
    @Binding var shortcut: RecordingShortcut
    var onChange: (RecordingShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutTextField {
        let field = ShortcutTextField()
        field.placeholderString = "Press shortcut"
        field.onShortcut = { newShortcut in
            shortcut = newShortcut
            onChange(newShortcut)
        }
        field.stringValue = shortcut.displayText
        return field
    }

    func updateNSView(_ nsView: ShortcutTextField, context: Context) {
        nsView.stringValue = shortcut.displayText
    }

    class ShortcutTextField: NSTextField {
        var onShortcut: ((RecordingShortcut) -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            drawsBackground = true
            isBezeled = true
            isEditable = false
            alignment = .center
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            guard let chars = event.charactersIgnoringModifiers, let char = chars.uppercased().first else { return }
            let filtered = event.modifierFlags.intersection([.command, .option, .shift, .control])
            let shortcut = RecordingShortcut(key: String(char), modifiers: filtered)
            stringValue = shortcut.displayText
            onShortcut?(shortcut)
        }
    }
}
#else
struct ShortcutCaptureField: View {
    var title: String
    @Binding var shortcut: RecordingShortcut
    var onChange: (RecordingShortcut) -> Void
    var body: some View {
        TextField(title, text: .constant(""))
    }
}
#endif

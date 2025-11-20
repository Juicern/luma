import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack {
            if !state.microphoneAuthorized {
                PermissionGateView()
            } else {
                MainDashboardView()
            }
        }
        .padding()
        .frame(minWidth: 900, minHeight: 600)
        .sheet(item: $state.promptPreview) { preview in
            PromptPreviewSheet(preview: preview)
                .environmentObject(state)
        }
        .sheet(isPresented: $state.isAddPromptPresented) {
            AddPromptSheet()
                .environmentObject(state)
        }
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
                    PermissionStatusCard()
                    APIKeyCard()
                    ShortcutCard()
                    PromptCard()
                    RecordingControls()
                    TranscriptionHistoryCard()
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

struct PermissionStatusCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Permissions")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
#if os(macOS)
                    state.refreshAccessibilityState()
#endif
                    state.requestMicrophonePermission()
                }
                .buttonStyle(.bordered)
            }
            PermissionStatusRow(
                icon: "mic.fill",
                title: "Microphone",
                description: "Allows Luma to capture your voice.",
                granted: state.microphoneAuthorized,
                actionTitle: state.microphoneAuthorized ? "Open Settings" : "Grant",
                action: {
                    if state.microphoneAuthorized {
                        state.openMicrophoneSettings()
                    } else {
                        state.requestMicrophonePermission()
                    }
                }
            )
#if os(macOS)
            PermissionStatusRow(
                icon: "keyboard.fill",
                title: "Accessibility",
                description: "Required for global shortcuts & auto-paste.",
                granted: state.accessibilityGranted,
                actionTitle: state.accessibilityGranted ? "Open Settings" : "Grant",
                action: {
                    if state.accessibilityGranted {
                        state.openAccessibilitySettings()
                    } else {
                        state.requestAccessibilityPermission()
                    }
                }
            )
#endif
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PermissionStatusRow: View {
    var icon: String
    var title: String
    var description: String
    var granted: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(granted ? "Granted" : "Missing")
                    .font(.caption)
                    .foregroundColor(granted ? .green : .orange)
            }
            Spacer()
            Button(actionTitle, action: action)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
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
            if let models = state.providerModels[state.selectedProvider], !models.isEmpty {
                Picker("Model", selection: $state.selectedModel) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
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
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt Composer")
                .font(.headline)

            Text("Quick Templates")
                .font(.subheadline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(state.defaultPromptTemplates) { template in
                    PromptChip(
                        title: template.name,
                        subtitle: template.description,
                        isActive: false
                    ) {
                        state.presentTemplate(template)
                    }
                }
            }

            Divider()

            HStack {
                Text("Saved Prompts")
                    .font(.subheadline)
                Spacer()
                Button("Refresh") { state.loadPresets() }
                    .disabled(!state.isLoggedIn)
                Button {
                    state.beginAddPrompt()
                } label: {
                    Label("Add Prompt", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!state.isLoggedIn)
            }
            if state.presets.isEmpty {
                Text(state.isLoggedIn ? "No prompts yet. Add one to reuse your favorite instructions." : "Log in to manage prompts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(state.presets) { preset in
                        PromptChip(
                            title: preset.name,
                            subtitle: state.selectedPresetID == preset.id ? "Active" : "Tap to preview",
                            isActive: state.selectedPresetID == preset.id
                        ) {
                            state.presentPreset(preset)
                        }
                    }
                }
            }

            if !state.presetStatus.isEmpty {
                Text(state.presetStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
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
            if !state.pasteStatus.isEmpty {
                Text(state.pasteStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

struct TranscriptionHistoryCard: View {
    @EnvironmentObject private var state: AppState

    private var filteredHistory: [TranscriptionHistoryItem] {
        let query = state.transcriptionSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return state.transcriptionHistory }
        return state.transcriptionHistory.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcription History")
                    .font(.headline)
                Spacer()
                TextField("Search history", text: $state.transcriptionSearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
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
            if filteredHistory.isEmpty {
                Text("No transcriptions captured yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Table(filteredHistory) {
                    TableColumn("When") { entry in
                        Text(entry.timestamp, style: .time)
                            .font(.caption)
                    }
                    TableColumn("Mode") { entry in
                        Text(entry.mode.displayName)
                    }
                    TableColumn("Duration") { entry in
                        Text(entry.durationLabel)
                    }
                    TableColumn("Preview", value: \.preview)
                    TableColumn("Actions") { entry in
                        Button("Copy") { state.copyTextToClipboard(entry.text) }
                    }
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

struct PromptChip: View {
    var title: String
    var subtitle: String?
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive ? Color.green.opacity(0.2) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

struct PromptPreviewSheet: View {
    @EnvironmentObject private var state: AppState
    var preview: PromptPreviewState

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(preview.title)
                    .font(.title2)
                    .bold()
                ScrollView {
                    Text(preview.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Button("Copy") { state.copyTextToClipboard(preview.text) }
                    Spacer()
                    Button("Use Prompt") {
                        state.applyPreview(preview)
                        state.promptPreview = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { state.promptPreview = nil }
                }
            }
        }
    }
}

struct AddPromptSheet: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Prompt name", text: $state.draftPromptName)
                }
                Section("Prompt Text") {
                    TextEditor(text: $state.draftPromptText)
                        .frame(minHeight: 160)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        state.isAddPromptPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { state.submitNewPrompt() }
                        .disabled(state.draftPromptName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  state.draftPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if state.draftPromptText.isEmpty {
                    state.draftPromptText = state.userPrompt
                }
            }
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
            let normalized = RecordingShortcut.normalizeModifiers(event.modifierFlags)
            let shortcut = RecordingShortcut(key: String(char), modifiers: normalized)
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

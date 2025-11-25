import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Group {
            if !state.microphoneAuthorized {
                PermissionGateView()
            } else {
                HStack(spacing: 0) {
                    SidebarView()
                        .frame(width: 240)
                        .background(.ultraThinMaterial)
                    ScrollView {
                        VStack {
                            ContentPanelView()
                                .frame(maxWidth: 1100)
                                .padding(.vertical, 32)
                                .padding(.horizontal, 56)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .frame(minWidth: 1024, minHeight: 640)
        .sheet(item: $state.promptPreview) { preview in
            PromptPreviewSheet(preview: preview)
                .environmentObject(state)
        }
        .sheet(isPresented: $state.isAddPromptPresented) {
            AddPromptSheet()
                .environmentObject(state)
        }
        .sheet(item: $state.selectedHistoryItem) { item in
            HistoryPreviewSheet(item: item)
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

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @State private var hoveredPanel: DashboardPanel?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Luma")
                .font(.largeTitle)
                .bold()
                .padding(.top, 28)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            ForEach(DashboardPanel.allCases) { panel in
                let isActive = state.selectedPanel == panel
                let isHovered = hoveredPanel == panel
                Button {
                    state.selectedPanel = panel
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: panel))
                        Text(panel.rawValue)
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isActive ? Color.accentColor.opacity(0.25) :
                                  (isHovered ? Color.accentColor.opacity(0.12) : .clear))
                    )
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredPanel = hovering ? panel : nil
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private func icon(for panel: DashboardPanel) -> String {
        switch panel {
        case .guide: return "questionmark.circle"
        case .account: return "person.crop.circle"
        case .permissions: return "shield.lefthalf.filled"
        case .prompts: return "text.quote"
        case .history: return "clock.arrow.circlepath"
        case .model: return "server.rack"
        }
    }
}

struct ContentPanelView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            switch state.selectedPanel {
            case .guide:
                UserGuideView()
            case .account:
                UserCard()
            case .permissions:
                VStack(spacing: 24) {
                    PermissionStatusCard()
                    ShortcutCard()
                }
            case .prompts:
                PromptCard()
            case .history:
                TranscriptionHistoryCard()
            case .model:
                APIKeyCard()
            }
        }
    }
}

struct UserGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Use Luma")
                .font(.title2)
                .bold()
            GuideStep(title: "1. Sign In", description: "Create an account or log in so we can store your API keys and personal prompt library.")
            GuideStep(title: "2. Connect an API Key", description: "Paste your OpenAI or Gemini key under Models & Keys. We store it encrypted locally.")
            GuideStep(title: "3. Pick a prompt", description: "Choose a quick template or open your saved prompts to see the detailed instructions before using them.")
            GuideStep(title: "4. Set shortcuts & permissions", description: "Grant microphone + accessibility access, then configure the temporary/main shortcuts from the Permission tab.")
            GuideStep(title: "5. Capture & paste", description: "Use the shortcuts anywhere. Luma transcribes, rewrites, and automatically inserts the text into the active app while keeping a copy in History.")
            GuideStep(title: "6. Review history", description: "If you need an earlier transcription, open History, search, and copy it back.")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct GuideStep: View {
    var title: String
    var description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct UserCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account & Backend")
                .font(.headline)
            Divider()
            if state.isLoggedIn, let user = state.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Signed in as \(user.name)", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.title3)
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Refresh Session") { state.restoreSession() }
                            Button("Log Out") { state.logout() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    Text(user.email)
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("User ID stored locally.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Picker("", selection: $state.isRegistering) {
                    Text("Log In").tag(false)
                    Text("Sign Up").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                VStack(alignment: .leading, spacing: 8) {
                    if state.isRegistering {
                        Text("Create a Luma account to sync presets and API keys.")
                            .font(.subheadline)
                        TextField("Name", text: $state.registrationName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                        TextField("Email", text: $state.registrationEmail)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.next)
                        SecureField("Password", text: $state.registrationPassword)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                        HStack {
                            Button("Create Account") { state.registerUser() }
                                .buttonStyle(.borderedProminent)
                            if !state.registrationStatus.isEmpty {
                                Text(state.registrationStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Sign in with your Luma account to sync presets and API keys.")
                            .font(.subheadline)
                        TextField("Email", text: $state.loginEmail)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.username)
                            .submitLabel(.next)
                        SecureField("Password", text: $state.loginPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .submitLabel(.go)
                        Button("Fill from Keychain") {
                            state.loadCredentialsFromKeychain()
                        }
                        .buttonStyle(.bordered)
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
                .onSubmit {
                    if state.isRegistering {
                        state.registerUser()
                    } else {
                        state.login()
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: 88, alignment: .topLeading)
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
    @State private var editingKind: ShortcutKind?
    @State private var draftShortcut = RecordingShortcut(key: "R", modifiers: [.command, .option])

    enum ShortcutKind: Identifiable {
        case temporary, main
        var id: String {
            switch self {
            case .temporary: return "temporary"
            case .main: return "main"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            Toggle("Allow prompt/content shortcuts to be the same", isOn: $state.allowSharedShortcut)
            HStack(alignment: .top, spacing: 32) {
                ShortcutCaptureField(
                    title: "Temporary Prompt",
                    subtitle: state.temporaryShortcut.descriptiveLabel,
                    shortcutText: state.temporaryShortcut.displayText.isEmpty ? "Click to set shortcut" : state.temporaryShortcut.displayText
                ) {
                    ShortcutManager.shared.pause()
                    draftShortcut = state.temporaryShortcut
                    editingKind = .temporary
                }
                ShortcutCaptureField(
                    title: "Main Content",
                    subtitle: state.mainShortcut.descriptiveLabel,
                    shortcutText: state.mainShortcut.displayText.isEmpty ? "Click to set shortcut" : state.mainShortcut.displayText
                ) {
                    ShortcutManager.shared.pause()
                    draftShortcut = state.mainShortcut
                    editingKind = .main
                }
                Spacer()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(item: $editingKind, onDismiss: {
            ShortcutManager.shared.resume()
        }, content: { kind in
            ShortcutEditSheet(
                title: kind == .temporary ? "Temporary Prompt" : "Main Content",
                shortcut: $draftShortcut,
                onSave: {
                    if kind == .temporary {
                        state.updateShortcut(draftShortcut, forTemporary: true)
                    } else {
                        state.updateShortcut(draftShortcut, forTemporary: false)
                    }
                    editingKind = nil
                },
                onCancel: { editingKind = nil }
            )
            .frame(minWidth: 360)
        })
    }
}

struct PromptCard: View {
    @EnvironmentObject private var state: AppState
    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Prompt Library")
                    .font(.headline)
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

            if state.presets.isEmpty && !state.isLoggedIn {
                Text("Log in to sync and save prompts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(state.defaultPromptTemplates) { template in
                    PromptChip(
                        title: state.templateDisplayName(template),
                        subtitle: template.description,
                        badgeText: "Template",
                        isActive: state.activeTemplateKey == template.key && state.selectedPresetID == nil,
                        primaryAction: { state.activateTemplate(template) },
                        detailAction: { state.presentTemplate(template) },
                        editAction: { state.beginEditTemplate(template) },
                        deleteAction: nil
                    )
                }
                ForEach(state.presets) { preset in
                    PromptChip(
                        title: preset.name,
                        subtitle: state.selectedPresetID == preset.id ? "Active" : "Tap to use",
                        badgeText: nil,
                        isActive: state.selectedPresetID == preset.id,
                        primaryAction: { state.activatePreset(preset) },
                        detailAction: { state.presentPreset(preset) },
                        editAction: { state.beginEditPreset(preset) },
                        deleteAction: { state.deletePreset(preset) }
                    )
                }
            }

            if state.presets.isEmpty && state.isLoggedIn {
                Text("No custom prompts yet. Add one to reuse your favorite instructions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        Text(entry.modeLabel)
                    }
                    TableColumn("Duration") { entry in
                        Text(entry.durationLabel)
                    }
                    TableColumn("Preview") { entry in
                        Button(action: { state.selectedHistoryItem = entry }) {
                            Text(entry.preview)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
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

struct HistoryPreviewSheet: View {
    @EnvironmentObject private var state: AppState
    var item: TranscriptionHistoryItem

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.modeLabel)
                    .font(.title2)
                    .bold()
                Text(item.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                if item.rawText != item.text {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Raw Input")
                            .font(.subheadline)
                            .bold()
                        Text(item.rawText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
                    }
                }
                Spacer()
                HStack {
                    Button("Copy Result") {
                        state.copyTextToClipboard(item.text)
                    }
                    if item.rawText != item.text {
                        Button("Copy Raw") {
                            state.copyTextToClipboard(item.rawText)
                        }
                    }
                    Spacer()
                    Button("Close") {
                        state.selectedHistoryItem = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

struct PromptChip: View {
    var title: String
    var subtitle: String?
    var badgeText: String?
    var isActive: Bool
    var primaryAction: () -> Void
    var detailAction: (() -> Void)?
    var editAction: (() -> Void)?
    var deleteAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                    if let badgeText = badgeText {
                        Text(badgeText.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.2))
                            )
                    }
                    Spacer()
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                if let detailAction = detailAction {
                    Button("Details", action: detailAction)
                        .buttonStyle(.borderless)
                }
                if let editAction = editAction {
                    Button("Customize", action: editAction)
                        .buttonStyle(.borderless)
                }
                if let deleteAction = deleteAction {
                    Button("Delete", role: .destructive, action: deleteAction)
                        .buttonStyle(.borderless)
                }
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? Color.green.opacity(0.25) : Color.primary.opacity(0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            primaryAction()
        }
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
            .navigationTitle(state.editingTemplateKey == nil ? "Add Prompt" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        state.isAddPromptPresented = false
                        state.editingTemplateKey = nil
                        state.editingPresetID = nil
                        state.draftPromptName = ""
                        state.draftPromptText = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { state.submitPromptForm() }
                        .disabled(state.draftPromptName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  state.draftPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if state.editingTemplateKey == nil && state.draftPromptText.isEmpty {
                    state.draftPromptText = state.userPrompt
                }
            }
        }
    }
}

#if os(macOS)
struct ShortcutEditSheet: View {
    var title: String
    @Binding var shortcut: RecordingShortcut
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Press the new keys for \(title).")
                .font(.headline)
            ShortcutRecorderField(shortcut: $shortcut, onChange: { _ in })
                .frame(height: 44)
            Text("Hold the desired modifiers (⌘, ⌥, ⇧, ⌃) with or without a letter/number. A modifier-only combo like Right Option is allowed.")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!shortcut.isValid)
            }
        }
        .padding()
        .frame(width: 320)
        .onSubmit { onSave() }
    }
}

struct ShortcutCaptureField: View {
    var title: String
    var subtitle: String
    var shortcutText: String
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Button(action: onTap) {
                HStack {
                    Text(shortcutText.isEmpty ? "Click to set shortcut" : shortcutText)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.25), lineWidth: 1.2)
                )
            }
            .buttonStyle(.plain)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: RecordingShortcut
    var onChange: (RecordingShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutTextField {
        let field = ShortcutTextField()
        field.placeholderString = "Press new shortcut"
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

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
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

        override func flagsChanged(with event: NSEvent) {
            let normalized = RecordingShortcut.normalizeModifiers(event.modifierFlags)
            // Ignore if no modifiers held
            if normalized.isEmpty {
                return
            }
            let shortcut = RecordingShortcut(key: "", modifiers: normalized)
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

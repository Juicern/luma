import SwiftUI

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
                    APIKeyCard()
                    ShortcutCard()
                    PresetCard()
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
        "2. Pick a preset",
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

struct APIKeyCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider API Key")
                .font(.headline)
            SecureField("sk-...", text: $state.apiKey)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save Key") { state.saveAPIKey() }
                    .buttonStyle(.borderedProminent)
                if !state.apiKeyStatus.isEmpty {
                    Text(state.apiKeyStatus)
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
                ShortcutField(title: "Temporary Prompt", shortcut: $state.temporaryShortcut) { newShortcut in
                    state.updateShortcut(newShortcut, forTemporary: true)
                }
                ShortcutField(title: "Main Content", shortcut: $state.mainShortcut) { newShortcut in
                    state.updateShortcut(newShortcut, forTemporary: false)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ShortcutField: View {
    var title: String
    @Binding var shortcut: RecordingShortcut
    var onCommit: (RecordingShortcut) -> Void

    @State private var editingText: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.subheadline)
            TextField("⌥", text: Binding(
                get: { editingText.isEmpty ? shortcut.description : editingText },
                set: { editingText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                shortcut.description = editingText.isEmpty ? shortcut.description : editingText
                onCommit(shortcut)
                editingText = ""
            }
        }
    }
}

struct PresetCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt Presets")
                .font(.headline)
            Picker("Preset", selection: $state.selectedPreset) {
                ForEach(state.presets) { preset in
                    Text(preset.name).tag(Optional(preset))
                }
            }
            .pickerStyle(.segmented)
            if let preset = state.selectedPreset {
                Text(preset.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Toggle("Include clipboard context", isOn: $state.clipboardEnabled)
            TextField("Optional context snippet", text: $state.contextText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)
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
                Button(state.recordingMode == .mainContent ? "Stop Main" : "Record Main Content") {
                    toggle(mode: .mainContent)
                }
            }
            .buttonStyle(.borderedProminent)
            if state.recordingMode != .idle {
                Text("Listening… press the shortcut again or click stop.")
                    .font(.caption)
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
                    // placeholder session creation
                    let session = SessionSummary(
                        id: UUID(),
                        title: "Session \(state.sessions.count + 1)",
                        presetName: state.selectedPreset?.name ?? "Unknown",
                        updatedAt: Date(),
                        status: "Recording"
                    )
                    state.sessions.insert(session, at: 0)
                }
            }
            Table(state.sessions) {
                TableColumn("Title", value: \ .title)
                TableColumn("Preset", value: \ .presetName)
                TableColumn("Updated") { session in
                    Text(formatter.string(from: session.updatedAt))
                }
                TableColumn("Status", value: \ .status)
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

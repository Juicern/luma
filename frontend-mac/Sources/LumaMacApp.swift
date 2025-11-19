import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct LumaMacApp: App {
    @StateObject private var state = AppState()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .onAppear { state.bootstrap() }
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Record Temporary Prompt (\(state.temporaryShortcut.description))") {
                    state.startRecording(.temporaryPrompt)
                }
                .keyboardShortcut(.init(Character("r")), modifiers: [.command, .option])

                Button("Record Main Content (\(state.mainShortcut.description))") {
                    state.startRecording(.mainContent)
                }
                .keyboardShortcut(.init(Character("m")), modifiers: [.option])
            }
        }
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }
}
#endif

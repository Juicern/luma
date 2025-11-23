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
        WindowGroup("Luma") {
            ContentView()
                .environmentObject(state)
                .onAppear { state.bootstrap() }
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Record Temporary Prompt (\(state.temporaryShortcut.displayText))") {
                    state.startRecording(.temporaryPrompt)
                }
                .keyboardShortcut(state.temporaryShortcut.keyEquivalent, modifiers: state.temporaryShortcut.eventModifiers)

                Button("Record Main Content (\(state.mainShortcut.displayText))") {
                    state.startRecording(.mainContent)
                }
                .keyboardShortcut(state.mainShortcut.keyEquivalent, modifiers: state.mainShortcut.eventModifiers)
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

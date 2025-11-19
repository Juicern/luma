# Luma macOS Frontend

SwiftUI app that records voice input, manages presets, and triggers the backend rewrite pipeline.

## Requirements

- Xcode 15+ or Swift 5.9 toolchain
- macOS 13+
- Backend running locally (default `http://localhost:8080`)

## Run

```bash
cd frontend-mac
swift run LumaMac
```

On first launch you will be prompted for microphone access. Granting it is required to record temporary prompts and main content. After that you can:

1. Paste your provider API key (it will be sent to the backend once wiring is complete).
2. Pick a preset and optionally toggle clipboard context.
3. Configure shortcuts for the temporary prompt vs. main content. You can reuse the same combo if desired.
4. Use the buttons or shortcuts to simulate recording; the UI shows the state change.

> NOTE: Audio capture and backend calls are stubbed for now. The UI/state management, permissions, and shortcut preferences are wired so engineering can plug the remaining pieces in next.

#if os(macOS)
import AppKit

final class RecordingHUD {
    static let shared = RecordingHUD()

    private var panel: NSPanel?
    private var label: NSTextField?
    private var spinner: NSProgressIndicator?

    private init() {}

    func show(message: String) {
        DispatchQueue.main.async {
            self.ensurePanel()
            self.label?.stringValue = message
            self.spinner?.startAnimation(nil)
            if let panel = self.panel {
                self.positionPanel(panel)
                panel.orderFrontRegardless()
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.spinner?.stopAnimation(nil)
            self.panel?.orderOut(nil)
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 120)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let effectView = NSVisualEffectView(frame: contentRect)
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large

        let label = NSTextField(labelWithString: "Listening…")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = NSColor.labelColor
        label.lineBreakMode = .byWordWrapping

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)

        effectView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -20)
        ])

        panel.contentView = effectView
        panel.isMovable = false
        panel.ignoresMouseEvents = true

        self.panel = panel
        self.label = label
        self.spinner = spinner
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        var panelFrame = panel.frame
        panelFrame.origin.x = frame.midX - panelFrame.width / 2
        panelFrame.origin.y = frame.minY + 80
        panel.setFrame(panelFrame, display: true)
    }
}
#endif

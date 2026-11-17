import AppKit

/// A short notice in the middle of the screen with the pointer, like the system volume HUD.
/// It never takes focus or clicks, and fades out by itself.
@MainActor
final class Toast {
    static let shared = Toast()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ title: String, detail: String? = nil, seconds: Double = 3) {
        hideWork?.cancel()
        panel?.orderOut(nil)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        let stack = NSStackView(views: [titleLabel])
        if let detail {
            let detailLabel = NSTextField(labelWithString: detail)
            detailLabel.font = .systemFont(ofSize: 13)
            detailLabel.textColor = .secondaryLabelColor
            stack.addArrangedSubview(detailLabel)
        }
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 22, bottom: 14, right: 22)

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true
        background.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        let size = stack.fittingSize

        let screen =
            NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        let frame = NSRect(
            x: area.midX - size.width / 2, y: area.minY + area.height * 0.2,
            width: size.width, height: size.height)
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        // Above the pointer overlays, on every Space, including full-screen slide shows.
        panel.level = OverlayLevel.notice
        panel.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
        ]
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        self.panel = panel

        let work = DispatchWorkItem { [weak self, weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup(
                {
                    $0.duration = 0.4
                    panel.animator().alphaValue = 0
                },
                completionHandler: {
                    MainActor.assumeIsolated {
                        panel.orderOut(nil)
                        if self?.panel === panel { self?.panel = nil }
                    }
                })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

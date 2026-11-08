import AppKit
import QuartzCore

/// Lightweight, event-driven custom banners. This deliberately does not replace
/// Notification Center history or system Focus integration.
@MainActor
final class CustomNotificationBanner {
    static let shared = CustomNotificationBanner()
    static let settingKey = "tether_custom_notification_banners"

    private var windows: [NSPanel] = []
    private let width: CGFloat = 360
    private let height: CGFloat = 86

    func show(_ item: PhoneNotification) {
        guard let screen = NSScreen.main, let frame = screen.visibleFrame as CGRect? else { return }
        let panel = NSPanel(contentRect: NSRect(x: frame.maxX - width - 18, y: frame.maxY - height - 14,
                                                width: width, height: height),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 17
        effect.layer?.masksToBounds = true

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyDown
        icon.image = item.imageData.flatMap(NSImage.init(data:))
            ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: item.appName)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: item.title.isEmpty ? item.appName : item.title)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString: item.text)
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabelColor
        body.maximumNumberOfLines = 2
        body.translatesAutoresizingMaskIntoConstraints = false

        let text = NSStackView(views: [title, body])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        text.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(text)
        effect.addSubview(icon)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            text.trailingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -12),
            text.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            icon.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            icon.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 38),
            icon.heightAnchor.constraint(equalToConstant: 38)
        ])
        panel.contentView = effect
        windows.append(panel)
        reposition()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        Task { @MainActor [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                Task { @MainActor in
                    guard let self, let panel else { return }
                    panel.orderOut(nil)
                    self.windows.removeAll { $0 === panel }
                    self.reposition()
                }
            })
        }
    }

    private func reposition() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        for (index, panel) in windows.suffix(4).enumerated() {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - width - 18,
                                         y: frame.maxY - height - 14 - CGFloat(index) * (height + 10)))
        }
        for panel in windows.dropLast(4) { panel.orderOut(nil) }
    }
}

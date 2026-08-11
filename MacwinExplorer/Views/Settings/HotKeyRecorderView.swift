import SwiftUI
import AppKit

final class HotKeyRecorderNSView: NSView {
    var displayText: String = "Не задано" { didSet { needsDisplay = true } }
    var isListening = false { didSet { needsDisplay = true } }
    var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isListening = true
    }

    override func keyDown(with event: NSEvent) {
        guard isListening else { return }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.isEmpty else { return }
        onCapture?(event.keyCode, modifiers)
        isListening = false
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        isListening = false
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (isListening ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isListening ? "Нажмите комбинацию…" : displayText
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
}

/// Click, then press a key combo (must include at least one modifier) to
/// capture it — used for the global "open new window" shortcut in Settings.
struct HotKeyRecorderView: NSViewRepresentable {
    var displayText: String
    var onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let view = HotKeyRecorderNSView()
        view.displayText = displayText
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        nsView.displayText = displayText
        nsView.onCapture = onCapture
    }
}

import AppKit

// MARK: - Model

enum Tool {
    case highlighter, arrow, box, text
}

struct Annotation {
    var tool: Tool
    var color: NSColor
    var points: [NSPoint]   // highlighter: whole freehand stroke; others: [start, end]; text: [anchor]
    var text: String = ""
}

// MARK: - Drawing surface

/// Shows the screenshot and lets the user draw on top of it. All annotation
/// geometry is stored in *image* coordinates, so the view can be shown at any
/// size and still export at full resolution.
final class AnnotationView: NSView, NSTextFieldDelegate {
    private let image: NSImage
    private let imageSize: NSSize

    var tool: Tool = .highlighter
    var color: NSColor = .systemRed

    private var annotations: [Annotation] = []
    private var draft: Annotation?
    private var textField: NSTextField?
    private var textAnchor: NSPoint = .zero

    var isEditingText: Bool { textField != nil }

    init(image: NSImage) {
        self.image = image
        self.imageSize = image.size
        super.init(frame: NSRect(origin: .zero, size: imageSize))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat { imageSize.width == 0 ? 1 : bounds.width / imageSize.width }

    private func toImage(_ viewPoint: NSPoint) -> NSPoint {
        NSPoint(x: viewPoint.x / scale, y: viewPoint.y / scale)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        commitText()
        let point = toImage(convert(event.locationInWindow, from: nil))

        if tool == .text {
            beginText(at: point)
            return
        }

        let strokeColor = (tool == .highlighter)
            ? NSColor.systemYellow.withAlphaComponent(0.35)
            : color
        draft = Annotation(tool: tool, color: strokeColor,
                           points: tool == .highlighter ? [point] : [point, point])
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard var current = draft else { return }
        let point = toImage(convert(event.locationInWindow, from: nil))
        if current.tool == .highlighter {
            current.points.append(point)
        } else {
            current.points[1] = point
        }
        draft = current
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { draft = nil; needsDisplay = true }
        guard let current = draft else { return }
        if current.tool == .highlighter {
            if current.points.count > 1 { annotations.append(current) }
        } else {
            let dx = current.points[1].x - current.points[0].x
            let dy = current.points[1].y - current.points[0].y
            if hypot(dx, dy) > 3 { annotations.append(current) }
        }
    }

    // MARK: Text tool

    private func beginText(at point: NSPoint) {
        let field = NSTextField(frame: NSRect(x: point.x * scale,
                                              y: point.y * scale - 14,
                                              width: 240, height: 28))
        field.font = .boldSystemFont(ofSize: 18 * scale)
        field.textColor = color
        field.backgroundColor = NSColor.white.withAlphaComponent(0.75)
        field.drawsBackground = true
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "Type, then press Return"
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
        textAnchor = point
    }

    private func commitText() {
        guard let field = textField else { return }
        let value = field.stringValue
        field.removeFromSuperview()
        textField = nil
        guard !value.isEmpty else { return }
        annotations.append(Annotation(tool: .text, color: color, points: [textAnchor], text: value))
        needsDisplay = true
    }

    func cancelText() {
        textField?.removeFromSuperview()
        textField = nil
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitText()
    }

    // MARK: Editing commands

    func undo() {
        commitText()
        guard !annotations.isEmpty else { NSSound.beep(); return }
        annotations.removeLast()
        needsDisplay = true
    }

    // MARK: Rendering

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        drawContents()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawContents() {
        image.draw(in: NSRect(origin: .zero, size: imageSize),
                   from: NSRect(origin: .zero, size: imageSize),
                   operation: .copy, fraction: 1)
        for annotation in annotations { draw(annotation) }
        if let draft { draw(draft) }
    }

    private func draw(_ annotation: Annotation) {
        switch annotation.tool {
        case .highlighter:
            guard let first = annotation.points.first else { return }
            let path = NSBezierPath()
            path.lineWidth = 16
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: first)
            for point in annotation.points.dropFirst() { path.line(to: point) }
            annotation.color.setStroke()
            path.stroke()

        case .box:
            let path = NSBezierPath(rect: rect(annotation.points[0], annotation.points[1]))
            path.lineWidth = 3
            annotation.color.setStroke()
            path.stroke()

        case .arrow:
            drawArrow(from: annotation.points[0], to: annotation.points[1], color: annotation.color)

        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 18),
                .foregroundColor: annotation.color
            ]
            (annotation.text as NSString).draw(at: annotation.points[0], withAttributes: attributes)
        }
    }

    private func drawArrow(from start: NSPoint, to end: NSPoint, color: NSColor) {
        color.setStroke()
        color.setFill()

        let shaft = NSBezierPath()
        shaft.lineWidth = 4
        shaft.lineCapStyle = .round
        shaft.move(to: start)
        shaft.line(to: end)
        shaft.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 18
        let spread = CGFloat.pi / 7
        let left = NSPoint(x: end.x - headLength * cos(angle - spread),
                           y: end.y - headLength * sin(angle - spread))
        let right = NSPoint(x: end.x - headLength * cos(angle + spread),
                            y: end.y - headLength * sin(angle + spread))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }

    private func rect(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    // MARK: Export

    private func renderRep() -> NSBitmapImageRep? {
        commitText()
        let width = Int(imageSize.width.rounded())
        let height = Int(imageSize.height.rounded())
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }

        rep.size = imageSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: imageSize))
        for annotation in annotations { draw(annotation) }
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    func flattenedImage() -> NSImage {
        guard let rep = renderRep() else { return image }
        let output = NSImage(size: imageSize)
        output.addRepresentation(rep)
        return output
    }

    func pngData() -> Data? {
        renderRep()?.representation(using: .png, properties: [:])
    }

    func tiffData() -> Data? {
        renderRep()?.tiffRepresentation
    }
}

// MARK: - Window

final class EditorWindowController: NSObject, NSWindowDelegate {
    private static var current: EditorWindowController?

    private let window: NSWindow
    private let view: AnnotationView
    private var toolButtons: [(Tool, NSButton)] = []
    private var keyMonitor: Any?

    static func present(with image: NSImage) {
        DispatchQueue.main.async {
            let controller = EditorWindowController(image: image)
            current = controller
            controller.show()
        }
    }

    private init(image: NSImage) {
        view = AnnotationView(image: image)

        let toolbarHeight: CGFloat = 44
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let maxWidth = screen.width * 0.85
        let maxHeight = screen.height * 0.85 - toolbarHeight
        let fit = min(1, min(maxWidth / max(image.size.width, 1),
                             maxHeight / max(image.size.height, 1)))
        let contentWidth = max(image.size.width * fit, 360)
        let contentHeight = image.size.height * fit + toolbarHeight

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
                          styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        super.init()

        window.title = "Draw, then Copy  (\u{2318}C copy · \u{2318}S save · \u{2318}Z undo · Esc cancel)"
        window.delegate = self
        window.level = .floating
        window.isReleasedWhenClosed = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))

        view.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight - toolbarHeight)
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)

        let toolbar = makeToolbar()
        toolbar.frame = NSRect(x: 0, y: contentHeight - toolbarHeight,
                               width: contentWidth, height: toolbarHeight)
        toolbar.autoresizingMask = [.width, .minYMargin]
        container.addSubview(toolbar)

        window.contentView = container
        selectTool(.highlighter)
    }

    private func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window == self.window else { return event }
            if event.keyCode == 53 { // Esc
                if self.view.isEditingText { self.view.cancelText() } else { self.dismiss() }
                return nil
            }
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers {
                case "c": self.copyToClipboard(); return nil
                case "s": self.saveToDesktop(); return nil
                case "z": self.view.undo(); return nil
                default: break
                }
            }
            return event
        }
    }

    // MARK: Toolbar

    private func makeToolbar() -> NSView {
        let bar = NSVisualEffectView()
        bar.material = .titlebar
        bar.blendingMode = .withinWindow

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor)
        ])

        func button(_ symbol: String, _ tip: String, _ action: Selector) -> NSButton {
            let btn = NSButton()
            btn.bezelStyle = .texturedRounded
            btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            btn.imagePosition = .imageOnly
            btn.toolTip = tip
            btn.target = self
            btn.action = action
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            return btn
        }

        let highlighter = button("highlighter", "Highlighter", #selector(pickHighlighter))
        let arrow = button("arrow.up.forward", "Arrow", #selector(pickArrow))
        let box = button("rectangle", "Box", #selector(pickBox))
        let text = button("character.textbox", "Text", #selector(pickText))
        for tool in [highlighter, arrow, box, text] { tool.setButtonType(.pushOnPushOff) }
        toolButtons = [(.highlighter, highlighter), (.arrow, arrow), (.box, box), (.text, text)]

        let undo = button("arrow.uturn.backward", "Undo (\u{2318}Z)", #selector(doUndo))

        let copy = button("doc.on.doc", "Copy to clipboard (\u{2318}C)", #selector(doCopy))
        copy.imagePosition = .imageLeading
        copy.title = " Copy"
        copy.keyEquivalent = "\r"

        let save = button("square.and.arrow.down", "Save to Desktop (\u{2318}S)", #selector(doSave))
        let cancel = button("xmark", "Cancel (Esc)", #selector(doCancel))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        for v in [highlighter, arrow, box, text, undo, spacer, copy, save, cancel] {
            stack.addArrangedSubview(v)
        }
        return bar
    }

    private func selectTool(_ tool: Tool) {
        view.tool = tool
        for (key, btn) in toolButtons { btn.state = (key == tool) ? .on : .off }
    }

    // MARK: Actions

    @objc private func pickHighlighter() { selectTool(.highlighter) }
    @objc private func pickArrow() { selectTool(.arrow) }
    @objc private func pickBox() { selectTool(.box) }
    @objc private func pickText() { selectTool(.text) }
    @objc private func doUndo() { view.undo() }
    @objc private func doCopy() { copyToClipboard() }
    @objc private func doSave() { saveToDesktop() }
    @objc private func doCancel() { dismiss() }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        var wrote = false
        if let png = view.pngData() { pasteboard.setData(png, forType: .png); wrote = true }
        if let tiff = view.tiffData() { pasteboard.setData(tiff, forType: .tiff); wrote = true }
        if wrote { dismiss() } else { NSSound.beep() }
    }

    private func saveToDesktop() {
        guard let png = view.pngData() else { NSSound.beep(); return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent("Screenshot \(formatter.string(from: Date())).png")
        do {
            try png.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            dismiss()
        } catch {
            NSSound.beep()
        }
    }

    private func dismiss() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        EditorWindowController.current = nil
    }
}

import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = GlobalHotKey()
    private let capture = CaptureController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "QuickSnap")
            button.toolTip = "QuickSnap — press \u{2318}\u{21E7}2 for a screenshot"
        }
        buildMenu()

        // Register QuickSnap with the system and show the permission prompt once.
        if !ScreenRecordingPermission.isGranted {
            ScreenRecordingPermission.request()
        }

        // The one shortcut: Cmd + Shift + 2  ->  drag an area  ->  markup bar opens  ->  Copy.
        hotKey.register(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .shift]) { [weak self] in
            self?.capture.captureAreaAndEdit()
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Screenshot   \u{2318}\u{21E7}2",
                     action: #selector(snap), keyEquivalent: "")
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Open QuickSnap at Login",
                                   action: #selector(toggleLogin(_:)), keyEquivalent: "")
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "About QuickSnap", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Quit QuickSnap",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        for item in menu.items where item.action != nil && item.target == nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func snap() { capture.captureAreaAndEdit() }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        LoginItem.toggle()
        sender.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "QuickSnap",
            .init(rawValue: "Copyright"): "MIT License — free to use, copy, and share."
        ])
    }
}

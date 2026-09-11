import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = GlobalHotKey()
    private let capture = CaptureController()
    private var shortcutItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                   accessibilityDescription: "QuickSnap")
        }
        buildMenu()

        // Register QuickSnap with the system and show the permission prompt once.
        if !ScreenRecordingPermission.isGranted {
            ScreenRecordingPermission.request()
        }

        registerHotKey()
    }

    // MARK: - Shortcut

    private struct Combo { let keyCode: UInt32; let modifiers: NSEvent.ModifierFlags; let label: String }

    /// Tried in order. F1 is the preferred one-key trigger; if something else
    /// on the system already owns it (or a later combo), we fall down the list
    /// and tell the user what happened.
    private var comboCandidates: [Combo] {
        [
            Combo(keyCode: UInt32(kVK_F1), modifiers: [], label: "F1"),
            Combo(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .shift], label: "\u{2318}\u{21E7}2"),
            Combo(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .option, .shift],
                 label: "\u{2318}\u{2325}\u{21E7}2"),
        ]
    }

    private func registerHotKey() {
        let action: () -> Void = { [weak self] in self?.capture.captureAreaAndEdit() }
        let candidates = comboCandidates

        for (index, combo) in candidates.enumerated() {
            if hotKey.register(keyCode: combo.keyCode, modifiers: combo.modifiers, action: action) {
                applyShortcutLabel(combo.label)
                if index > 0 {
                    presentConflictAlert(claimedLabel: candidates[0].label, fellBackTo: combo.label)
                }
                return
            }
        }
        applyShortcutLabel(nil)
        presentConflictAlert(claimedLabel: candidates[0].label, fellBackTo: nil)
    }

    private func applyShortcutLabel(_ label: String?) {
        if let label {
            shortcutItem.title = "New Screenshot   \(label)"
            statusItem.button?.toolTip = "QuickSnap — press \(label) for a screenshot"
        } else {
            shortcutItem.title = "New Screenshot"
            statusItem.button?.toolTip = "QuickSnap — use this menu to take a screenshot"
        }
    }

    /// Best-effort guess at who's holding the shortcut hostage, so the alert
    /// can name a suspect instead of just shrugging.
    private func likelyConflictingApp() -> String? {
        let keywords = ["screenify", "screen record", "capture", "snagit", "cleanshot", "shottr"]
        return NSWorkspace.shared.runningApplications
            .compactMap { $0.localizedName }
            .first { name in
                let lower = name.lowercased()
                return keywords.contains { lower.contains($0) }
            }
    }

    private func presentConflictAlert(claimedLabel: String, fellBackTo: String?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "\(claimedLabel) is already taken"

        let suspect = likelyConflictingApp()
        var text = suspect.map {
            "Another running app — most likely \($0) — has already claimed \(claimedLabel) as its own shortcut. Only one app can use a given combo at a time."
        } ?? "Another running app (or macOS itself, if this is a function key) has already claimed \(claimedLabel). Only one app can use a given combo at a time."

        if let fellBackTo {
            text += "\n\nQuickSnap switched to \(fellBackTo) instead — that shortcut works right now. To get \(claimedLabel) back, open the other app's settings, change or turn off its shortcut, then reopen QuickSnap."
        } else {
            text += "\n\nQuickSnap couldn't find a free alternative. Use the menu-bar camera icon to take a screenshot for now, or free up the shortcut and reopen QuickSnap."
        }
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        shortcutItem = NSMenuItem(title: "New Screenshot", action: #selector(snap), keyEquivalent: "")
        menu.addItem(shortcutItem)
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

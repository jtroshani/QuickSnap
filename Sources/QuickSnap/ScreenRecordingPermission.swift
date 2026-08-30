import AppKit
import CoreGraphics

/// macOS won't let *any* app capture the screen until the user grants
/// "Screen & System Audio Recording" permission. These helpers check for it,
/// trigger the system prompt (attributed to QuickSnap itself), and — if it's
/// still missing — walk the user through turning it on.
enum ScreenRecordingPermission {

    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the one-time system prompt. Safe to call on every launch: once the
    /// user has answered, macOS never shows it again.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Called when we tried to capture but don't have permission.
    static func presentSetupAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Let QuickSnap record the screen"
        alert.informativeText = """
        macOS needs your OK before any app can take a screenshot.

        1.  Click “Open Settings & Quit”.
        2.  Open “Screen & System Audio Recording”.
        3.  Turn the switch next to QuickSnap ON.
        4.  Launch QuickSnap again (press ⌘–Space, type QuickSnap) and use ⌘⇧2.

        The change only takes effect after QuickSnap is reopened.
        """
        alert.addButton(withTitle: "Open Settings & Quit")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
}

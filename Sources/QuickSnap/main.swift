import AppKit

// QuickSnap is a menu-bar-only app: no Dock icon, no window.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

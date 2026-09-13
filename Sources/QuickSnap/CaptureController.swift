import AppKit

/// Drives macOS's built-in `/usr/sbin/screencapture` for the region selector,
/// then hands the pixels to the markup editor. Nothing is written to disk unless
/// the user clicks "Save" in the editor.
final class CaptureController {

    /// Drag a box on screen, then the markup bar opens (highlighter / arrow / box /
    /// text / Copy). We capture straight to the clipboard with `-c` — that also
    /// stops macOS from dropping its own thumbnail in the corner — and read the
    /// image back out to edit it.
    func captureAreaAndEdit() {
        NSLog("QuickSnap: captureAreaAndEdit() fired")
        guard ScreenRecordingPermission.isGranted else {
            NSLog("QuickSnap: Screen Recording permission NOT granted — showing setup alert")
            ScreenRecordingPermission.presentSetupAlert()
            return
        }

        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount

        run(["-i", "-c"]) { success in
            NSLog("QuickSnap: screencapture exited success=\(success) changeCount \(changeCountBefore)->\(pasteboard.changeCount)")
            // Esc / cancel leaves the clipboard untouched -> nothing to do.
            guard success, pasteboard.changeCount != changeCountBefore else { return }

            let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
            if let data, let image = NSImage(data: data) {
                NSLog("QuickSnap: presenting editor with captured image")
                EditorWindowController.present(with: image)
            } else if let image = NSImage(pasteboard: pasteboard) {
                NSLog("QuickSnap: presenting editor with pasteboard image (fallback path)")
                EditorWindowController.present(with: image)
            } else {
                NSLog("QuickSnap: clipboard changed but no image could be read from it")
            }
        }
    }

    // MARK: - Private

    private func run(_ arguments: [String], completion: ((Bool) -> Void)? = nil) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = arguments
        task.terminationHandler = { process in
            let ok = process.terminationStatus == 0
            DispatchQueue.main.async { completion?(ok) }
        }
        do {
            try task.run()
        } catch {
            NSLog("QuickSnap: failed to launch /usr/sbin/screencapture: \(error)")
            NSSound.beep()
            DispatchQueue.main.async { completion?(false) }
        }
    }
}

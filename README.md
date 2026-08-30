# QuickSnap

A tiny macOS menu-bar app for grabbing a screenshot, marking it up, and copying it:

> **Press `⌘ + ⇧ + 2` → drag a box → a markup bar pops up → click _Copy_.**
> Then `⌘ + V` to paste it into Slack, Mail, Notes, a doc — wherever.

**Nothing is ever saved to your Desktop** unless you click **Save** yourself.
No windows to manage, nothing to configure.

---

## Why this exists

macOS already has a built-in version of this (`⌘ ⇧ ⌃ 4`), but:

- the built-in shortcut is a four-finger stretch nobody remembers;
- there's no icon anywhere to remind you it exists;
- the plain shortcut dumps a file on your Desktop, and there's no quick way to
  scribble a highlight or an arrow before you share it.

QuickSnap gives you an easy shortcut, an always-visible menu-bar icon, and a
small markup bar (highlighter / arrow / box / text) with a big **Copy** button.
The part where you drag the selection box is Apple's own tool, so it's exactly
as reliable as the system feature.

## How to use it (the entire manual)

1. Press **`⌘ ⇧ 2`** (or click the menu-bar camera → **New Screenshot**).
2. **Drag a box** around what you want. To grab a whole window, press **Space**
   first, then click the window.
3. A little editor window opens with your shot. Optionally draw on it:

   | Button | Does |
   |---|---|
   | **Highlighter** | drag a translucent yellow stroke |
   | **Arrow** | drag from tail to head |
   | **Box** | drag a rectangle outline |
   | **Text** | click, type, press Return |
   | **Undo** (`⌘Z`) | remove the last mark |

4. Click **Copy** (or press `⌘C` / Return). The window closes and the image —
   with your markup baked in — is on the clipboard. Paste anywhere with `⌘V`.
   - Prefer a file? Click **Save** (`⌘S`) instead — it writes one PNG to the
     Desktop and shows it in Finder.
   - Changed your mind? Click the **✕** or press **Esc** — nothing is saved.

The menu-bar camera icon also has **Open QuickSnap at Login** and **Quit**.

## Install (for people downloading it)

1. Download `QuickSnap.zip` from the [Releases](../../releases) page and unzip it.
2. Drag **QuickSnap.app** into your **Applications** folder.
3. **Right-click** the app → **Open** → **Open** again.
   (You only do this once. It's because the app isn't signed with a paid Apple
   developer certificate — see note below.)
4. The first time you take a shot, macOS asks for **Screen Recording**
   permission. Click **Open System Settings**, switch QuickSnap **on**, and
   quit/reopen the app. (macOS requires this of every screenshot tool.)

That's it — look for the camera icon near your clock.

## Build & run it yourself

You need the Xcode Command Line Tools (`xcode-select --install`), nothing else.

```bash
git clone https://github.com/<you>/QuickSnap.git
cd QuickSnap
./install.sh        # builds, installs to /Applications, fixes permissions
```

`./build.sh` on its own just compiles and makes `QuickSnap.app` in the current
folder — fine for a quick look, but **use `./install.sh`** if you want the
Screen Recording permission to stick (see next section for why).

## Troubleshooting: "it keeps sending me to System Settings"

If taking a screenshot repeatedly bounces you to
**Privacy & Security ▸ Screen & System Audio Recording** even though QuickSnap
is already switched on there, the permission grant isn't sticking. Two causes:

| Cause | Fix |
|---|---|
| **App is in an iCloud-synced folder** (`~/Desktop`, `~/Documents`). macOS can't keep a stable identity for it. | Run it from **`/Applications`**. |
| **Ad-hoc signature changes on every build**, so macOS sees each build as a new app. | Sign with one **stable identity**. |

`./install.sh` does both automatically: it creates a one-off self-signed signing
certificate (`QuickSnap Local Signing` in your login keychain), builds and signs
with it, copies the app to `/Applications`, and runs
`tccutil reset ScreenCapture com.github.quicksnap` to clear the stale records.
After it finishes:

1. Grant permission in the pane it opens.
2. Quit QuickSnap and reopen it (**required** — macOS only applies the change on relaunch).
3. Delete the old copy from your Desktop.

To undo: delete `/Applications/QuickSnap.app` and remove the
`QuickSnap Local Signing` certificate in **Keychain Access**.

## Publishing a release on GitHub

- **Manual:** run `./build.sh`, then
  `ditto -c -k --keepParent QuickSnap.app QuickSnap.zip`, and upload the zip to
  a new GitHub Release.
- **Automatic:** push a tag like `v1.0.0`. The included workflow
  (`.github/workflows/release.yml`) builds the app on GitHub's macOS runners and
  attaches `QuickSnap.zip` to the release for you.

The download page links to `releases/latest/download/QuickSnap.zip`, so as long
as every release keeps that asset name, the **Download for Mac** button always
points at the newest build.

## The download page (`docs/`)

`docs/index.html` is a self-contained landing page — logo, the three-step
explainer, install notes, download buttons. To put it online:

1. Open `docs/index.html` and set one line near the bottom:
   `const REPO = "your-username/QuickSnap";`
2. Commit and push.
3. On GitHub: **Settings ▸ Pages ▸ Source → Deploy from a branch**, branch
   `main`, folder `/docs`. (Or leave `.github/workflows/pages.yml` to deploy it
   for you — then set Source to **GitHub Actions**.)
4. Your page is live at `https://your-username.github.io/QuickSnap/`. That's the
   link you share.

Until `REPO` is set, the page shows a small reminder strip and the download
buttons fall back to the repo homepage.

### About code signing

This project ships **unsigned** (ad-hoc signed), which is why downloaders need
the one-time right-click-Open step. If you join the Apple Developer Program
($99/yr) you can `codesign` with a *Developer ID* certificate and *notarize* the
zip, and then it opens with a normal double-click. Not required for a hobby
project — plenty of popular tools ship exactly like this.

## What's under the hood

| File | Job |
|---|---|
| `Sources/QuickSnap/main.swift` | Boots a menu-bar-only app (no Dock icon). |
| `AppDelegate.swift` | Builds the menu, wires up the shortcut. |
| `GlobalHotKey.swift` | Registers `⌘ ⇧ 2` system-wide (Carbon `RegisterEventHotKey` — no Accessibility permission needed). |
| `CaptureController.swift` | Runs `/usr/sbin/screencapture -i -c`, then reads the image back off the clipboard. `-c` also suppresses macOS's own corner thumbnail. |
| `Editor.swift` | The markup window: `AnnotationView` (draw + flatten to a full-res PNG) and `EditorWindowController` (toolbar, Copy / Save / Undo). |
| `LoginItem.swift` | The "Open at Login" toggle via `SMAppService`. |

Want a different shortcut? Change the `keyCode` / `modifiers` in
`AppDelegate.swift` and rebuild. (A proper in-app shortcut picker is the
obvious next feature.)

## License

MIT — do whatever you like with it.

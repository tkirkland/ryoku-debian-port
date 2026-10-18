# 09a: Shell QML front end (Quickshell)

**Scope.** The Quickshell QML front end of the Ryoku desktop shell at the pinned commit `98a03682`:
everything under `ryoku/shell/quickshell/` (the `shell` config with `modules/`, `services/`,
`components/`, `utils/`, `barkit/`, `assets/`; plus `ryoshot`, `ryopin`, `welcome`, `keys`,
`keys-hint`, `reload-cover`, `plugins/` with `kit/`), and also `ryoku/shell/matugen/`,
`ryoku/shell/qt6ct/`, `ryoku/shell/systemd/`, `ryoku/shell/environment.d/`, `ryoku/shell/deploy.sh`,
`dev-run.sh`, `dev-stop.sh`, the shell docs (`docs/ui-ux.md`, `bar.md`, `barstyles.md`, `frame.md`,
`launcher.md`, `plugins.md`, `stage.md`, `theming.md`) and `release/packages/ryoku-shell/PKGBUILD`.
The QML tree is 942 files: 552 `.qml`, 54 `.js`, 40 `.mjs` (node unit tests), 42 `.qsb` and 41 `.frag`.
The Go daemon (`ryoku/shell/ipc`), the C++ plugin (`Ryoku.Blobs`), ryogami, ryomotion, ryotunes,
`ryoku/shell/scripts/` and `ryoku/ui` (Ryoku.Ui) belong to other reports. They appear here only as
dependencies. Debian versions come from `tools/pkgver`, given as trixie / trixie-bpo / forky / sid /
resolute. `-` means the package is not in that suite.

## Summary

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| Quickshell runtime | `quickshell` (Arch extra) | trixie: NO; trixie-bpo: PARTIAL (0.3.0, built on Qt 6.8); forky/sid: YES (0.3.2); resolute: NO (not packaged) | Medium | Needs ≥0.3.0 because `//@ pragma DefaultEnv` is used (`shell/shell.qml:7-9`). Arch had 0.3.1 at the pin date. It links Qt private API, so it must be rebuilt with every Qt bump. |
| Qt 6 / QML modules | 30 import names across 552 files | trixie: NO (Qt 6.8.2); resolute: PARTIAL (Qt 6.10.2); forky/sid: YES (Qt 6.11.2) | trixie High / resolute Medium / forky Low | `RectangularShadow` needs Qt 6.9 (17 sites, among them the default bar `qsbar/BarSlot.qml:179`). Its per-corner radii need Qt 6.11, and they are in the default `hero` launcher (`hero/LauncherSurface.qml:466-469`). |
| Ryoku QML modules + import path | `/usr/lib/qt6/qml/Ryoku/{Ui,FrameBars,PluginKit,Wm/Hyprland,Blobs}` | NO | Low | Debian's Qt QML dir is `/usr/lib/x86_64-linux-gnu/qt6/qml`. `/usr/lib/qt6/qml` is not on its default import path. |
| External commands run by the QML | ~110 tools, `Process`/`execDetached`/`Spawn.run` | PARTIAL | Medium | `fd` is `fdfind` on Debian. `rfkill` and `iw` live in `/usr/sbin`, which the session PATH leaves out. Arch-only items: `/var/log/pacman.log`, `gpk --manager pacman,aur`, `omarchy`. Not packaged: `waifu2x-ncnn-vulkan`, `nvibrant`, `voxtype`. |
| Shaders (`.qsb`) | 42 files | YES | Low | The committed `.qsb` files are QSB format v9, which Qt 6.8, 6.10 and 6.11 all read. `logo-tint.frag.qsb` has no `.frag` source in the repo. |
| matugen | `ryoku/shell/matugen/` | NO (not packaged anywhere) | Medium | Needs matugen ≥4.1.0 (`--prefer`). Arch ships 4.2.0. Building 4.2.0 needs rustc ≥1.88, and trixie has 1.85 (trixie-bpo has 1.96). |
| qt6ct / fonts / icons / cursor | `qt6ct.conf`, `Tokens.qml`, Theme singletons | PARTIAL | Medium | Not in Debian: Material Symbols Rounded (variable), every Nerd Font, Space Grotesk (Debian), Fraunces. `SpaceMono Nerd Font` is the default mono font, but no Ryoku package ships it, on Arch either. |
| systemd user units / environment.d | `ryoku/shell/systemd/`, `environment.d/` | PARTIAL | Low | `PATH=` in `ryoku-session.conf:16` drops `/usr/sbin` (see commands row). `QML_IMPORT_PATH` holds only `~/.local/lib/qt6/qml`. |
| deploy.sh / dev-run.sh / dev-stop.sh | `ryoku/shell/` | PARTIAL | Low | Uses `pacman -Q`, `pacman -S`, `pacman-key` and `[ryoku]` repo edits. These calls are skipped when pacman is absent, but the Qt-stamp logic depends on them. |
| Compositor naming in QML (rule 2) | `components/CustomShortcut.qml`, `FocusGrab.qml` | n/a | Low | Both name `Ryoku.Wm.Hyprland` by string. No `Quickshell.Hyprland` import exists in the shell tree. |

---

### Quickshell runtime (`quickshell`, Arch `extra/quickshell`)

**What it does:** Quickshell is the QML host process (`qs`) that runs every Ryoku surface. The Go daemon
launches each surface with `qs -c <name>` (installed config) or `qs -p <dir>` (checkout)
(`ryoku/shell/ipc/actions.go:51-53`). Configs live under `~/.config/quickshell/{shell,ryoshot,ryopin,welcome,keys,keys-hint,hub,...}`,
copied there from `/usr/share/ryoku/config/quickshell` (`release/packages/ryoku-desktop/PKGBUILD:272-275`).
`reload-cover` ships separately in `ryoku-shell` (`release/packages/ryoku-shell/PKGBUILD:61-62`).

**Arch couplings:**
- Arch provides it from the official `extra` repo, not the AUR: `quickshell` is in `system/packages/base.packages:258`,
  `ryoku-desktop` depends on it (`PKGBUILD:87`), and so do `ryoku-shell` (`PKGBUILD:18`) and `ryogami` (`PKGBUILD:29`).
  Arch version history (gitlab tags): 0.3.0-1 (2026-05-11), **0.3.1-1 (2026-08-21; current on the pin date 2026-09-26)**,
  0.3.2-1 (2026-10-08). `quickshell-git` from the AUR is explicitly discouraged. It satisfies the dependency
  through `provides` but is not rebuilt on Qt updates (`ryoku/cli/internal/doctor/reconcile_quickshell.go:3-6`,
  `ryoku/shell/deploy.sh:107-123`).
- `ryoku doctor` repairs the runtime with `sudo pacman -S quickshell` (`reconcile_quickshell.go:27,40,75`) and
  checks Qt at `/usr/lib/libQt6Core.so.6` (`reconcile_quickshell.go:20`). Debian's path is
  `/usr/lib/x86_64-linux-gnu/libQt6Core.so.6`. This code is outside this report's scope; it is listed under cross-cutting findings.

**Quickshell modules and types Ryoku uses** (file counts are files with that `import`):

| Module | Files | Types / APIs used (example cite) | Min Quickshell |
|---|---|---|---|
| `Quickshell` | 253 | `ShellRoot`, `PanelWindow`, `FloatingWindow`, `Variants`, `Scope`, `LazyLoader`, `Singleton`, `SystemClock`, `PersistentProperties`, `ColorQuantizer` (4 files), `ScriptModel` (2), `DesktopEntries` (15), `Quickshell.execDetached` (26 files) incl. the object form `{command, environment}` (`ryoku/ui/Singletons/Spawn.qml:42`), `Quickshell.env` (87), `Quickshell.screens`, `Quickshell.clipboardText`, `Region` with per-corner radius (`shell/modules/launcher/variants/hero/LauncherSurface.qml:402`) | **0.3.0** (per-corner `Region` radius) |
| `Quickshell.Io` | 141 | `Process` (209), `StdioCollector`, `SplitParser`, `FileView` (108), `JsonAdapter` (29), `Socket` (33; daemon socket `$XDG_RUNTIME_DIR/ryoku-shell.sock`, `shell/services/Polkit.qml:27`), `IpcHandler` (11) | 0.2.x |
| `Quickshell.Wayland` | 67 | `WlrLayershell`/`WlrLayer`/`WlrKeyboardFocus`/`ExclusionMode` (≈60), `ScreencopyView` (7; ryoshot `Overlay.qml`), `IdleInhibitor` (`shell/shell.qml:645`, `qsbar/BarSlot.qml:120`) | **0.3.0** (`IdleInhibitor`) |
| `Quickshell.Widgets` | 23 | `ClippingRectangle` (18), `IconImage` (6) | 0.2.x |
| `Quickshell.Services.Mpris` | 14 | `Mpris.players` | 0.2.x |
| `Quickshell.Bluetooth` | 13 | `Bluetooth.defaultAdapter`, `BluetoothDevice` | 0.2.x |
| `Quickshell.Services.Pipewire` | 5 | `Pipewire`, `PwObjectTracker`, `PwNodePeakMonitor` (`shell/components/HFader.qml:40`, `qsbar/panels/MicrophonePeakMonitor.qml:13`) | **0.3.0** (`PwNodePeakMonitor`) |
| `Quickshell.Services.UPower` | 4 | `UPower.displayDevice` (`shell/services/Battery.qml`) | 0.2.x |
| `Quickshell.Services.Notifications` | 2 | `NotificationServer` (`shell/services/Notifs.qml`, `qsbar/panels/NotificationPanel.qml`) | 0.2.x |
| `Quickshell.Networking` | 1 | `Networking`, `NetworkBackendType` (`qsbar/panels/NetworkManagerAdapter.qml:2,12`) | **0.3.0** (network module added) |
| `Quickshell.Hyprland` | 0 in this tree | Used only in `ryoku/wm/hyprland/qml/{GlobalShortcutBridge,FocusGrabBridge}.qml:1`, loaded by name from the shell (see Rule 2 section) | 0.2.x |
| Not used: `Quickshell.Services.SystemTray` (the tray goes through the daemon, `shell/services/Tray.qml:33`), `Quickshell.Services.Polkit` (the daemon is the agent, `shell/services/Polkit.qml:7-10`), `Quickshell.Services.Greetd`, `Quickshell.Services.Pam`, `WlSessionLock`, `ToplevelManager`, `I3` | | | |

**Pragmas** (all `//@ pragma` lines):
- `UseQApplication`: `shell/shell.qml:1`, `shell/modules/launcher/Launcher.qml:1`, `launcher/variants/{okshell,hero,main}/Main.qml:1`, `kairos/Main.qml:11`.
- `DefaultEnv QSG_RENDER_LOOP=threaded|basic`: `shell/shell.qml:7`, `ryopin/shell.qml:1`, `ryoshot/shell.qml:1`, `modules/visualizer/Visualizer.qml:1`, `launcher/variants/main/Main.qml:2`.
- `DefaultEnv QS_DROP_EXPENSIVE_FONTS=1` (`shell/shell.qml:8`) and `DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000` (`shell/shell.qml:9`).

`DefaultEnv` and `QS_DROP_EXPENSIVE_FONTS` arrived in Quickshell 0.3.0 (upstream `changelog/v0.3.0.md`).
Before 0.3.0, "Unrecognized pragmas are … a hard error" (same file). So on any Quickshell older than 0.3.0 the main
`shell/shell.qml` does not load at all.

**Minimum version, derived from the code:** **Quickshell 0.3.0.** Its features in use are `DefaultEnv`, `IdleInhibitor`,
`PwNodePeakMonitor`, `Quickshell.Networking` and per-corner `Region` radius. No API added after 0.3.0 is used.
Upstream `git log v0.3.0..v0.3.2` contains only fixes plus "networking: add NetworkManager service watcher" and
"hyprland/ipc: support workspace addresses". Ryoku does not use Hyprland IPC from QML.
**Version to ship for parity: ≥0.3.1.** Arch ran 0.3.1 on the pin date. 0.3.1 fixes crashes in APIs Ryoku uses
heavily: `FileView` updating watched files (108 FileViews), `JsonAdapter` array deserialize (29), `ScriptModel`,
`ColorQuantizer` deletion, `PwNodePeakMonitor` channel mismatch, and the wifi network disappearing in `Networking`
(upstream `changelog/v0.3.1.md`). 0.3.2 adds Qt 6.12 support (`changelog/v0.3.2.md`); Arch moved to Qt 6.12.0 on 2026-10-01.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| quickshell 0.3.1-1 (pin) | the whole shell (`ryoku-desktop/PKGBUILD:87`) | quickshell | - | 0.3.0-1~bpo13+1 | 0.3.2-1 | 0.3.2-1 | - | 0.3.0 (`//@ pragma DefaultEnv`, `shell/shell.qml:7`); 0.3.1 for crash-fix parity; 0.3.2 if Qt ≥6.12 |
| cpptrace (quickshell dep) | crash handler (`CRASH_HANDLER` ON default) | libcpptrace-dev (build) | - | 1.0.4-2~bpo13+1 | 1.0.4-2 | 1.0.4-2 | - | any; resolute: build cpptrace or `-DCRASH_HANDLER=OFF` |
| (build) | quickshell build | qt6-base-private-dev / qt6-declarative-private-dev / qt6-wayland-private-dev | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | Qt ≥6.6 for quickshell itself (`CMakeLists.txt:6 QT_MIN_VERSION 6.6.0`); Qt ≥6.11 for Ryoku's QML (next section) |
| (build) | quickshell build | wayland-protocols | 1.44 | 1.47 | 1.49 | 1.49 | 1.47 | ≥1.41 (Debian `debian/control`) |
| (build) | quickshell build | libcli11-dev | 2.4.1 | - | 2.6.1 | 2.6.1 | 2.6.1 | any |
| (build) | quickshell build | libpipewire-0.3-dev, libpolkit-agent-1-dev, libjemalloc-dev, spirv-tools, qt6-shadertools-dev, libvulkan-dev, libgbm-dev, libdrm-dev, libpam0g-dev, libglib2.0-dev, libxcb1-dev, libegl-dev, libgles-dev | present in all suites | | | | | | |

**As-is on Debian:** forky/sid YES (0.3.2 against Qt 6.11.2). trixie-bpo is PARTIAL: 0.3.0 runs, but it is built
against Qt 6.8.2, which is too old for Ryoku's QML (next section), and it lacks the 0.3.1 crash fixes. trixie and resolute: NO.

**Port steps:**
1. forky/sid: install `quickshell` (0.3.2). Debian's build already enables every backend Ryoku needs. Upstream
   `boption` defaults are all ON (`CMakeLists.txt:56-83`), and `debian/rules` only sets
   `-DINSTALL_QML_PREFIX=lib/$(DEB_HOST_MULTIARCH)/qt6/qml -DNO_PCH=ON -DDISTRIBUTOR=Debian`. The package ships
   `/usr/bin/qs`, `/usr/bin/quickshell` and every module directory Ryoku imports (sid file list), including `Quickshell/Hyprland`
   and `Quickshell/Networking`.
2. trixie (only together with a Qt ≥6.11 backport; see the Qt section): rebuild Debian's `quickshell_0.3.2-1.dsc`
   against the backported Qt:
   `dget https://deb.debian.org/debian/pool/main/q/quickshell/quickshell_0.3.2-1.dsc && cd quickshell-0.3.2 && dch --bpo && sbuild -d trixie-backports --extra-repository='<qt6.11 backport repo>'`.
   `libcpptrace-dev` is already in trixie-backports.
3. resolute: Qt 6.10.2 is below 6.11 (next section). Rebuild the same Debian source against a Qt ≥6.11. Resolute lacks
   `libcpptrace-dev`, so either backport `cpptrace_1.0.4-2` from forky first or add `-DCRASH_HANDLER=OFF` to
   `override_dh_auto_configure`. `ryoku/ui/Singletons/Spawn.qml:23-29` only unsets the crash env vars, so it does not care which.
4. Pin the runtime to the Qt it was built with. Debian expresses this through the `qtbase-abi-6-x-y` virtual that the
   private-dev symbols generate. Every Qt minor bump in the target archive requires a quickshell rebuild. That is
   the same constraint `reconcile_quickshell.go:3-6` documents for Arch.

**Complexity:** Medium. Packaging is a no-op on forky/sid; on trixie and resolute it is a rebuild that is tied to the Qt decision.

**Issues / risks:**
- The trixie-bpo quickshell 0.3.0 is not usable as-is, because the QML it would run needs Qt ≥6.9/6.11 and it is built against 6.8.2.
- Debian forky/sid will move to Qt 6.12. Arch did so on 2026-10-01. Quickshell 0.3.1 does not support Qt 6.12; 0.3.2 does (`changelog/v0.3.2.md`).
- `ryoku doctor` hardcodes `pacman` and `/usr/lib/libQt6Core.so.6` to detect and repair a Qt-skewed quickshell (`reconcile_quickshell.go:20,27,75`).

---

### Qt 6 and QML modules (every `import` in the QML tree)

**What it does:** The QML imports the following modules. Counts are files with that import. No import carries a
version number (`import X N.M` is absent in all 552 files).

| Import | Files | Example | Debian package |
|---|---|---|---|
| `QtQuick` | 547 | everywhere | qml6-module-qtquick (+ qml6-module-qtqml, qml6-module-qtqml-workerscript, qml6-module-qtquick-window pulled in) |
| `QtQuick.Effects` | 34 | `MultiEffect` (22 files), `RectangularShadow` (13 files, 17 sites) | qml6-module-qtquick-effects |
| `QtQuick.Shapes` | 27 | `Shape`, `ShapePath`, `PathArc/PathAngleArc/PathQuad/PathCubic/PathSvg/PathPolyline/PathRectangle`, `preferredRendererType: Shape.CurveRenderer` (24 files) | qml6-module-qtquick-shapes |
| `QtQuick.Layouts` | 10 | `RowLayout`, `ColumnLayout`, `GridLayout` | qml6-module-qtquick-layouts |
| `QtQuick.Controls` | 7 | `TextField`, `TextArea`, `ScrollView`, `ScrollBar` (`shell/modules/bar/PolkitSurface.qml`, `KeyringSurface.qml`, `panel/PanelChat.qml`, `components/Calendar.qml`, `launcher/variants/main/SearchRow.qml`, `plugins/kit/SearchField.qml`, `ryoshot/Beautify.qml`) | qml6-module-qtquick-controls (+ qml6-module-qtquick-templates; Fusion style is in the same package) |
| `QtQuick.Dialogs` | 2 | `FileDialog` (`shell/modules/desktop/PluginWidgetMenu.qml`, `bar/framebars/menus/quicksettings/QuickSettingsStage.qml`) | qml6-module-qtquick-dialogs |
| `Qt5Compat.GraphicalEffects` | 7 | `ColorOverlay`, `OpacityMask`, `FastBlur`, `LinearGradient` | qml6-module-qt5compat-graphicaleffects |
| `QtMultimedia` | 4 | `MediaPlayer`, `VideoOutput`, `AudioOutput` (`reload-cover/ReloadVideo.qml:13`, `modules/desktop/music/MusicBackdrop.qml:41`, `modules/wallpaper/Backdrop.qml`, `bar/framebars/menus/WallVideo.qml:15`) | qml6-module-qtmultimedia + libqt6multimedia6 (ships the ffmpeg backend `plugins/multimedia/libffmpegmediaplugin.so`; Debian builds no gstreamer backend) |
| `Qt.labs.folderlistmodel` | 4 | `FolderListModel` | qml6-module-qt-labs-folderlistmodel |
| `QtQml.Models` | 1 | | qml6-module-qtqml-models |
| `org.kde.syntaxhighlighting` | 1 | `SyntaxHighlighter` (`shell/components/CodeHighlight.qml`) | qml6-module-org-kde-syntaxhighlighting (Arch: `syntax-highlighting`, `ryoku-desktop/PKGBUILD:90`) |
| `Quickshell*` | see previous section | | quickshell |
| `Ryoku.Ui` / `Ryoku.Ui.Singletons` | 34 / 276 | design system (`ryoku/ui`) | Ryoku's own package (next section) |
| `Ryoku.FrameBars` | 7 | `ryoku/shell/framebars` | Ryoku's own |
| `Ryoku.PluginKit` / `.Singletons` | 4 / 1 | `ryoku/shell/quickshell/plugins/kit` | Ryoku's own |
| `Ryoku.Blobs` | 3 | C++ plugin (`Frame.qml`, `Popout.qml`, `Osd.qml`) | Ryoku's own (other report) |
| `shell.services` / `shell.barkit` | 224 / 14 | local modules resolved by putting `~/.config/quickshell` first on `QML2_IMPORT_PATH` (`ryoku/shell/ipc/daemon.go:403-421`) | none |
| `node:assert`, `node:test` | 40 `.mjs` | unit tests only (`docs/launcher.md:105`) | nodejs (dev only) |

Runtime plugins with no QML import: SVG decode for every icon (`shell/services/Icons.qml:7-14` loads plain file:// SVGs)
→ qt6-svg-plugins. WebP/AVIF previews → qt6-image-formats-plugins (`ryoku-desktop/PKGBUILD:44-49`). Wayland QPA →
libqt6waylandclient6 (sid ships `plugins/platforms/libqwayland.so` there) / qt6-wayland. `QT_QPA_PLATFORMTHEME=qt6ct`
(`ryoku/shell/environment.d/ryoku-session.conf:20`) → qt6ct.

**Arch couplings:** Arch ships the matching packages `qt6-declarative`, `qt6-5compat`, `qt6-svg`, `qt6-multimedia`, `qt6-multimedia-ffmpeg`,
`qt6-imageformats`, `qt6-wayland` and `syntax-highlighting` (`system/packages/base.packages:98-100,130-134`; `ryoku-desktop/PKGBUILD:40-49,90,142-143`).
Arch extra had qt6-base **6.11.2** on the pin date (6.11.2-1 2026-08-18; 6.12.0-1 landed 2026-10-01).

**Minimum Qt, derived from the code** (each API checked against qtdeclarative sources, `\since` tags at v6.11.0):

| API | Since | Where | Effect if missing |
|---|---|---|---|
| `QtQuick.Effects` `MultiEffect` | 6.5 | 22 files | n/a on all targets |
| `Shape.CurveRenderer`, `font.features` | 6.6 | `reload-cover/ReloadCover.qml:92`, `plugins/kit/GlyphIcon.qml:98`; `plugins/kit/SearchField.qml:76` (16 files) | n/a |
| `font.variableAxes` | 6.7 | `shell/components/MaterialIcon.qml:11` (every Material icon), `qsbar/modules/IconText.qml:11` | n/a |
| `Rectangle.topLeftRadius` etc. | 6.7 | `shell/modules/bar/popouts/Popout.qml:284` | n/a |
| `PathRectangle`, `Image.retainWhileLoading` | 6.8 | `reload-cover/ReloadCover.qml:98`, `ryoshot/AnnLayer.qml:357`, `ryoshot/LensShape.qml:47`; `qsbar/panels/ImageCarouselCarousel.qml:649` | n/a |
| **`RectangularShadow`** | **6.9** (`src/effects/qquickrectangularshadow.cpp` absent at v6.8.2, present at v6.9.0) | 17 sites in 13 files: `qsbar/BarSlot.qml:179,2111`, `qsbar/modules/PillShadow.qml:6` (used by 21 files), `dock/DockBackdrop.qml:47`, `dock/DockItem.qml:123`, `dock/DockItemChrome.qml:148,197`, `dock/DockMedia.qml:52`, `clipboard/ClipboardSurface.qml:477,490`, `launcher/variants/hero/LauncherSurface.qml:459`, `launcher/variants/kairos/{Main.qml:178,Preview.qml:44}`, `bar/barstyles/kairos/components/{Island.qml:425,435,MusicSurface.qml:166}`, `kairos/settings/SettingsWindow.qml:71` | On Qt 6.8 these components fail to compile. The default bar style `qsbar` (`docs/barstyles.md:4`), the dock, the clipboard surface and the `kairos` bar style all fail. Only the `sumi` bar style has no RectangularShadow. |
| **`RectangularShadow.topLeftRadius/topRightRadius/bottomLeftRadius/bottomRightRadius`** | **6.11** (absent in v6.10.2 `qquickrectangularshadow_p.h`, present at v6.11.0) | `shell/modules/launcher/variants/hero/LauncherSurface.qml:466-469`. `hero` is the default launcher (`launcher/shared/Singletons/LauncherConfig.qml:34`, `launcher/catalog.json` `"default": "hero"`) | On Qt 6.10 the hero variant fails to load. `Launcher.qml:111-117` then falls back to `okshell` (`catalog.json` `"fallback": "okshell"`), which looks different. |

No other Qt 6.9-6.11 QML API from that list is used (checked: `delegateModelAccess`, `Synchronizer`, `SearchField` (Ryoku has its own
`plugins/kit/SearchField.qml`), `FlexboxLayout`, `ShapePath.trim`, `SafeArea`, `ContextMenu`, `DelegateChooser`, `Flickable.acceptedButtons`,
`TextEdit.textEdited` (all four `onTextEdited` handlers are on `TextInput`), `popupType`, `Qt.atob/btoa(ArrayBuffer)`). The QtMultimedia usage is
the 6.0-era API (no `playbackOptions` or `endOfStreamPolicy`). The JavaScript uses `?.`/`??` (`services/BarProducts.qml:21`, `desktop/WidgetMenu.qml:49`),
class syntax and template literals, all of which work in V4 on 6.8+.
**→ Minimum Qt for a 100% identical shell: 6.11.** Arch ran 6.11.2 on the pin date. Without the hero launcher's exact look, the minimum is 6.9.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| qt6-declarative | QtQuick, Shapes, Layouts, Controls, Dialogs, Effects, folderlistmodel, QtQml.Models | qml6-module-qtquick, -qtquick-effects, -qtquick-shapes, -qtquick-layouts, -qtquick-controls, -qtquick-templates, -qtquick-dialogs, -qtquick-window, -qt-labs-folderlistmodel, -qtqml-models, -qtqml, -qtqml-workerscript | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | **6.11** (`hero/LauncherSurface.qml:466`); 6.9 (`qsbar/BarSlot.qml:179`) |
| qt6-5compat | `Qt5Compat.GraphicalEffects` (7 files) | qml6-module-qt5compat-graphicaleffects | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | same minor as qtbase |
| qt6-multimedia + qt6-multimedia-ffmpeg | video wallpaper / previews (4 files); `QT_MEDIA_BACKEND=ffmpeg` (`systemd/user/ryoku-shell.service:22`) | qml6-module-qtmultimedia, libqt6multimedia6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | same minor |
| qt6-svg | SVG icons (`services/Icons.qml:7-14`) | qt6-svg-plugins, libqt6svg6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | same minor |
| qt6-imageformats | WebP previews (`ryoku-desktop/PKGBUILD:44-49`) | qt6-image-formats-plugins | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | same minor |
| qt6-wayland | Wayland QPA | qt6-wayland, libqt6waylandclient6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | same minor |
| syntax-highlighting | `CodeHighlight.qml` | qml6-module-org-kde-syntaxhighlighting | 6.13.0 | - | 6.30.0 | 6.30.0 | 6.24.0 | KF6 public ABI; a build against older Qt runs on newer Qt |
| qt6-base | Qt core | qt6-base (libqt6core6t64 etc.) | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | 6.11 |

**As-is on Debian:** forky/sid YES. resolute PARTIAL (the default launcher falls back to okshell). trixie NO (default bar, dock and clipboard do not load).

**Port steps:**
1. forky/sid: `apt install` the packages in the table. No change needed.
2. trixie (Qt 6.8.2): either (a) backport Debian's 6.11.2 Qt source packages to trixie, or (b) patch the QML.
   - (a) Rebuild from forky in dependency order: `qt6-base`, `qt6-shadertools`, `qt6-svg`, `qt6-declarative`, `qt6-wayland`, `qt6-5compat`,
     `qt6-imageformats`, `qt6-multimedia`, `qt6-tools` (needed by several of these for build). Use
     `dget <forky .dsc> && dch --bpo && sbuild -d trixie`. Then rebuild every private-API reverse dependency that a Ryoku box installs
     (at minimum `quickshell`, `qt6ct`, plus anything else depending on `qtbase-abi-6-8-2` / `qtdeclarative-abi-6-8-2`, for example fcitx5-qt6 if installed).
   - (b) Patching QML is not a 100% port: replacing `RectangularShadow` with `MultiEffect { shadowEnabled: true }` changes rendering.
3. resolute (Qt 6.10.2): (a) backport Qt 6.11 as in step 2(a), or (b) patch `hero/LauncherSurface.qml:466-469` (per-corner radii → one
   `radius`), which visibly changes the hero launcher's shadow shape.

**Complexity:** forky/sid Low. resolute Medium. trixie High (a Qt minor-version backport plus rebuilding its private-ABI consumers).

**Issues / risks:**
- RectangularShadow failures cascade. `PillShadow.qml` is a `RectangularShadow` root instantiated by 21 files across the qsbar bar style, so on Qt 6.8 the whole default bar style fails, not just its shadows.
- A Qt backport on trixie conflicts with every trixie package that pins `qtbase-abi-6-8-2`. Those must be rebuilt or dropped from the image.
- Arch already runs Qt 6.12 (2026-10-01). Future Ryoku commits may start using 6.12-only APIs, and no Debian suite has 6.12 yet.

**Questions for the human:**
- Base Qt: (1) forky/sid as-is (Qt 6.11.2, zero work, moving target); (2) trixie plus a self-maintained Qt 6.11 backport stack (≈9 source
  packages plus private-ABI rebuilds, every Qt security update re-done by hand); (3) resolute plus a Qt 6.11 backport, or accept the okshell
  fallback or patch `hero/LauncherSurface.qml:466-469` (not pixel-identical).

---

### Ryoku QML modules and the QML import path

**What it does:** The shell imports four Ryoku-owned module trees that are installed outside the config root. Quickshell sandboxes relative
imports to the running config, so these must be installed modules (`ryoku-desktop/PKGBUILD:340-345`).

**Arch couplings:**
- `Ryoku.PluginKit` → `/usr/lib/qt6/qml/Ryoku/PluginKit` (`release/packages/ryoku-desktop/PKGBUILD:324-326`).
- `Ryoku.Ui` → `/usr/lib/qt6/qml/Ryoku/Ui` (`PKGBUILD:331-337`).
- `Ryoku.FrameBars` → `/usr/lib/qt6/qml/Ryoku/FrameBars` (`PKGBUILD:347-349`).
- `Ryoku.Wm.Hyprland` → `/usr/lib/qt6/qml/Ryoku/Wm/Hyprland` (`release/packages/ryoku-desktop-hyprland/PKGBUILD:87-88`).
- `Ryoku.Blobs` → `/usr/lib/qt6/qml/Ryoku/Blobs` (`release/packages/ryoku-blobs/PKGBUILD:33-37`).
- The daemon decides whether to add `~/.local/lib/qt6/qml` by testing for `/usr/lib/qt6/qml/Ryoku/Blobs/qmldir` (`ryoku/shell/ipc/daemon.go:411`).
- Comments and docs assume that path: `ryoku/shell/environment.d/ryoku-session.conf:11`, `docs/ui-ux.md:151`, `deploy.sh:523`.

**Dependencies:** none beyond Qt.

**As-is on Debian:** NO. Debian's `QLibraryInfo::QmlImportsPath` is `/usr/lib/x86_64-linux-gnu/qt6/qml` (Debian quickshell's own
`-DINSTALL_QML_PREFIX=lib/$(DEB_HOST_MULTIARCH)/qt6/qml` confirms the layout). `/usr/lib/qt6/qml` is not searched, so `import Ryoku.Ui`
fails and no surface loads. `ryoku-desktop/PKGBUILD:343-345`: "Omitting it loads no shell at all".

**Port steps:**
1. In the Debian packaging for ryoku-desktop, ryoku-desktop-hyprland and ryoku-blobs, install to `/usr/lib/$(DEB_HOST_MULTIARCH)/qt6/qml/Ryoku/...`
   (old `$pkgdir/usr/lib/qt6/qml/Ryoku/<M>` → new `debian/<pkg>/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku/<M>`), or compute it with
   `qtpaths6 --query QT_INSTALL_QML`.
2. `ryoku/shell/ipc/daemon.go:411`: change the probe `"/usr/lib/qt6/qml/Ryoku/Blobs/qmldir"` to the multiarch path, or probe both.
   Otherwise every Debian box always appends `~/.local/lib/qt6/qml`. That is harmless when the directory is empty, but it lets a stale dev build shadow the package.
3. Update the comments and docs that name `/usr/lib/qt6/qml` (`ryoku-session.conf:11`, `docs/ui-ux.md:151`, `deploy.sh:523`).

**Complexity:** Low.

**Issues / risks:** The same path bug hits every Ryoku QML module packaged by other reports (Hub, apps, lockscreen `QML2_IMPORT_PATH`
in `ryoku/lockscreen/qylock/quickshell-lockscreen/lock.sh:46` is relative and fine).

---

### External commands run by the QML (`Process`, `Quickshell.execDetached`, `Spawn.run`, `sh -c`/`bash -c` bodies)

**What it does:** There are 209 `Process` blocks, 26 files calling `Quickshell.execDetached`, 26 `Spawn.run` calls
(`ryoku/ui/Singletons/Spawn.qml:33-43`), and 139 inline `bash -c`/`sh -c` bodies. All string literals were scanned for
command-position words. The list below is complete for this tree.

**Arch couplings:**
- `tail -n 0 -F /var/log/pacman.log` drives a "N PACKAGES CHANGED / PACMAN" particle in the bar (`qsbar/modules/ParticleStream.qml:1031-1047`).
  Debian has no such file. The apt equivalent is `/var/log/apt/history.log` (`Start-Date:` … `Upgrade:`/`Install:`/`Remove:` … `End-Date:`) or `/var/log/dpkg.log` (`status installed`).
- `gpk search <term> --json --limit 30 --manager pacman,aur` is the launcher's fast lane (`launcher/shared/providers/packages/Packages.qml:217`).
  gpk 0.6.10 has an apt manager (`internal/manager/apt.go` upstream), so on Debian the value becomes `--manager apt` (plus `flatpak` if wanted).
  gpk's PKGBUILD `depends=('pacman')` (`release/packages/gpk/PKGBUILD`). Its binary is a static Go release asset with no pacman link.
- `omarchy toggle idle` / `omarchy toggle notification silencing` are fallbacks when `ryoku-cmd-caffeine` / `true` is missing
  (`qsbar/modules/IdleWidget.qml:31`, `NotificationSilenceWidget.qml:29`). No such command exists on Arch either; the fallback is dead code.
- The web search `aur` bang points at `https://aur.archlinux.org/packages?K=` (`launcher/shared/providers/web/engines.js:11`).
- `kitty ryoku update` (`qsbar/modules/UpdateWidget.qml:68`) runs Ryoku's updater (pacman-based; other report). The update count comes from the daemon (`shell/services/Updates.qml:16`).
- The welcome copy says "on Arch and Hyprland" (`welcome/Welcome.qml:26`, `welcome/StepWelcome.qml:17`).

**Debian-specific differences (not Arch-only commands):**
- **`fd` is `fdfind` on Debian.** fd-find ships only `/usr/bin/fdfind` in trixie, sid and resolute. The launcher's file provider probes
  `command -v fd` (`launcher/shared/providers/find/Find.qml:215`) and runs `fd` (`Find.qml:130-135`). On Debian it reports "unavailable".
- **`rfkill` and `iw` are in `/usr/sbin`** on trixie, sid and resolute (`/usr/sbin/rfkill`, `/usr/sbin/iw`). The session PATH is
  `$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin` (`ryoku/shell/environment.d/ryoku-session.conf:16`). On Arch `/usr/sbin` → `/usr/bin`.
  Affected calls: `rfkill unblock bluetooth` (`bar/popouts/BluetoothPopout.qml:101`), `rfkill block|unblock wifi` (`qsbar/panels/NetworkPanel.qml:152`),
  `rfkill list wifi` (`NetworkPanel.qml:1542`), `rfkill` inside the BT link script (`services/BtLink.qml:167,178`, message text only),
  `iw dev $IFACE link` (`qsbar/modules/NetworkWidget.qml:209`, `NetworkPanel.qml:1406,1557`).
- `/bin/sh` is dash on Debian and bash on Arch. All 139 `sh -c` bodies were scanned for bashisms and none were found. Bodies that need
  bash already call `bash -c` explicitly (106 sites).
- `awk` is mawk by default on Debian and gawk on Arch. The only gawk-sensitive construct is regex intervals `{6}`/`{2}`
  (`qsbar/panels/ImageCarouselPanel.qml:240`, `ImageCarouselHearthstone.qml:246`). Installing `gawk` makes `/usr/bin/awk` resolve to gawk
  through alternatives, which gives Arch parity.
- `magick`/`identify`: Debian imagemagick-7.q16 registers `/usr/bin/magick` and `/usr/bin/identify` through `update-alternatives` (postinst), so the names match.
- `pactl` comes from `pulseaudio-utils` on Debian (Arch: libpulse).

**Command inventory** (Debian package; first cites; ✱ = guarded by `command -v`, missing → feature silently off):

| Command | Cites (file:line, paths relative to `ryoku/shell/quickshell/`) | Debian package | Notes |
|---|---|---|---|
| `qs` | `welcome/Welcome.qml:47`, `welcome/StepCustomize.qml:71`, `ryopin/Pin.qml:85`, `launcher/shared/providers/actions/catalog.js:22,35,36`, `bar/Frame.qml:71`, `services/Capture.qml:175` | quickshell | `qs -c hub|ryoshot|ryopin|keys` |
| `flock`, `setsid`, `lsblk` | `welcome/Welcome.qml:47`, `desktop/WidgetMenu.qml:118`; `qsbar/panels/MediaBrowserPanel.qml:167`; `qsbar/Theme.qml:2045` | util-linux | `flock -n -o`, `setsid -f` |
| `rfkill` | see above | rfkill (`/usr/sbin`) | PATH issue |
| `iw` | see above | iw (`/usr/sbin`) | PATH issue |
| `ip` | `qsbar/modules/NetworkWidget.qml:204`, `qsbar/panels/NetworkPanel.qml:1402,1404,1554` | iproute2 (`/usr/bin/ip`) | |
| `iwctl` | `qsbar/panels/NetworkPanel.qml:185,208,229,1456-1459` | iwd | fallback when Quickshell.Networking reports no NetworkManager (`NetworkManagerAdapter.qml:12`) |
| `nmcli`, `systemctl is-active NetworkManager` | `qsbar/panels/NetworkManagerAdapter.qml:268-270,319-324`; `qsbar/Theme.qml:2531` | network-manager | `nmcli --escape no -g` |
| `bluetoothctl` | `bar/popouts/BtHero.qml:73`, `services/BtLink.qml:160-230` (`--agent NoInputNoOutput --timeout`) | bluez | |
| `brightnessctl` | `qsbar/RyokuPower.js:16,29,32`, `services/Devices.qml:132,184` | brightnessctl | through `ryoku-hw-backlight` |
| `ddcutil` | `bar/BrightnessControl.qml:128`, `kairos/quicksettings/pages/DisplayPage.qml:111`, `services/Devices.qml:96,160` | ddcutil | needs i2c-dev (other report) |
| `upower -e/-i` | `qsbar/RyokuPower.js:36-37` | upower | |
| `playerctl` | `launcher/shared/providers/actions/catalog.js:29-31`, `qsbar/modules/MprisArtwork.qml:56` | playerctl | |
| `pactl` | `bar/framebars/menus/MediaHero.qml:64`, `services/Audio.qml:253,323`, `services/VoiceBars.qml:25`, `visualizer/Singletons/wavecap.py:26-27` | pulseaudio-utils | needs pipewire-pulse |
| `pw-record` | `visualizer/Singletons/wavecap.py:41,48` | pipewire-bin | |
| `python3` | `visualizer/Singletons/Waveform.qml:25` (`wavecap.py`, stdlib only) | python3 | |
| `cava` ✱ | `services/AudioBars.qml:58` (`method = pipewire`), `services/VoiceBars.qml:25` (`method = pulse`), `visualizer/Singletons/Spectrum.qml:48`, `bar/framebars/menus/MediaHero.qml:62-72`, `qsbar/modules/MprisWidget.qml:47-48` | cava | Debian cava links libpipewire + libpulse. Arch 1.0.0; trixie 0.10.4. Config keys used (`data_format`, `ascii_max_range`, `channels`, `mono_option`, `noise_reduction`, `raw_target`, `autosens`, `monstercat`, `waves`, `sleep_timer`, `active`) exist in both. |
| `grim` | `services/Capture.qml:168`, `ryoshot/Overlay.qml:142` | grim | |
| `slurp` | `services/Recorder.qml:77` | slurp | |
| `wl-copy`, `wl-paste` | `launcher/shared/AskPanel.qml:167`, `qsbar/panels/MediaBrowserPanel.qml:249-250`; `bar/panel/PanelChat.qml:212,215` | wl-clipboard | |
| `notify-send` | `bar/RecordHud.qml:149`, `services/Capture.qml:172-173`, `ryoshot/shell.qml:592`, `ryopin/shell.qml:98` | libnotify-bin | |
| `xdg-open` | `launcher/shared/AskPanel.qml:180,184,419`, `bar/panel/PanelChat.qml:996,1048`, `services/Stash.qml:165`, `services/Needle.qml:136` | xdg-utils | |
| `gio trash` / `trash-put` | `qsbar/panels/MediaBrowserPanel.qml:240`, `MediaBrowserHearthstone.qml:242`, `MediaBrowserCarousel.qml:232` | libglib2.0-bin / trash-cli | either one |
| `magick`, `identify` | `qsbar/panels/ImageCarouselPanel.qml:270,276`, `MediaBrowserPanel.qml:199,203`; `ryoshot/Beautify.qml:148` | imagemagick | |
| `ffmpeg`, `ffprobe` | `bar/popouts/CapturePopout.qml:106,108` | ffmpeg | |
| `waifu2x-ncnn-vulkan` ✱ | `ryoshot/Beautify.qml:147-150` (models hardcoded at `/usr/share/waifu2x-ncnn-vulkan/models-cunet`) | **not in Debian/Ubuntu** | Arch extra 20250915. Build recipe in Port steps. |
| `curl` | `launcher/shared/providers/web/Web.qml:93`, `launcher/shared/Singletons/Weather.qml:56,150`, `ryoshot/shell.qml:852` | curl | |
| `jq` | `qsbar/modules/ParticleStream.qml:938`, `qsbar/Theme.qml:2498` | jq | |
| `fd` ✱ | `launcher/shared/providers/find/Find.qml:130-135,215` | fd-find (`fdfind`) | name differs |
| `find` | `launcher/shared/providers/recent/Recent.qml:92,192`, `desktop/PluginWidgetMenu.qml:110` | findutils | `find --version` probe |
| `kitty` | `launcher/shared/AskPanel.qml:176`, `qsbar/modules/UpdateWidget.qml:68`, `qsbar/panels/{BatteryPanel.qml:230,CpuPanel.qml:358,MemoryPanel.qml:212,GpuPanel.qml:276}` | kitty (trixie 0.41.1; Arch current) | hardcoded terminal |
| `btop` | same four panels (`kitty 'btop'`) | btop | |
| `nvim` | `launcher/shared/AskPanel.qml:176,194` | neovim | |
| `nautilus` | `bar/popouts/CapturePopout.qml:468` | nautilus | |
| `pavucontrol` ✱ | `qsbar/panels/VolumePanel.qml:681` | pavucontrol | |
| `zenity` / `kdialog` | `bar/panel/PanelChat.qml:194`, `ryoshot/shell.qml:836-837`, `ryoshot/SettingsPanel.qml:24-25` | zenity / kdialog | |
| `inxi` ✱ | `qsbar/Theme.qml:1982` | inxi | |
| `nvidia-smi` | `qsbar/Theme.qml:1997-1998`, `services/StatsFeed.qml:221` | nvidia-smi (non-free; 550.163.01 trixie) | NVIDIA only |
| `nvibrant` | `services/Devices.qml:51` | **not in Debian** (Arch AUR `nvibrant-bin`, `system/packages/aur.packages`) | NVIDIA digital vibrance |
| `voxtype` ✱ | `qsbar/Theme.qml:2497-2498` | **not in Debian** (AUR `voxtype-bin`) | other report (dictation) |
| `makoctl` ✱ | `qsbar/modules/ParticleStream.qml:938`, `qsbar/Theme.qml:2400,2410` | mako-notifier | optional, probed |
| `pgrep`, `pkill`, `ps` | `qsbar/Theme.qml:2388` (`pgrep -x hypridle`), `services/Recorder.qml:343-347` (gpu-screen-recorder / wf-recorder detection), `qsbar/modules/ClaudeWidget.qml:122-132` (claude/codex/opencode), `qsbar/Theme.qml:1989` | procps | |
| `systemctl` | `bar/framebars/menus/MenuQuickActions.qml:57-58` (reboot/poweroff), `quicksettings/QuickSettingsHome.qml:103,110`, `qsbar/Theme.qml:1460` (`--user start ryoku-ai-usage.service`) | systemd | |
| `df`, `stat`, `date`, `sha256sum`, `md5sum`, `mktemp`, `readlink`, `timeout`, `basename`, `dirname`, `sort`, `head`, `tail`, `tr`, `cut`, `touch`, `mv`, `cp`, `ln`, `rm`, `mkdir`, `nice`, `tee`, `sleep`, `env` | e.g. `services/StatsFeed.qml:228`, `qsbar/Theme.qml:1357,2039`, `qsbar/panels/ImageCarouselPanel.qml:171-276` | coreutils | GNU flags (`date +%s%N`, `stat -c`) |
| `grep`, `sed`, `awk`, `xargs` | `qsbar/RyokuPower.js:12-42`, `qsbar/panels/NetworkPanel.qml:1457-1469` | grep, sed, gawk (see above), findutils | |
| `git` | none executed (string matches are icon names `qsbar/Theme.qml:3018` and URL rewriting `ImageCarouselPanel.qml:347`) | n/a | |
| Ryoku commands | `ryoku-shell` (48 refs, e.g. `bar/Frame.qml:67`), `ryoku-hub` (`keys/shell.qml:24`, `ryoshot/HotkeyRow.qml:55`), `ryoku-rashin` (`launcher/shared/AskPanel.qml:109-159`), `ryogami` (`launcher/shared/providers/actions/catalog.js:18-19`, `welcome/StepCustomize.qml:70`), `ryostore` (`qsbar/controlcenter/routes/LayoutRoute.qml:561`), `ryoku` (`qsbar/controlcenter/routes/CommunityRoute.qml:85-91`), `ryostage` (`stage/Singletons/StageBackend.qml:16`), `ryoku-app` (`services/AppLaunch.qml:27`), `ryoku-docker` (`services/Stash.qml:150`), `ryoku-plugins-place` (`qsbar/Theme.qml:612`, `desktop/Desktop.qml:144`), `ryoku-reload-cover` (`shell/shell.qml:74-75`), `ryoku-eq` (`services/Equalizer.qml:20-21`), `ryoku-hw-backlight` (`qsbar/RyokuPower.js:12`), `ryoku-monitor` (`launcher/shared/providers/actions/catalog.js:16`; lives in `ryoku/hyprland/scripts/`), `ryoku-cmd-{caffeine,game-mode,color-picker,ocr,qr-scan,google-lens,radio,calc,songrec,screenrecord,nightlight}` (`shell/shell.qml:595,614`, `catalog.js:14-32`), `stash-{compress,install}.sh` (`services/Stash.qml:181,185`), `plugins/discover.sh` (`desktop/Singletons/Registry.qml:22-23`) | Ryoku's own packages (other reports) | each needs a Debian deb |

`plugins/discover.sh` and `plugins/ryoku-plugins-place` (in scope) need bash, jq (`--rawfile`, jq ≥1.6), flock (util-linux) and coreutils. Debian has them all.

**Filesystem paths read by the QML:**
- `/proc/stat`, `/proc/cpuinfo`, `/proc/loadavg`, `/proc/meminfo`, `/proc/uptime`, `/proc/net/dev`, `/proc/sys/kernel/osrelease`,
  `/proc/$p/cmdline` (`qsbar/Theme.qml:1936-1960`, `services/Session.qml:55`, `services/Sysinfo.qml:82-103`, `services/StatsFeed.qml:200`,
  `services/Recorder.qml:345`). These are kernel ABI and identical on Debian.
- `/sys/class/{net,hwmon,thermal,backlight,power_supply,drm}`, `/sys/devices/system/cpu/cpu0/cpufreq/*`, `/sys/bus/pci/drivers/nvidia/*`
  (`qsbar/RyokuPower.js:12`, `qsbar/Theme.qml:2005-2030`, `NetworkPanel.qml:1438`). Also identical.
- `/etc/hostname` (`services/Session.qml:66`). Identical.
- `/var/log/pacman.log` (`qsbar/modules/ParticleStream.qml:1034`). **Arch-only.**
- `/usr/share/waifu2x-ncnn-vulkan/models-cunet` (`ryoshot/Beautify.qml:147`). This is the path of the Arch package; the Debian deb must use the same one.
- `/usr/share/ryoku` (`qsbar/Theme.qml:2300,2327,3567`). Ryoku's own path; same on Debian.
- No `/etc/os-release`, `/usr/lib/qt6/...` or `/usr/share/icons` reads in QML. Icons are indexed by `ryoku-shell icons` (daemon,
  `services/Icons.qml:84-97`) from the GTK icon theme in `~/.config/gtk-3.0/settings.ini` (`Icons.qml:114-120`).

**Dependencies:** `fd-find`, `rfkill`, `iw`, `iproute2`, `iwd`, `network-manager`, `bluez`, `brightnessctl`, `ddcutil`, `upower`, `playerctl`,
`pulseaudio-utils`, `pipewire-bin`, `python3`, `cava`, `grim`, `slurp`, `wl-clipboard`, `libnotify-bin`, `xdg-utils`, `libglib2.0-bin`, `trash-cli`,
`imagemagick`, `ffmpeg`, `curl`, `jq`, `kitty`, `btop`, `neovim`, `nautilus`, `pavucontrol`, `zenity`, `kdialog`, `inxi`, `procps`, `util-linux`,
`coreutils`, `findutils`, `grep`, `sed`, `gawk`, `bash`, plus `nvidia-smi` (NVIDIA), `mako-notifier` (optional). Versions:

| Arch pkg | Debian pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|
| fd | fd-find | 10.2.0 | - | 10.5.0 | 10.5.0 | 10.3.0 | any; binary name `fdfind` |
| util-linux (rfkill) | rfkill | 2.41.5 | - | 2.42.4 | 2.42.4 | 2.41.3 | any |
| iw | iw | 6.9 | - | 6.17 | 6.17 | 6.17 | any |
| iwd | iwd | 3.8 | - | 3.12 | 3.12 | 3.10 | any |
| networkmanager | network-manager | 1.52.1 | - | 1.58.1 | 1.58.1 | 1.54.3 | any |
| bluez-utils | bluez | 5.82 | - | 5.87 | 5.87 | 5.85 | `--agent/--timeout` flags present in all |
| brightnessctl | brightnessctl | 0.5.1 | - | 0.5.1 | 0.5.1 | 0.5.1 | any |
| ddcutil | ddcutil | 2.2.0 | 2.2.7 | 2.2.7 | 2.2.7 | 2.2.5 | any |
| upower | upower | 1.90.9 | - | 1.91.5 | 1.91.5 | 1.91.1 | any |
| playerctl | playerctl | 2.4.1 | - | 2.4.1 | 2.4.1 | 2.4.1 | any |
| libpulse (pactl) | pulseaudio-utils | 17.0 | - | 17.0 | 17.0 | 17.0 | ≥15 (`pactl get-default-sink`) |
| pipewire | pipewire-bin / pipewire-pulse | 1.4.2 | 1.6.9 | 1.6.9 | 1.6.9 | 1.6.2 | any |
| cava | cava | 0.10.4 | - | 1.0.0 | 1.0.0 | 0.10.7 | Arch had 1.0.0 at pin |
| grim / slurp | grim / slurp | 1.4.0 / 1.5.0 | - | 1.5.0 / 1.5.0 | same | 1.4.0 / 1.6.0 | any |
| wl-clipboard | wl-clipboard | 2.2.1 | 2.3.0 | 2.3.0 | 2.3.0 | 2.2.1 | any |
| libnotify | libnotify-bin | 0.8.6 | - | 0.8.8 | 0.8.8 | 0.8.8 | any |
| xdg-utils | xdg-utils | 1.2.1 | - | 1.2.1 | 1.2.1 | 1.2.1 | any |
| glib2 (gio) | libglib2.0-bin | 2.84.4 | - | 2.90.1 | 2.90.1 | 2.88.0 | any |
| trash-cli | trash-cli | 0.24.5.26 | - | same | same | same | any |
| imagemagick | imagemagick | 7.1.1.43 | - | 7.1.2.31 | 7.1.2.33 | 7.1.2.18 | IM7 (`magick`) |
| ffmpeg | ffmpeg | 7.1.5 | - | 9.0.2 | 9.0.2 | 8.0.1 | any |
| curl / jq | curl / jq | 8.14.1 / 1.7.1 | 8.21.0 / - | 8.22.0 / 1.8.2 | 8.23.0 / 1.8.2 | 8.18.0 / 1.8.1 | jq ≥1.6 (`--rawfile`) |
| kitty / btop / neovim | kitty / btop / neovim | 0.41.1 / 1.3.2 / 0.10.4 | - | 0.48.2 / 1.4.7 / 0.12.4 | same | 0.45.0 / 1.4.6 / 0.11.6 | other report |
| nautilus / pavucontrol | nautilus / pavucontrol | 48.3 / 6.1 | - | 51.0.1 / 6.1 | same | 50.2.2 / 6.1 | any |
| zenity / kdialog | zenity / kdialog | 4.1.90 / 25.04.0 | - | 4.2.2 / 26.04.0 | same | 4.2.1 / 25.12.3 | any |
| inxi | inxi | 3.3.38 | 3.3.41 | 3.3.41 | 3.3.41 | 3.3.40 | any |
| nvidia-utils | nvidia-smi (non-free) | 550.163.01 | 550.163.01 | 550.163.01 | 550.163.01 | - (Ubuntu: nvidia-utils-NNN) | any |
| gawk | gawk | 5.2.1 | - | 5.3.2 | 5.3.2 | 5.3.2 | any |
| mako | mako-notifier | 1.10.0 | - | 1.11.0 | 1.11.0 | 1.10.0 | optional |
| waifu2x-ncnn-vulkan | — | - | - | - | - | - | upstream 20250915 |
| nvibrant-bin (AUR) | — | - | - | - | - | - | upstream |
| voxtype-bin (AUR) | — | - | - | - | - | - | other report |
| gpu-screen-recorder (only detected by pgrep here) | gpu-screen-recorder | - | - | 5.13.8 | 5.13.8 | - | other report |

**As-is on Debian:** PARTIAL. Most tools exist under the same names. `fd`, `rfkill`, `iw`, the pacman log, the gpk manager list and three unpackaged binaries differ.

**Port steps:**
1. `fd`: ship `/usr/bin/fd -> fdfind` in a Ryoku deb (`Depends: fd-find`), or change `Find.qml:130-135,215` to resolve
   `fd` then `fdfind` (`command -v fd || command -v fdfind`). The symlink keeps the QML byte-identical.
2. PATH: change `ryoku/shell/environment.d/ryoku-session.conf:16` from
   `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin` to `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin`.
   Apply the same change to any PATH the Hyprland `env.lua` sets (other report). Alternatively call `/usr/sbin/rfkill` and `/usr/sbin/iw` by full path.
3. `qsbar/modules/ParticleStream.qml:1034`: replace the pacman log tail with an apt one, for example
   `tail -n 0 -F /var/log/apt/history.log`, counting packages on `Install:`/`Upgrade:`/`Remove:` lines and firing on `End-Date:`.
   Change the label `"PACMAN"` (`:1045`).
4. `Packages.qml:217`: `"--manager", "pacman,aur"` → `"--manager", "apt"` (or `"apt,flatpak"`). Repackage gpk 0.6.10 as a deb from
   `https://github.com/neur0map/glazepkg/releases/download/v0.6.10/gpk-linux-amd64` (sha256 `b4e43c24…` per `release/packages/gpk/PKGBUILD`),
   installed to `/usr/bin/gpk` with no pacman dependency.
5. `waifu2x-ncnn-vulkan` deb: upstream `https://github.com/nihui/waifu2x-ncnn-vulkan`, tag `20250915` (Arch extra uses the same version).
   `git clone --recursive -b 20250915 …` (bundles ncnn and glslang submodules).
   Build-deps: `cmake g++ libvulkan-dev glslang-dev libwebp-dev libpng-dev libjpeg-dev` (Debian has no `libncnn-dev`, so use the bundled submodule).
   `cmake -S src -B build -DCMAKE_BUILD_TYPE=Release -DUSE_SYSTEM_NCNN=OFF -DUSE_SYSTEM_WEBP=ON && cmake --build build`.
   Install `build/waifu2x-ncnn-vulkan` → `/usr/bin/` and `models/models-{cunet,upconv_7_anime_style_art_rgb,upconv_7_photo}` →
   `/usr/share/waifu2x-ncnn-vulkan/` (the path `ryoshot/Beautify.qml:147` hardcodes). Runtime: `libvulkan1` + a Vulkan ICD.
   (The upstream `-linux.zip` release asset is an alternative prebuilt binary.)
6. `nvibrant`: build from upstream `https://github.com/Tremeschin/nvibrant` (the AUR `nvibrant-bin` source) as a deb, or leave it out on non-NVIDIA images.
   It is called unguarded at `services/Devices.qml:51`.
7. Depend on `gawk` so `/usr/bin/awk` resolves to gawk as on Arch.
8. Optional, for parity of copy: change "on Arch and Hyprland" in `welcome/Welcome.qml:26` and `welcome/StepWelcome.qml:17` (i18n catalog keys change too).

**Complexity:** Medium (many small edits plus two from-source debs).

**Issues / risks:**
- The hardcoded `kitty` (5 sites) and `nautilus` (2) stay hard dependencies.
- `omarchy` fallbacks are dead on both distros.
- `bluetoothctl --agent NoInputNoOutput` behaviour depends on the BlueZ version (trixie 5.82, Arch newer). `ryoku-desktop` works around a BlueZ ≥5.83 A2DP regression (`ryoku-desktop/PKGBUILD:630-637`), so trixie's 5.82 behaves differently from Arch's here.

---

### Shaders (`*.frag` → `*.frag.qsb`)

**What it does:** `ShaderEffect.fragmentShader` loads precompiled `.qsb` files:
- `modules/wallpaper/reveal.frag.qsb` and 39 `modules/wallpaper/skwd/*.frag.qsb` wallpaper transitions (`modules/wallpaper/Backdrop.qml:302-323,431`; transition names come from ryogami, `ryoku/shell/ryogami/daemon/transitions.go:148,344`).
- `qsbar/shaders/stream.frag.qsb` (`qsbar/modules/StreamShader.qml:88`).
- `qsbar/shaders/logo-tint.frag.qsb` (`ClaudeWidget.qml:196`, `GpuWidget.qml:47`, `AiUsagePanel.qml:144`).

The convention is `qsb --qt6 -o <name>.frag.qsb <name>.frag`, with the result committed (`docs/development.md:17-19`).

**Arch couplings:** none at runtime. The shaders are built by hand with Arch's `qsb` (`qt6-shadertools`).

**Dependencies:**

| Arch pkg | Used for | Debian pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| qt6-shadertools (qsb, dev only) | regenerating `.qsb` | qt6-shader-baker (`/usr/lib/qt6/bin/qsb`; not on PATH) | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | any 6.x writing QSB v9 |

**As-is on Debian:** YES. All 42 committed `.qsb` files decode to QSB serialization version **9** and carry GLSL 100es/120/150, HLSL
and MSL variants. `QShaderPrivate::QSB_VERSION = 9` in qtbase v6.8.2, v6.10.0 and v6.11.0 (`src/gui/rhi/qshader_p.h`), so
trixie, resolute and forky/sid all load them unchanged.

**Port steps:** none for runtime. For development on Debian, `qsb` is `/usr/lib/qt6/bin/qsb` (package `qt6-shader-baker`). Either call it by
full path or add `/usr/lib/qt6/bin` to PATH. `docs/development.md:17` assumes `qsb` is on PATH (on Arch it is `/usr/bin/qsb`).

**Complexity:** Low.

**Issues / risks:** `qsbar/shaders/logo-tint.frag.qsb` has **no `.frag` source** in the repo (41 `.frag` for 42 `.qsb`). It cannot be
regenerated if a future Qt drops QSB v9 reading. Recovering the GLSL from the `.qsb` (`qsb -d`) is the only path.

---

### matugen (`ryoku/shell/matugen/`)

**What it does:** It is the Material You / base16 palette engine. The daemon runs `matugen image <wallpaper> -t <scheme> -m <dark|light> --contrast N
--lightness-dark N --lightness-light N --source-color-index N --prefer <p> --json hex --dry-run` (`ryoku/shell/ipc/matugen.go:156-190`).
It then renders templates with `matugen -c <config> json <carrier.json>` (`matugen.go:1253`, also `ryoku/hub/backend/schemes.go:49`).

**Template syntax used** (`ryoku/shell/matugen/templates/*`): `{{colors.<role>.<default|dark|light>.hex}}` (1340×), `.hex_stripped`, `.red/.green/.blue`,
`.hue/.saturation/.lightness`, base16 roles `{{colors.color0..color15[_argb].<mode>.hex}}`, and one filter `{{… | replace: "#", ""}}`.
No `<* for *>` blocks.

**Template targets:**
- Core set (`config.toml`, always rendered): `~/.config/kitty/current-theme.conf`, `~/.cache/ryoku/hypr-colors.lua`,
  `~/.config/btop/themes/ryoku.theme`, `~/.cache/ryoku/share-picker.css`, `~/.config/qt6ct/colors/ryoku.conf`
  (post_hook runs `ryoku-cmd-folders` and `ryoku-cursor-material-recolor`), `~/.cache/ryoku/kdeglobals-colors.conf`.
- App set (`apps.toml`, toggled): `~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css`, `~/.config/vesktop/themes/matugen.css`,
  `~/.config/equibop/themes/matugen.css`, `~/.config/obs-studio/themes/matugen.theme`, `~/.config/zed/themes/matugen.json`,
  `~/.config/heroic/store/styles/matugen.css`, `~/.local/share/TelegramDesktop/tdata/matugen.tdesktop-theme`,
  `~/.steam/steam/steamui/skins/Material-Theme/css/main/colors/matugen.css`, `~/.config/cava/config`, `~/.config/ghostty/ryoku-colors`,
  `~/.config/micro/colorschemes/matugen.micro`, `~/.cache/matugen/papirus-color` (post_hook `papirus-folders -c …` if present),
  `~/.config/fish/conf.d/ryoku-colors.fish`, `~/.config/yazi/theme.toml`, `~/.config/matugen/generated/obsidian.css`,
  `~/.config/zathura/zathurarc`, `~/.config/alacritty/colors.toml`, `~/.config/tmux/ryoku-colors.conf`, `~/.config/Sidra/custom.css`,
  `~/.config/ryotunes/skins/matugen/skin.json`.
- `templates/colors.json` exists but no config block references it. The daemon writes colors.json itself (`config.toml:3-4` comment).

**Arch couplings:**
- `matugen` comes from Arch `extra` (`system/packages/base.packages:146`, `ryoku-desktop/PKGBUILD:121-124`). Arch shipped 4.2.0-1 (2026-08-18) on the pin date.
- Arch builds it with `cargo build --frozen --release --all-features` (Arch PKGBUILD).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| matugen 4.2.0 | palette + templates (`ipc/matugen.go:156-190,1253`) | — (not packaged) | - | - | - | - | - | **4.1.0**: `--prefer` added in 4.1.0 (upstream CHANGELOG, PR #264). `--source-color-index` and `--lightness-dark/-light` and base16 `color0..15` added in 4.0.0. Pin **4.2.0** for identical colours, because 4.2.0 changes base16 accent ordering (#286, #283). |
| (build) rust | build | rustc / cargo | 1.85.1 | 1.96.1 | 1.96.1 | 1.97.1 | 1.93.1 | **≥1.88** (locked `image 0.25.10` declares `rust-version 1.88.0`) |
| papirus-folders (optional) | `apps.toml` papirus post_hook | — | - | - | - | - | - | optional; guarded by `which` |

**As-is on Debian:** NO.

**Port steps** (build matugen 4.2.0 as a deb):
1. Source: `https://github.com/InioX/matugen/archive/refs/tags/v4.2.0.tar.gz` (Arch sha256 `82044ab8ac3e793b2b94f8f75917b348b4038585133a77c07f5de59c88d65244`).
2. Toolchain: trixie → `apt install -t trixie-backports rustc cargo` (1.96). forky/sid/resolute use the archive rustc.
   Build-deps: `cargo rustc pkgconf gcc`. With `--all-features`, reqwest uses `rustls-tls` (ring), so no libssl is needed. jxl-oxide is pure Rust.
3. `cargo fetch --locked && cargo build --frozen --release --all-features` (same as Arch). Vendor crates with `cargo vendor` for an offline sbuild.
4. Install `target/release/matugen` → `/usr/bin/matugen`. License GPL-2.0-or-later (Cargo.toml).

**Complexity:** Medium (Rust deb with 381 crates; trixie needs backports rustc).

**Issues / risks:**
- matugen is not in Debian under any name. Debian's Rust policy would reject this deb as-is (vendored crates), so it lives in the Ryoku repo.
- Template targets assume app paths. Steam's `~/.steam/steam` is the same for Debian's `steam-installer`. Telegram's `~/.local/share/TelegramDesktop` is the native build's path, not the flatpak's.

---

### qt6ct, fonts, icon theme, cursor theme

**What it does:**
- `ryoku/shell/qt6ct/qt6ct.conf` sets `style=Fusion`, `icon_theme=Papirus-Dark`, `general="Space Grotesk,10…"`, `fixed="SpaceMono Nerd Font,10…"`, and the palette from `~/.config/qt6ct/colors/ryoku.conf` (matugen) (`qt6ct.conf:2-10`).
- The session sets `QT_QPA_PLATFORMTHEME=qt6ct` (`ryoku-session.conf:20`).
- GTK baseline (`ryoku/shell/gtk-3.0/settings.ini`): `gtk-theme-name=adw-gtk3-dark`, `gtk-icon-theme-name=ryoku-folders` (generated by `ryoku-cmd-folders`), `gtk-cursor-theme-name=Bibata-Modern-Ice` (`:12-13`).

**Font families named in the QML:**

| Family | Where | Arch package | Debian/Ubuntu |
|---|---|---|---|
| Material Symbols Rounded (variable; FILL/opsz axes) | `components/MaterialIcon.qml:9-11` (every pill/bar icon), `qsbar/modules/IconText.qml:10`, launcher okshell/kairos | ttf-material-symbols-variable (`ryoku-desktop/PKGBUILD:173`) | **none**. `fonts-material-design-icons-iconfont` 6.7.0 is the old "Material Icons" family, not Symbols. |
| JetBrainsMono Nerd Font | `reload-cover/ReloadCover.qml:130,141`, `plugins/kit/Singletons/Theme.qml:75`, `desktop/Singletons/Theme.qml:80`, `overview/Singletons/Theme.qml:40` | ttf-jetbrains-mono-nerd 3.5.1 | **none** (fonts-jetbrains-mono is the non-Nerd face) |
| SpaceMono Nerd Font | `ryoku/ui/Singletons/Tokens.qml:107,279` (default `Tokens.mono`), `qt6ct.conf:10`, `ipc/matugen.go:1645` | **not shipped by any Ryoku package or package list** (checked base/aur/cachyos/hardware packages and all PKGBUILDs) | none |
| Space Grotesk | `Tokens.qml:106`, `plugins/kit/Singletons/Theme.qml:73`, `overview/Singletons/Config.qml:59` | otf-space-grotesk 2.0.0 ([ryoku], `release/packages/otf-space-grotesk/PKGBUILD`) | Debian: none. Ubuntu resolute: fonts-space-grotesk 2.0.0. |
| Fraunces | `Tokens.qml:105`, `services/Theme.qml:213`, several Theme singletons | AUR ttf-fraunces-variable (`system/packages/aur.packages`) | none |
| Noto Sans CJK JP | `Tokens.qml:108`, `qsbar/Theme.qml:3042` | noto-fonts-cjk | fonts-noto-cjk |
| Inter / Inter Display | `desktop/stats/StatsWidget.qml:99-150`; `desktop/clock/ClockGoodNight.qml:60,66` | inter-font 4.1 | fonts-inter 4.1 (`Inter Display` is in Inter 4.x; check with `fc-list \| grep "Inter Display"` on the target) |
| Adwaita Mono | `qsbar/modules/WorkspaceWidget.qml:299`, `qsbar/controlcenter/kit/CcWorkspacePreview.qml:128` | via adwaita fonts (GNOME 48) | fonts-adwaita: forky/sid 51.0, resolute 49.0, **not in trixie** |
| Bundled display fonts (FontLoader) | `desktop/Singletons/Fonts.qml:20-30` → `shell/assets/fonts/*` | in-tree | in-tree |
| Nerd Font codepoints for launcher logos (`0xF359` hyprland, `0xE732` arch, …) | `qsbar/Theme.qml:3016-3018` | any Nerd Font | needs the Nerd Font packages above |

**Icon theme:** Papirus-Dark (`qt6ct.conf:4`; `ryoku-desktop/PKGBUILD:69-72`) → Debian `papirus-icon-theme` (20250501 trixie, 20260801 forky/sid).
`papirus-folders` (matugen post_hook) is not in Debian.

**Cursor:** `XCURSOR_THEME=Bibata-Modern-Ice` (`ryoku-session.conf:8`). It ships from `[ryoku]` `ryoku-cursors` (other report). Debian also has `bibata-cursor-theme` 2.0.6.

**Dependencies:**

| Arch pkg | Used for | Debian pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| qt6ct | Qt palette/font/icons | qt6ct | 0.10 | - | 0.11 | 0.11 | 0.11 | must match Qt minor (private API); rebuild with any Qt backport |
| papirus-icon-theme | Qt + GTK icons | papirus-icon-theme | 20250501 | - | 20260801 | 20260801 | 20250501+git | any |
| noto-fonts-cjk | JP seals | fonts-noto-cjk | 20240730 | - | same | same | same | any |
| inter-font | stats/clock | fonts-inter | 4.1 | - | 4.1 | 4.1 | 4.1 | 4.x |
| (adwaita fonts) | Adwaita Mono | fonts-adwaita | - | - | 51.0 | 51.0 | 49.0 | any |
| ttf-material-symbols-variable | all icons | — | - | - | - | - | - | variable font with FILL axis |
| ttf-jetbrains-mono-nerd | mono | — | - | - | - | - | - | nerd-fonts v3.5.1 (Arch) |
| otf-space-grotesk | UI | — (Ubuntu: fonts-space-grotesk) | - | - | - | - | 2.0.0 | 2.0.0 |
| ttf-fraunces-variable (AUR) | display | — | - | - | - | - | - | upstream |
| ttf-maple-mono-nf ([ryoku]) | offered mono (Hub) | — | - | - | - | - | - | 7.9 (`release/packages/ttf-maple-mono-nf/PKGBUILD`) |

**As-is on Debian:** PARTIAL. Without Material Symbols every icon renders as its ligature text (`ryoku-desktop/PKGBUILD:164-167`).

**Port steps:**
1. `fonts-ryoku-material-symbols` deb: from `https://github.com/google/material-design-icons` path `variablefont/`, install
   `MaterialSymbols{Rounded,Outlined,Sharp}[FILL,GRAD,opsz,wght].ttf` → `/usr/share/fonts/truetype/material-symbols/` (Arch installs these three files to `/usr/share/fonts/TTF/`).
2. Nerd Fonts deb(s): from `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/{JetBrainsMono,SpaceMono}.zip` (plus FiraCode and Hack, which `base.packages:310-311` lists),
   installing `*.ttf` → `/usr/share/fonts/truetype/nerd-fonts/<family>/`. Including SpaceMono changes the look relative to an Arch box that lacks it (see issue below).
3. Space Grotesk deb: reuse `release/packages/otf-space-grotesk` (`SpaceGrotesk-2.0.0.zip`, `otf/*.otf` → `/usr/share/fonts/opentype/space-grotesk/`). On resolute use `fonts-space-grotesk`.
4. Fraunces deb: upstream `https://github.com/undercasetype/Fraunces` variable TTFs → `/usr/share/fonts/truetype/fraunces/`.
5. Maple Mono NF deb: reuse `release/packages/ttf-maple-mono-nf` (`MapleMono-NF.zip` v7.9).
6. trixie: `fonts-adwaita` is absent. Repackage from forky (`fonts-adwaita_51.0+dfsg-1`, arch:all, trivially backportable) or accept the fallback for the two Adwaita Mono sites.
7. `apt install qt6ct papirus-icon-theme fonts-noto-cjk fonts-noto-core fonts-noto-color-emoji fonts-inter` and run `fc-cache` in the font debs' triggers (Debian fontconfig does this automatically).

**Complexity:** Medium (four or five font debs, no code).

**Issues / risks:**
- **`SpaceMono Nerd Font` is the default `Tokens.mono` and qt6ct fixed font, but Ryoku never installs it.** On Arch the name falls back through
  fontconfig. A "100% identical" port must decide whether to reproduce that fallback or ship the font (see question).
- Nerd Fonts and Material Symbols are not in Debian, so they become Ryoku-maintained font debs.

**Questions for the human:**
- SpaceMono Nerd Font: (1) do not ship it, which reproduces Arch's actual rendering via fontconfig fallback; or (2) ship nerd-fonts SpaceMono, which renders the font the code asks for but differs from current Arch boxes.

---

### systemd user units and session environment (`ryoku/shell/systemd/`, `ryoku/shell/environment.d/`)

**What it does:**
- `ryoku-shell.service` runs `/usr/bin/ryoku-shell daemon` with `QT_MEDIA_BACKEND=ffmpeg` (`systemd/user/ryoku-shell.service:16-33`).
- `ryoku-eq.service` runs `/usr/bin/pipewire -c %t/ryoku/eq/filter-chain.conf` (`:13`).
- `ryoku-bootstrap.service` runs `ryoku materialize` (`:24`).
- Other units: `ryogami`, `ryoku-idle`, `ryoku-clamshell`, `ryoku-ai-usage.{service,timer}`, `ryoku-session.target`.
- Drop-ins: `niri.service.d`, `xdg-desktop-portal-gnome.service.d`.
- The generator `60-ryoku-xdg-dirs` (`xdg-user-dir`).
- `environment.d/ryoku-session.conf` holds the session env.

**Arch couplings:**
- `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin` (`ryoku-session.conf:16`) has no sbin (see commands section).
- `QML_IMPORT_PATH/QML2_IMPORT_PATH=$HOME/.local/lib/qt6/qml` (`:13-14`). The comment at `:11` assumes `/usr/lib/qt6/qml`.

**Dependencies:** systemd (user manager, environment generators), pipewire-bin (`/usr/bin/pipewire`; filter-chain module in libpipewire-0.3-modules), xdg-user-dirs (0.18 / 0.20 / 0.19).

**As-is on Debian:** PARTIAL. All unit paths (`/usr/lib/systemd/user`, `/usr/lib/systemd/user-environment-generators`, `/usr/lib/environment.d`) exist on Debian. Only PATH needs editing.

**Port steps:** apply the PATH edit from the commands section, and update the `:11` comment for the multiarch QML path.

**Complexity:** Low.

---

### deploy.sh, dev-run.sh, dev-stop.sh (`ryoku/shell/`)

**What it does:** These scripts build and install the shell from a checkout into `~/.local` and `~/.config` (dev workflow). `dev-run.sh` builds the daemon,
`Ryoku.Blobs`, `Ryoku.Ui` and `Ryoku.FrameBars` into `~/.local/lib/qt6/qml` and runs `ryoku-shell daemon` with `RYOKU_SHELL_DIR` (`dev-run.sh:11-36`).

**Arch couplings:**
- `deploy.sh:120` suggests `sudo pacman -S quickshell`, and `deploy.sh:229` suggests `sudo pacman -S --needed go`.
- `deploy.sh:474` uses `qtver="$(pacman -Q qt6-base …)"` to stamp the Blobs build. On Debian the result is empty, so `Ryoku.Blobs` rebuilds on every deploy.
- `deploy.sh:658-710` adds `[ryoku]` to `/etc/pacman.conf`, runs `pacman-key --add/--lsign-key` and `pacman -Syu ryotunes`. All of it is skipped when `pacman` is absent (`:658`).
- `deploy.sh:429-438` installs plymouth, limine, mkinitcpio and `ryoku-boot-apply` (other report).
- Hyprland plugin builds are gated on `pkg-config --exists hyprland` (`:501`).

**Dependencies:** go, cmake, ninja, qt6-base-dev, qt6-declarative-dev, qt6-shadertools-dev (Blobs), jq, flock, systemd-run, systemd-inhibit (`deploy.sh:29,55`).

**As-is on Debian:** PARTIAL. It runs, but leaves out pacman-only steps, always rebuilds Blobs, and prints Arch install hints.

**Port steps:**
1. `deploy.sh:474`: `qtver="$(dpkg-query -W -f='${Version}' libqt6core6t64 2>/dev/null)"` (or `qtpaths6 --qt-version`).
2. `deploy.sh:120,229`: change the hint text to `apt install quickshell` / `apt install golang-go`. The Go version needed is the other report's call.
3. `deploy.sh:658-710`: add an apt branch for the Ryoku apt repo, or leave it skipped.

**Complexity:** Low.

---

### Compositor naming / Hyprland coupling in the QML (rule 2)

**What it does / findings:**
- `shell/components/CustomShortcut.qml:37` runs `Qt.createComponent("Ryoku.Wm.Hyprland", "GlobalShortcutBridge")`, and
  `shell/components/FocusGrab.qml:35` runs `Qt.createComponent("Ryoku.Wm.Hyprland", "FocusGrabBridge")`. Both name a compositor outside
  `ryoku/wm/`, which contradicts AGENTS.md rule 2. They are gated on `Wm.caps.globalShortcuts` / `Wm.caps.focusGrab`, so on niri they stay
  inert. The bridges import `Quickshell.Hyprland` (`ryoku/wm/hyprland/qml/*.qml:1`). Users: `shell/shell.qml:533-560,781-811`
  (`CustomShortcut`), `launcher/variants/hero/LauncherSurface.qml:547` (`FocusGrab`).
- No `import Quickshell.Hyprland`, `hyprctl` call or Hyprland socket access exists anywhere in `ryoku/shell/quickshell/`. Workspaces come from
  the daemon-fed `Wm` singleton (`ryoku/ui/Singletons/Wm.qml`; e.g. `qsbar/modules/WorkspaceWidget.qml:23-59`).
- Hyprland-named but compositor-neutral items:
  - `pgrep -x hypridle` (`qsbar/Theme.qml:2388`). hypridle serves ext-idle-notify on niri too (`ryoku-desktop/PKGBUILD:194-198`). Debian: trixie-bpo 0.1.8, forky/sid 0.1.8, resolute 0.1.7.
  - The cache file `~/.cache/ryoku/hypr-perf.json` (`shell/shell.qml:140-156`).
  - Welcome copy (`welcome/Welcome.qml:26`).
  - Logo options `"hyprland"` (`qsbar/Theme.qml:3009-3016`).

**As-is on Debian:** YES. This is not a Debian issue. `Ryoku.Wm.Hyprland` needs quickshell's Hyprland module, and Debian builds it (`Quickshell/Hyprland/_GlobalShortcuts`, `_FocusGrab` in the sid file list).

**Docs vs code:** `docs/barstyles.md:225-257` tells widget authors that workspaces come from `Quickshell.Hyprland` (`Hyprland.workspaces`,
`Hyprland.dispatch`) and a `Workspaces` singleton seeded from `hyprctl`. The shipped code uses `Wm.workspaces`/`Wm.focusedWorkspace`
(`qsbar/modules/WorkspaceWidget.qml:23-59`) and no `Quickshell.Hyprland`. The doc is stale. A third-party plugin written to the doc
would import `Quickshell.Hyprland`, which Debian's quickshell provides.

**Complexity:** Low.

---

## Cross-cutting findings

1. **Qt ≥6.11 is a hard requirement for an identical shell.** `RectangularShadow` needs 6.9. Its per-corner radii in the default hero launcher need 6.11. Only Debian forky/sid (6.11.2) meet this; trixie (6.8.2) and resolute (6.10.2) do not. Every QML-consuming report (Hub, lockscreen, apps, ryogami wall-ui, Ryoku.Ui) should check RectangularShadow and the other 6.9-6.11 APIs listed above.
2. **QML install path.** Every PKGBUILD that installs to `/usr/lib/qt6/qml` must use `/usr/lib/x86_64-linux-gnu/qt6/qml` on Debian: ryoku-desktop (`PKGBUILD:324-349`), ryoku-desktop-hyprland (`:87-88`) and ryoku-blobs (`:33-37`). The daemon probe at `ryoku/shell/ipc/daemon.go:411` also needs this change.
3. **Quickshell, qt6ct and anything using Qt private API must be rebuilt per Qt minor.** `ryoku doctor`'s repair path is pacman-only and hardcodes `/usr/lib/libQt6Core.so.6` (`ryoku/cli/internal/doctor/reconcile_quickshell.go:20,27,75`).
4. **Session PATH lacks `/usr/sbin`** (`ryoku/shell/environment.d/ryoku-session.conf:16`). On Debian this breaks every caller of `rfkill`, `iw` and other sbin tools, including scripts covered by other reports.
5. **`fd` → `fdfind`** affects any script that calls `fd` (the launcher's file finder here; check `ryoku/shell/scripts` and the yazi/nvim configs).
6. **`/bin/sh` is dash and default awk is mawk on Debian.** The shell QML is clean for dash; scripts in other reports need the same scan. Depend on `gawk` for Arch parity.
7. **gpk** needs `--manager apt` instead of `pacman,aur` in the launcher (`Packages.qml:217`), and a deb without `depends=('pacman')`.
8. **Package-change feed:** `/var/log/pacman.log` (bar particle) becomes `/var/log/apt/history.log`. The daemon's update check (other report) feeds `Updates.pending`.
9. **matugen 4.2.0 needs rustc ≥1.88.** Any other Rust component built for trixie also needs trixie-backports rustc (1.96).
10. **Fonts** Ryoku must ship as debs: Material Symbols (variable), JetBrainsMono/FiraCode/Hack Nerd, Space Grotesk, Fraunces, Maple Mono NF, and `fonts-adwaita` on trixie. SpaceMono Nerd Font is referenced but unshipped even on Arch.
11. `qsb` is at `/usr/lib/qt6/bin/qsb` (qt6-shader-baker) and is not on PATH on Debian (`docs/development.md:17`).
12. `waifu2x-ncnn-vulkan` (also used by "ryowalls Enhance", `ryoku-desktop/PKGBUILD:225`) has to be built. Its models path `/usr/share/waifu2x-ncnn-vulkan/models-cunet` is hardcoded (`ryoshot/Beautify.qml:147`).
13. On trixie, BlueZ 5.82 is older than Arch's. The BlueZ ≥5.83 A2DP workaround unit (`ryoku-desktop/PKGBUILD:630-637`) is then aimed at a bug trixie does not have.

## Debian package names needed by this section (master list)

```
quickshell
qml6-module-qtquick qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtqml-models
qml6-module-qtquick-window qml6-module-qtquick-effects qml6-module-qtquick-shapes
qml6-module-qtquick-layouts qml6-module-qtquick-controls qml6-module-qtquick-templates
qml6-module-qtquick-dialogs qml6-module-qt-labs-folderlistmodel
qml6-module-qt5compat-graphicaleffects qml6-module-qtmultimedia libqt6multimedia6
qml6-module-org-kde-syntaxhighlighting
qt6-svg-plugins libqt6svg6 qt6-image-formats-plugins qt6-wayland libqt6waylandclient6 qt6-qpa-plugins
qt6ct papirus-icon-theme
fonts-noto-cjk fonts-noto-core fonts-noto-color-emoji fonts-inter fonts-adwaita
fd-find rfkill iw iproute2 iwd network-manager bluez brightnessctl ddcutil upower playerctl
pulseaudio-utils pipewire-bin pipewire-pulse libpipewire-0.3-modules python3 cava
grim slurp wl-clipboard libnotify-bin xdg-utils xdg-user-dirs libglib2.0-bin trash-cli
imagemagick ffmpeg curl jq kitty btop neovim nautilus pavucontrol zenity kdialog inxi
procps util-linux coreutils findutils grep sed gawk bash systemd
nvidia-smi            (NVIDIA images only, non-free)
mako-notifier         (optional; probed only)
nodejs                (dev: .mjs unit tests)
qt6-shader-baker      (dev: qsb)
rustc cargo           (build: matugen; trixie-backports on trixie)
# build of quickshell where rebuilt:
qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev
qt6-wayland-dev qt6-wayland-private-dev qt6-shadertools-dev libcli11-dev libcpptrace-dev
wayland-protocols libwayland-dev libpipewire-0.3-dev libpam0g-dev libpolkit-agent-1-dev
libpolkit-gobject-1-dev libglib2.0-dev libdrm-dev libgbm-dev libjemalloc-dev libegl-dev
libgles-dev libvulkan-dev libxcb1-dev spirv-tools cmake ninja-build pkgconf
# build of waifu2x-ncnn-vulkan:
cmake g++ libvulkan-dev glslang-dev libwebp-dev libpng-dev libjpeg-dev
# Ryoku-built debs (not in Debian):
matugen (4.2.0)  waifu2x-ncnn-vulkan (20250915)  gpk (0.6.10)  nvibrant
fonts: material-symbols (variable), nerd-fonts JetBrainsMono/FiraCode/Hack[/SpaceMono] v3.5.1,
       space-grotesk 2.0.0, fraunces, maple-mono-nf 7.9
```

# Ryoku Hub (Settings) front end: Debian/Ubuntu port findings (ryoku @98a0368, read-only)

Paths are relative to `/home/me/src/ryokudebian-installer/ryoku/hub/quickshell/`
unless they start with `ryoku/`, `system/`, `release/` or `tests/`; those are
relative to `/home/me/src/ryokudebian-installer`. Versions are listed as trixie
/ trixie-bpo / forky / sid / resolute, with "-" meaning the package is absent.

## 0. How the Hub is launched

- **Desktop entry:** `Exec=ryoku-shell hub open`
  (`ryoku/hub/ryoku-hub.desktop:6`).
- **Keybind:** Super+comma runs `ryoku-shell hub open`
  (`ryoku/hyprland/modules/binds.lua:72`). The same entry is in the neutral
  catalogue (`ryoku/wm/binds.go:169`, id `shell.settings`), which niri renders
  through `ryoku/wm/niri/config_binds.go`.
- **The daemon verb:**
  - Selection: it uses `-c hub`, or `-p <shellDir>/../hub/quickshell` on a dev
    checkout (`ryoku/shell/ipc/control.go:138-143`).
  - Open: if a Hub is alive (`qs … ipc call nav section`), it navigates and
    raises it. Otherwise it runs `flock -n -o /tmp/ryoku-hub.lock qs -c hub` and
    then `qs -c hub ipc call nav open <section>`
    (`ryoku/shell/ipc/control.go:145-196`).
  - Close: `qs … ipc call hub close` (`control.go:197-200`).
- **IPC targets:** `nav.open/section` and `hub.close` (`shell.qml:66-80`).
- **Other launchers:**
  - `execDetached(["ryoku-shell","hub","open"])` in
    `ryoku/shell/quickshell/shell/modules/bar/framebars/menus/QsTabRail.qml:74`,
    `MenuQuickActions.qml:54` and `…/panel/PanelChat.qml:1337`.
  - A direct `flock … qs -c hub` in
    `ryoku/shell/quickshell/welcome/Welcome.qml:47`, `StepCustomize.qml:71`,
    `…/desktop/WidgetMenu.qml:118` and `…/controlcenter/ControlCenter.qml:215`.
  - ryostore `openConfig("hub","/tmp/ryoku-hub.lock",…)`
    (`ryoku/apps/ryostore/backend/routing.go:56`).
  - The updater kills it with `pkill -f "qs -c hub"`
    (`ryoku/cli/internal/updater/update.go:1931`).
- **Install layout:** the config is copied to
  `/usr/share/ryoku/config/quickshell/hub`
  (`release/packages/ryoku-desktop/PKGBUILD:274-275`) and materialised to
  `~/.config/quickshell/hub`.
- **Backend binary:** `ryoku-hub` is built by
  `release/packages/ryoku-hub/PKGBUILD:24-25`
  (`CGO_ENABLED=0 go build -mod=vendor`). `go.mod` asks for `go 1.26.4`
  (`ryoku/hub/backend/go.mod:3`). golang-1.26: - / 1.26.9 / 1.26.9 / 1.26.9 /
  1.26.8.

## 1. QML imports

None of the Hub's imports carry a version number.

| Module                                       | Cite                                                                                                              | Debian provider                                                                  | Versions                             |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------ |
| QtQuick                                      | NotesPreview.qml:2                                                                                                | qml6-module-qtquick                                                              | 6.8.2 / - / 6.11.2 / 6.11.2 / 6.10.2 |
| QtQuick.Controls                             | ColorField.qml:2                                                                                                  | qml6-module-qtquick-controls (+ -templates)                                      | same                                 |
| QtQuick.Shapes                               | MusicPreview.qml:3                                                                                                | qml6-module-qtquick-shapes                                                       | same                                 |
| QtQuick.Window                               | pages/DictationPage.qml:5                                                                                         | qml6-module-qtquick-window                                                       | same                                 |
| QtQuick.Layouts                              | ReloadCoverControl.qml:4                                                                                          | qml6-module-qtquick-layouts                                                      | same                                 |
| Qt.labs.folderlistmodel                      | pages/LauncherPage.qml:5 (also `ryoku/ui/PickFile.qml:5`)                                                         | qml6-module-qt-labs-folderlistmodel                                              | same                                 |
| QtQuick.Effects (pulled in through Ryoku.Ui) | `ryoku/ui/DitherImage.qml:2`, Watermark.qml:2, Keycap.qml:4; used at pages/ProfilePage.qml:529, InputPage.qml:594 | qml6-module-qtquick-effects                                                      | same                                 |
| Quickshell                                   | ReloadCoverControl.qml:5                                                                                          | quickshell                                                                       | - / 0.3.0 / 0.3.2 / 0.3.2 / -        |
| Quickshell.Io                                | CompositorControl.qml:5                                                                                           | quickshell                                                                       | same                                 |
| Quickshell.Wayland                           | pages/KeybindsPage.qml:8                                                                                          | quickshell                                                                       | same                                 |
| Quickshell.Networking                        | pages/ConnectionsPage.qml:7                                                                                       | quickshell (NetworkManager over D-Bus)                                           | same                                 |
| Quickshell.Bluetooth                         | pages/ConnectionsPage.qml:8                                                                                       | quickshell (BlueZ)                                                               | same                                 |
| Quickshell.WindowManager (pulled in)         | `ryoku/ui/Singletons/Wm.qml:6`                                                                                    | quickshell                                                                       | same                                 |
| Ryoku.Ui / Ryoku.Ui.Singletons               | TimezoneMap.qml:5 / WeatherPreview.qml:3                                                                          | Ryoku's own package, installed to `/usr/lib/qt6/qml/Ryoku/Ui` (PKGBUILD:331-332) | —                                    |
| Ryoku.FrameBars                              | Hub.qml:32, pages/BarStudioPage.qml:10, barstudio/NacreEditor.qml:5                                               | Ryoku's own package, `/usr/lib/qt6/qml/Ryoku/FrameBars` (PKGBUILD:347-349)       | —                                    |
| Local modules                                | Singletons/qmldir, barstudio/qmldir                                                                               | bundled with the Hub                                                             | —                                    |

- I checked the packages.debian.org file lists: both the trixie-bpo 0.3.0 and
  the sid 0.3.2 quickshell ship `/usr/bin/qs` and the module directories
  Bluetooth, Io, Networking, Wayland and WindowManager under
  `/usr/lib/x86_64-linux-gnu/qt6/qml/Quickshell/`.
- The Hub does **not** use Qt5Compat.GraphicalEffects, QtMultimedia, org.kde._,
  Quickshell.Hyprland or any Quickshell.Services._ module (grep finds none).
- Runtime plugins it needs:
  - qt6-wayland: 6.8.2 / - / 6.11.2 / 6.11.2 / 6.10.2
  - qt6-svg-plugins: same versions
  - qt6-image-formats-plugins: same versions, needed for webp lock previews
    (`AnimatedImage` at pages/LockscreenPage.qml:2123).

## 2. External commands the Hub runs (197 call sites)

**A. `ryoku-hub` backend calls.** For each subcommand, one cite, then what it
touches:

- **config get/set:** Hub.qml:56, 87, 797, 810; pages/UpdatesPage.qml:67, 73.
  Writes the hub TOML.
- **desktop:**
  - get / defaults / preview / save / restore: Hub.qml:910, 925, 942, 717,
    729/963.
  - schema / unhonored: Singletons/ProviderSchema.qml:52, 69.
  - cursors / layouts / variants: pages/InputPage.qml:48, 240, 261.
  - anim-preset: pages/AnimationsPage.qml:182, 186.
  - plugins list / rebuild / add [--inspect] / remove:
    pages/PluginsPage.qml:232, 151-153, 164, 174, 182.
- **reload-cover import / prune:** SchemaPage.qml:203, Hub.qml:753.
- **wm list / preview:** CompositorControl.qml:37, CompositorSwitchSheet.qml:38.
  The backend calls `pacman -Si` (`ryoku/hub/backend/wm.go:174`).
- **outputs:** list, profiles, apply, save, load, rm at
  pages/DisplaysPage.qml:226, 264, 627/669, 680, 688, 693.
- **gpu:**
  - caps / mode get / tune caps / tune preset list / mux get:
    pages/GpuPage.qml:234, 252, 261, 270, 289.
  - mode set / mux set / tune set|reset|preset apply|save|delete:
    GpuPage.qml:173, 178, 188-209.
  - apply enable --dry-run: GpuPage.qml:213. apply enable runs in kitty:
    GpuPage.qml:217-218. apply disable: GpuPage.qml:1095.
- **cpu active / caps / set / switch:** GpuPage.qml:332, 154, 163, 183. The
  backend wraps `ryoku-power` and `ryoku-idle`
  (`ryoku/hub/backend/cputune.go:18, 317`).
- **lock list / set:** pages/LockscreenPage.qml:548/600, 556.
- **voxtype get / set / download / rmmodel:** pages/DictationPage.qml:133, 68,
  101, 106.
- **fastfetch:** get, reset, preview, save, import-logo, dither-logo,
  remove-logo at pages/FastfetchPage.qml:132, 213, 394, 440, 477, 516, 535.
- **Others:**
  - `import scan / apply - / undo`: pages/ImportPage.qml:266, 290, 297. Scanning
    a URL uses `git clone` (`ryoku/hub/backend/import.go:170`); apply takes a
    snapper snapshot (`import_apply.go:348-349`).
  - `keybinds`, `apps`, `shell get/set/prompt`: pages/KeybindsPage.qml:63, 82,
    98, 124, 132. `shell apply` runs `usermod -s` (`shellpref.go:241`).
  - `clipboard stats/prune`: pages/DesktopPage.qml:115, 138.
  - `profile export/import`: pages/ProfilePage.qml:1006, 1018.
  - `share status`: pages/RecordingPage.qml:385 (uses `busctl --user`).
  - `lighting <args>`: pages/LightingTab.qml:76. **This file is not referenced
    anywhere**: it is missing from the page map at Hub.qml:490-495 and nothing
    else names it.

### B. ryoku CLI and Ryoku helper calls

- **`ryoku`:**
  - `update` in kitty: UpdatesPage.qml:228
  - `rollback <snap>` in kitty: UpdatesPage.qml:215
  - `wm use <t> --keep-previous|--remove-previous`:
    CompositorSwitchSheet.qml:121, 126-129
  - `wm act session.exit`: CompositorSwitchSheet.qml:132
  - `wm act input.touchpad status|on|off`: InputPage.qml:71, 82
  - `keyboard apply <layout>`: InputPage.qml:308
  - `keyring status --json / set …`: LockscreenPage.qml:657, 294, 303, 312
  - `security-key status --json / enroll (terminal) / remove / set`:
    LockscreenPage.qml:709, 326, 335, 344, 353, 362
  - `doctor`: RecordingPage.qml:402
- **`ryoku-shell`:** `theme catalog` (Singletons/UserSchemes.qml:25);
  `bar settings` (pages/BarStudioPage.qml:231).
- **`ryostore`:**
  - open plugins|bundles|barstyles|lockscreens|fastfetch: AddonsPage.qml:88,
    BarStudioPage.qml:58, LockscreenPage.qml:543, FastfetchPage.qml:100
  - catalog --category …: AddonsPage.qml:176, 187; BarStudioPage.qml:82;
    FastfetchPage.qml:153
  - internal install-guest/remove-guest: AddonsPage.qml:125, 154
  - install barstyles: BarStudioPage.qml:71
  - internal apply-fastfetch / remove fastfetch / remove fastfetch-emblems:
    FastfetchPage.qml:52, 64, 86
- **`ryostore-install remove item|bundle`** in kitty: AddonsPage.qml:92.
- **`ryoku-plugins-place`:** AddonsPage.qml:131, 143; WidgetsPage.qml:504.
  **`bash <shell>/quickshell/plugins/discover.sh --all`:** AddonsPage.qml:162,
  WidgetsPage.qml:510.
- **`ryoku-rashin`:** status/paths --json, enable/disable, setup (kitty), serve,
  wire, agent use at RashinPage.qml:98, 195, 144, 168, 182-186, 214-216;
  `paths --snippet | wl-copy` at RashinPage.qml:218.
- **`ryoku-sysinfo` / `ryoku-profile-stats`** (run through bash):
  Singletons/SysInfo.qml:60, 94.
- **`ryoku-cmd-screenrecord --info`:** RecordingPage.qml:409.
  **`ryoku-fastfetch`:** FastfetchPage.qml:486. **`ryoku-i18n llm`:**
  SettingsSheet.qml:480-481.
- **`pkexec /usr/bin/ryoku-network-kill status|on|off`:**
  ConnectionsPage.qml:69, 95.
  **`[pkexec] ryoku-wifi-backend get|iwd|wpa_supplicant`:**
  ConnectionsPage.qml:809, 517.
- **`ryoku-qylock-lock <slug>`** (preview): LockscreenPage.qml:41, 560.
- **`qs -c shell ipc call …`:** SettingsSheet.qml:485,
  RecordingPage.qml:318-329.

### C. System tools

| Tool                                                                                                                     | Cites                                                                                                                | Debian package                                  | Versions                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| nmcli                                                                                                                    | ConnectionsPage.qml:507, 634, 650, 687, 692, 732, 770, 1864-1872, 1926, 1935, 1943                                   | network-manager                                 | 1.52.1 / - / 1.58.1 / 1.58.1 / 1.54.3                                                                        |
| bluetoothctl                                                                                                             | ConnectionsPage.qml:1430-1431                                                                                        | bluez                                           | 5.82 / - / 5.87 / 5.87 / 5.85                                                                                |
| rfkill                                                                                                                   | ConnectionsPage.qml:1496                                                                                             | rfkill                                          | 2.41.5 / - / 2.42.4 / 2.42.4 / 2.41.3                                                                        |
| systemctl (`--user restart ryoku-shell.service`; `pkexec systemctl enable --now bluetooth.service`), timedatectl, busctl | GlobalPage.qml:83; ConnectionsPage.qml:1504; GlobalPage.qml:61, 78; LockscreenPage.qml:857                           | systemd                                         | 257.13 / - / 262 / 262.1 / 259.9                                                                             |
| pkexec                                                                                                                   | ConnectionsPage.qml:69, 95, 517, 1504; LockscreenPage.qml:159                                                        | pkexec (a separate package on Debian) + polkitd | 126 / - / 127 / 128 / 127                                                                                    |
| fprintd-list / -enroll / -verify / -delete                                                                               | LockscreenPage.qml:775, 451, 459, 467                                                                                | fprintd                                         | 1.94.5 (all suites)                                                                                          |
| xdg-open                                                                                                                 | Hub.qml:595, PluginsPage.qml:185, RashinPage.qml:179                                                                 | xdg-utils                                       | 1.2.1                                                                                                        |
| kitty (12 sites); `${TERMINAL:-kitty}`                                                                                   | e.g. UpdatesPage.qml:228; LockscreenPage.qml:326                                                                     | kitty                                           | 0.41.1 / - / 0.48.2 / 0.48.2 / 0.45.0                                                                        |
| nvim                                                                                                                     | FastfetchPage.qml:484, 487                                                                                           | neovim                                          | 0.10.4 / - / 0.12.4 / 0.12.4 / 0.11.6                                                                        |
| fc-list                                                                                                                  | GlobalPage.qml:48, WidgetsPage.qml:94                                                                                | fontconfig                                      | 2.15.0 / - / 2.17.1 / 2.17.1 / 2.17.1                                                                        |
| curl (open-meteo geocoding)                                                                                              | SettingsSheet.qml:998                                                                                                | curl                                            | 8.14.1 / 8.21.0 / 8.22 / 8.23 / 8.18                                                                         |
| wl-copy                                                                                                                  | RashinPage.qml:218                                                                                                   | wl-clipboard                                    | 2.2.1 / 2.3.0 / 2.3.0 / 2.3.0 / 2.2.1                                                                        |
| sensors                                                                                                                  | Singletons/LiveStats.qml:59                                                                                          | lm-sensors                                      | 3.6.2                                                                                                        |
| nvidia-smi                                                                                                               | LiveStats.qml:69, GpuPage.qml:403                                                                                    | nvidia-smi (non-free)                           | 550.163.01-2 / 550.163.01-4~bpo13+1 / 550.163.01-5.1 / 550.163.01-5.1; resolute: nvidia-utils-580 580.178.04 |
| `/usr/share/zoneinfo/zone1970.tab`                                                                                       | TimezoneMap.qml:79                                                                                                   | tzdata                                          | 2026c / - / 2026e                                                                                            |
| env, date, stat, cat, ls, cp, mkdir, grep                                                                                | TimezoneMap.qml:53, ProfilePage.qml:47, HeroEditor.qml:70, FastfetchPage.qml:301, LockscreenPage.qml:413/426/766/808 | coreutils                                       | 9.7 / - / 9.10 / 9.10 / 9.7                                                                                  |
| `pkexec bash -c "sed -i …"` on /etc/pam.d                                                                                | LockscreenPage.qml:145-159                                                                                           | —                                               | —                                                                                                            |
| flock (launcher)                                                                                                         | control.go:179                                                                                                       | util-linux                                      | 2.41.5 / - / 2.42.4 / 2.42.4 / 2.41.3                                                                        |

## 3. Arch couplings (with cites)

- **pacman (UI text and comments):** UpdatesPage.qml:559, 591-595 (shown to the
  user: "Take them with: sudo pacman -Syu"); Singletons/Updates.qml:26;
  CompositorSwitchSheet.qml:14, 46, 94, 110-118 ("reversible pacman
  transaction"; sizes named the way pacman's removal summary names them).
- **pacman in the logic the Hub calls:**
  - `ryoku status --json` comes from `ryoku/shell/ipc/updates.go:71`. Underneath
    it runs `checkupdates` (`ryoku/cli/internal/updater/update.go:1698-1724`),
    `yay -Qua` (`update.go:1726-1744`), `pacman -Q ryoku-desktop`
    (`ryoku/cli/internal/sys/sys.go:58-67`) and `pacman -Sl ryoku`
    (`update.go:1675-1688`).
  - Package counts: `pacman -Qq` (`ryoku/shell/scripts/ryoku-sysinfo:71`);
    `pacman -Qen` / `pacman -Qm`
    (`ryoku/shell/scripts/ryoku-profile-stats:51-52`).
  - Install date: `/var/log/pacman.log` (ProfilePage.qml:47).
  - Compositor availability: `pacman -Si` (`ryoku/hub/backend/wm.go:171-174`).
  - Passthrough packages: `pacman -S --needed` / `-Q`
    (`ryoku/hub/backend/gpuapply.go:203, 215, 303-310`).
- **AUR, yay, paru, GlazePKG:**
  - DictationPage.qml:110-122 runs `gpk install voxtype-bin --manager aur` and
    `gpk remove voxtype-bin`; the UI text is at DictationPage.qml:270, 667.
  - ProfilePage.qml:763 shows "%2 AUR".
  - gpuapply.go:40-42, 68-95 builds AUR packages through ryoku-pkg-aur-add, yay
    or paru, and prints "try: yay -S".
  - `system/extras/ryostore-install:283-353` installs AUR packages via
    `ryoku-pkg-aur-add`.
- **ryostore-install, ryoku-pkg-\*, multilib, CachyOS:**
  - AddonsPage.qml:92 and schema/AddonsPage.js:58 call
    `ryostore-install remove`.
  - ryostore-install uses `pacman -Qq/-Si` (lines 85-100) and runs
    `ryoku-pkg-multilib` and `ryoku-pkg-cachyos` (lines 250, 258).
  - The bundle "installed" state comes from `ryostore-install status`
    (`ryoku/apps/ryostore/backend/provider_bundles.go:179`).
- **mkinitcpio:** InputPage.qml:303 (comment);
  `ryoku/cli/internal/keyboard/keyboard.go:14-17, 195, 268-272`
  (`mkinitcpio -P`, boot-image globs `/boot/EFI/Linux/*.efi` and
  `/boot/initramfs-*.img`).
- **snapper / Limine:** UpdatesPage.qml:212-216, 874-891 (ROLL BACK);
  `update.go:23, 63-160, 344, 1121-1124`.
- **CachyOS / Arch in UI text:** CreditsPage.qml:37-38 ("opinionated Arch",
  "performance Arch"); UpdatesPage.qml:591 (comment). Kernel switching to
  CachyOS is reachable only through RyoStore bundles (`docs/kernels.md:3`), not
  through a Hub page.
- **base-devel:** PluginsPage.qml:357.
- **Not present in the Hub QML:** reflector, rate-mirrors, mirrorlist,
  archlinux-keyring, pacman.conf, `/etc/os-release` checks, chaotic-aur, scx
  schedulers, kernel pickers. ryoku-sysinfo only reads `PRETTY_NAME` for display
  (`ryoku-sysinfo:58`).
- **`ryoku doctor`**, which RecordingPage.qml:402 runs, calls `pacman -Sy`
  (`ryoku/cli/internal/doctor/doctor.go:1091`) and has a multilib reconciler
  (`reconcile_multilib.go:56`).

## 4. Arch concepts per page

| Page                               | file:line                                                                                                 | Concept                                                                                                                             | What it does                                                                                        | Debian/Ubuntu replacement                                                                                                                                                                                                                                                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Updates                            | UpdatesPage.qml:559-603                                                                                   | pacman, distro lane                                                                                                                 | Lists SYSTEM PACKAGES; tells the user "sudo pacman -Syu"                                            | "sudo apt update && sudo apt full-upgrade". Backend: replace checkupdates with an unprivileged private-state `apt-get update` + `apt-get -s dist-upgrade`, or PackageKit `pkcon get-updates`. Drop the AUR lane, or map it to third-party origins (backports, extrepo, PPA). |
| Updates (singleton)                | Singletons/Updates.qml:26, 49, 65; update.go:1675-1744; sys.go:58                                         | checkupdates, yay -Qua, pacman -Q/-Sl                                                                                               | Decides whether an update is available and fills the package list                                   | `dpkg-query -W -f='${Version}' ryoku-desktop`; candidate from `apt-cache policy ryoku-desktop` (Ryoku apt repo)                                                                                                                                                              |
| Updates                            | UpdatesPage.qml:215, 875-889                                                                              | snapper + Limine snapshots                                                                                                          | ROLL BACK runs `ryoku rollback`                                                                     | snapper 0.10.6 exists in Debian. limine and grub-btrfs are absent from every suite, so the boot-menu entries need vendoring or the button must hide.                                                                                                                         |
| Profile                            | ProfilePage.qml:47                                                                                        | pacman.log                                                                                                                          | Install-date fallback                                                                               | `/var/log/installer/`, or the oldest of `/var/lib/dpkg/info` / dpkg.log; keep `stat %W` first                                                                                                                                                                                |
| Profile                            | ProfilePage.qml:752-763; SysInfo.qml:52-53, 107-108                                                       | pacman counts, AUR                                                                                                                  | "N EXPLICIT · N AUR · N TOTAL"                                                                      | `dpkg-query` count of installed packages; `apt-mark showmanual`; "AUR" becomes local/foreign packages (`apt list '?obsolete'`) or non-Debian origin. The i18n key changes.                                                                                                   |
| Dictation                          | DictationPage.qml:110-122, 270, 287, 667, 679                                                             | GlazePKG + AUR voxtype-bin                                                                                                          | Install/Remove Voxtype in a terminal                                                                | voxtype is in no Debian or Ubuntu suite. Ship a deb in the Ryoku apt repo and use `sudo apt install voxtype` in the terminal. (whisper.cpp exists only in forky/sid 1.9.5 and resolute 1.8.3.)                                                                               |
| Plugins                            | PluginsPage.qml:13-15, 357; `ryoku/wm/hyprland/config_plugins_tier.go:648-659`                            | base-devel, "hyprland package" headers                                                                                              | Toolchain gate; backend checks git, make, c++, pkg-config, cmake and `pkg-config --exists hyprland` | build-essential, cmake, git, pkg-config, hyprland-dev (- / 0.55.2 / 0.56.2 / 0.56.2 / 0.53.3). Whether hyprland-dev provides `hyprland.pc` is not verified.                                                                                                                  |
| Add-ons (Bundles tab)              | AddonsPage.qml:86-93, 185-199; schema/AddonsPage.js:58                                                    | pacman, AUR, multilib, CachyOS (through ryostore-install)                                                                           | Remove a component or bundle; installed counts                                                      | Port ryostore-install to apt. The AUR route becomes the Ryoku apt repo or upstream .deb. multilib becomes `dpkg --add-architecture i386`. Drop the cachyos route (or use an extrepo kernel).                                                                                 |
| Window Manager / compositor switch | CompositorSwitchSheet.qml:14, 46, 94, 110-129, 338, 369-370; CompositorControl.qml:145; wm.go:16, 150-174 | pacman transaction, `pacman -Si`, pacman size format                                                                                | Switches compositor and optionally removes the old one                                              | `apt-get install` / `remove` + `autoremove`; `apt-cache policy` for availability; Installed-Size from `dpkg-query` (KiB)                                                                                                                                                     |
| Graphics & Power                   | GpuPage.qml:212-222, 1062, 1135; gpuapply.go:68-95, 203-226, 303-310; hwcaps.go:280                       | pacman `qemu-desktop libvirt edk2-ovmf swtpm dnsmasq`; AUR looking-glass + looking-glass-module-dkms; hint "pacman -S qemu-desktop" | Passthrough plan and enable                                                                         | qemu-system-x86, libvirt-daemon-system, ovmf, swtpm, dnsmasq-base. looking-glass-client is sid-only (0+b7). kvmfr needs a Ryoku-built DKMS deb (dkms 3.2.2 is available).                                                                                                    |
| Input                              | InputPage.qml:295-312, 961-982; keyboard.go:195, 268-272                                                  | mkinitcpio, vconsole.conf, `/boot/initramfs-*.img`                                                                                  | "Login screen, TTY, and boot" apply                                                                 | `update-initramfs -u -k all`; initrd glob `/boot/initrd.img-*`. Debian's console keymap is console-setup (`/etc/default/keyboard`); whether localed writes it is not verified.                                                                                               |
| Lockscreen                         | LockscreenPage.qml:124-160, 929-967, 1313-1381                                                            | AUR pam_fprintd_grosshack at `/usr/lib/security`; edits `/etc/pam.d/{sudo,sddm,polkit-1}`                                           | Fingerprint for sudo, SDDM and polkit                                                               | Debian's module dir is `/usr/lib/x86_64-linux-gnu/security`. grosshack is not packaged: build it, or use stock pam_fprintd via a pam-auth-update profile (`/usr/share/pam-configs/fprintd`). Debian polkitd ships `/usr/lib/pam.d/polkit-1`, not `/etc/pam.d/polkit-1`.      |
| Lockscreen                         | LockscreenPage.qml:1442, 1494, 1823                                                                       | pam-u2f package name                                                                                                                | "Install pam-u2f"                                                                                   | libpam-u2f + pamu2fcfg (1.4.0)                                                                                                                                                                                                                                               |
| Credits                            | CreditsPage.qml:37-38                                                                                     | "opinionated Arch", "performance Arch"                                                                                              | Credits                                                                                             | Cosmetic: reword and add a Debian credit                                                                                                                                                                                                                                     |
| Recording                          | RecordingPage.qml:402                                                                                     | `ryoku doctor` (pacman -Sy, multilib)                                                                                               | Repair screen sharing                                                                               | Port the doctor reconcilers                                                                                                                                                                                                                                                  |
| General (timezone) / Connections   | GlobalPage.qml:85-91; ConnectionsPage.qml:67-104, 512-518, 819                                            | polkit rules keyed on `isInGroup("wheel")` (`system/policy/52-ryoku-timedate.rules`, `system/hardware/network/51-…, 55-….rules`)    | No-prompt pkexec                                                                                    | The Debian/Ubuntu admin group is `sudo`                                                                                                                                                                                                                                      |
| Rashin                             | RashinPage.qml:584                                                                                        | Package name                                                                                                                        | "install ryoku-rashin"                                                                              | Same name as a deb                                                                                                                                                                                                                                                           |

All of these English strings are i18n keys. Each Arch-specific key (for example
"sudo pacman -Syu", "voxtype-bin … GlazePKG", "Install base-devel", "performance
Arch", "Fingerprint at the greeter too (SDDM)") appears in 35 of the 37 catalogs
in `ryoku/i18n/catalog/*.json`, so every rewording needs a catalog regeneration.

## 5. Lockscreen and Session pages

- **Skin pick** (LockscreenPage.qml:551-558) runs `ryoku-hub lock set <slug>`
  (`ryoku/hub/backend/lock.go:340-356`):
  - It first writes the user's choice to `~/.config/qylock/theme`
    (lock.go:78-80, 359-368). Themes live in `~/.local/share/qylock/themes`
    (lock.go:74-76).
  - It then runs `pkexec <self> lock apply-greeter <slug>` (lock.go:396-411).
    That copies the theme to `/usr/share/sddm/themes/ryoku`, chowns it root and
    makes it world-readable, and atomically writes
    `/etc/sddm.conf.d/99-ryoku.conf` with `[Theme]\nCurrent=ryoku`
    (lock.go:370-385, 443-472). Both paths can be overridden with
    `RYOKU_SDDM_THEMES_DIR` and `RYOKU_SDDM_CONF`.
  - This is the only helper in the Hub path that writes `/etc/sddm.conf.d`.
  - Preview runs `ryoku-qylock-lock <slug>` (LockscreenPage.qml:41, 560).
  - Debian's sddm (0.21.0+git) ships `sddm-greeter-qt6`, `/etc/pam.d/sddm` and
    `/usr/share/sddm/themes`. qylock metadata declares `QtVersion=6`
    (`ryoku/lockscreen/qylock/themes/clockwork/orbital/metadata.desktop`).
- **Keyring:** `ryoku keyring status/set` (LockscreenPage.qml:294-313, 657). It
  escalates through pkexec (`ryoku/cli/internal/keyring/keyring.go:7`) and edits
  `pam_gnome_keyring` in `/etc/pam.d/sddm` (schema/LockscreenPage.js:34;
  `keyring/reconcile.go:64`). Debian packages: gnome-keyring and
  libpam-gnome-keyring, 48.0 / - / 51.1 / 51.1 / 50.0.
- **Security key:** `ryoku security-key …`. It edits `/etc/pam.d` with
  `pam_u2f.so` through `pkexec … security-key apply-pam`
  (`ryoku/cli/internal/securitykey/pam.go:18, 52, 208`) and needs `pamu2fcfg`
  (`enroll.go:21`).
- **Fingerprint:**
  - Runs as the user: fprintd-* and busctl.
  - User files: `~/.config/qylock/fingerprint` and `fingerprints.json`
    (LockscreenPage.qml:411-426, 766, 808).
  - The root half is `pkexec bash -c` doing
    `cp f f.ryoku-fp-bak; sed -i "1i auth sufficient pam_fprintd_grosshack.so"`
    on `/etc/pam.d/sudo|sddm|polkit-1` (LockscreenPage.qml:133-160).
  - The section only appears if `/usr/lib/security/pam_fprintd_grosshack.so`
    exists (LockscreenPage.qml:933, 1315). Doctor checks the same path
    (`ryoku/cli/internal/doctor/reconcile_fingerprint.go:37`).
- **SessionPage** (pages/SessionPage.qml:8-16, 33-85) only edits
  `desktop.autostart` and `desktop.env` in the draft store; Save goes through
  `ryoku-hub desktop save` (Hub.qml:717) into `desktop.json` and regenerates
  settings.lua. There is **no** greeter, autologin or sddm handling anywhere in
  the Hub (grep for autologin, greetd and sddm.conf finds nothing).

## 6. Displays, Graphics & Power, Performance

- **Displays:**
  - Commands: `ryoku-hub outputs …` only (DisplaysPage.qml:226-693), plus
    `Settings.patch("displays.ui_scale.*")` (DisplaysPage.qml:92). Output state
    goes through the compositor seam; the page never names hyprctl or niri.
  - System file: the backend writes `/var/lib/ryoku/greeter-primary` as mode
    0666 from the user session (`ryoku/hub/backend/outputs.go:187-194`). The
    installer must create it.
  - Untouched: kernel cmdline, modprobe.d, ddcutil.
- **Graphics & Power:**
  - Render mode goes to `ryoku-gpu mode`, which writes `~/.config/hypr/gpu.lua`
    or `niri/gpu.kdl` (`AQ_DRM_DEVICES`; gpumode.go:1-6, 48;
    `system/hardware/gpu/ryoku-gpu:37-39`).
  - MUX goes to `ryoku-gpu-mux` (gpumux.go:53-79), which writes firmware knobs
    under `/sys/class/firmware-attributes` or `/sys/devices/platform` and
    re-execs itself via pkexec (`ryoku-gpu-mux:36-37, 131-132`).
  - Tuning is runtime sysfs plus `nvidia-smi -pl/-pm/-lgc/-rgc/-rmc`
    (gputune.go:285-407).
  - CPU and battery go to `ryoku-power`, which coexists with
    power-profiles-daemon (`powerprofilesctl get`). It owns
    `charge_control_end_threshold`, `/sys/module/pcie_aspm/parameters/policy`,
    EPP, `scaling_governor` and `scaling_max_freq`, escalates with pkexec under
    rule 47, and persists to `power.json`
    (`system/hardware/power/ryoku-power:3-21, 38-39, 373-444`). Idle settings go
    to `ryoku-idle apply`.
  - Passthrough enable/disable (as root via pkexec) writes
    `/etc/modules-load.d/ryoku-kvmfr.conf`, `/etc/modprobe.d/ryoku-kvmfr.conf`,
    `/etc/udev/rules.d/99-ryoku-kvmfr.rules`,
    `/etc/polkit-1/rules.d/50-ryoku-libvirt.rules` and
    `/etc/libvirt/hooks/qemu`. It runs `gpasswd -a libvirt/kvm`,
    `systemctl enable --now libvirtd.socket`, `udevadm control --reload-rules`
    and `virsh net-autostart default`, and the hook runs `modprobe vfio-pci`
    (gpuapply.go:165-176, 244-252; gpuhook.go:45-132).
  - The header claims the backend "adds the kernel cmdline token"
    (gpuapply.go:7), but no code writes a cmdline; that comment is stale.
  - power-profiles-daemon: 0.30 / - / 0.30 / 0.30 / 0.30.
- **Performance:** it only writes `~/.config/ryoku/performance.json` and calls
  `wmAct("config.reload")` (PerformancePage.qml:178-190; Hub.qml:503). There is
  no scx, cpupower, tuned or ppd call anywhere in the Hub or its backend (grep
  finds none).

## 7. Updates singleton

- **Feed:** a Unix socket at `$XDG_RUNTIME_DIR/ryoku-shell.sock`
  (`subscribe updates`; Updates.qml:11, 79-92). "Check again" sends
  `call updates.check {}` (Updates.qml:49, 71-77).
- **Daemon:** runs `ryoku status --json` with a 5-minute timeout, at startup and
  then on the interval (off / hourly / daily / weekly) set by `update_interval`
  in the hub TOML (`ryoku/shell/ipc/updates.go:23-100`). The page also re-checks
  on its own timer (UpdatesPage.qml:95-100).
- **"available":** set from the JSON `available` field (Updates.qml:56-66). It
  concerns the Ryoku lane only.
  - On a checkout it comes from the git channel.
  - On a packaged box it compares `pacman -Q ryoku-desktop` with
    `pacman -Sl ryoku` and checkupdates, and reads release names from
    `/etc/ryoku-release` and the channel's `release.json` (update.go:1525-1600;
    `ryoku/cli/internal/sys/release.go:41`).
  - `packages` (the distro lane: checkupdates + `yay -Qua`) is informational and
    never sets `available` (update.go:1543-1547, 1571-1578).
- **Update button:** runs `kitty -e sh -c "exec ryoku update"`
  (UpdatesPage.qml:227-229, 1000-1004). Progress is read from
  `$XDG_RUNTIME_DIR/ryoku-update.json` (watched FileView), prompts are answered
  through `$XDG_RUNTIME_DIR/ryoku-update-answer`, and the owning PID is probed
  with `kill -0` (UpdatesPage.qml:114-205). `ryoku update` itself is a snapper
  pre/post pair around the pacman work (update.go:63-160).

## 8. Node tests

- **Files:** `Combos.test.mjs`, `ReloadCoverModel.test.mjs`,
  `barstudio/BarStudioModel.test.mjs`,
  `schema/{KeybindsPage,WidgetsPage,DesktopPage}.test.mjs`,
  `pages/lib/arrange.test.mjs`.
- **Runner:** `tests/shell-unit-tests.sh` runs each file as plain `node <file>`,
  not `node --test`, and finds every `ryoku/{shell,hub,ui}/**/*.test.mjs`.
- **Where it runs:** only in CI, `.github/workflows/shell-unit-tests.yml` with
  node-version 20. The git hooks do **not** run it (`.githooks/pre-commit:57-65`
  and `pre-push` run slop, delivery, wm-isolation and pkgbuild checks only).
  `docs/development.md:54` mentions only qmllint.
- **Node features used:** `node:test`, `node:assert/strict`, `node:vm`
  (`createContext`/`runInContext` over the `.pragma library` JS), `node:fs` with
  `new URL(…, import.meta.url)`, and `createRequire` (e.g. Combos.test.mjs:1-41,
  ReloadCoverModel.test.mjs:1-6). No import attributes. Node 20 or later is
  enough.
- **nodejs versions:** 20.19.2 / - / 24.21.0 / 24.22.0 / 22.22.1.

## 9. Fonts

| Font                                      | Cite                                                       | Shipped how                                                                           | Debian/Ubuntu                                                                        |
| ----------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Archivo Black                             | `fonts/archivo-black.ttf`; FontLoader at RashinPage.qml:50 | Bundled with the Hub                                                                  | —                                                                                    |
| Space Grotesk (Tokens.ui)                 | `ryoku/ui/Singletons/Tokens.qml:106`; MusicPreview.qml:62  | Arch: `otf-space-grotesk` from [ryoku] (`system/packages/base.packages:313-318`)      | fonts-space-grotesk only in resolute (2.0.0); vendor it for Debian                   |
| Fraunces (Tokens.display)                 | Tokens.qml:105; MusicPreview.qml:173                       | AUR `ttf-fraunces-variable` (`system/packages/aur.packages:52`)                       | Absent everywhere; vendor (OFL)                                                      |
| SpaceMono Nerd Font (Tokens.mono default) | Tokens.qml:107; also `ryoku/shell/ipc/matugen.go:1645`     | **No package ships it at this commit** (the Arch build falls back through fontconfig) | Absent; vendor it or change the default                                              |
| Noto Sans CJK JP (Tokens.jp)              | Tokens.qml:108                                             | noto-fonts-cjk                                                                        | fonts-noto-cjk 20240730 (all suites)                                                 |
| Inter / Inter Display                     | StatsPreview.qml:33; AioPreview.qml:75                     | inter-font                                                                            | fonts-inter 4.1 (all). That it includes the "Inter Display" family is not verified.  |
| JetBrainsMono Nerd Font                   | ClockPreview.qml:102                                       | ttf-jetbrains-mono-nerd                                                               | Debian has only the non-Nerd fonts-jetbrains-mono 2.304; vendor the Nerd build       |
| Material Symbols Rounded                  | WeatherPreview.qml:20, AioPreview.qml:43                   | ttf-material-symbols-variable                                                         | Absent everywhere (fonts-material-design-icons-iconfont is Material _Icons_); vendor |

Also in the PKGBUILD font list (PKGBUILD:164-173): noto-fonts maps to
fonts-noto-core 20201225, and noto-fonts-emoji maps to fonts-noto-color-emoji
2.051.

## 10. Risks and cross-cutting findings

1. **QML import path.** Ryoku.Ui, Ryoku.FrameBars and PluginKit install to
   `/usr/lib/qt6/qml` (PKGBUILD:324-349). Debian's Qt6 QML directory is
   `/usr/lib/x86_64-linux-gnu/qt6/qml` (confirmed from the quickshell file
   lists). Left as is, every Ryoku import fails; PKGBUILD:344-346 says that
   leaves no shell at all. Install to the QML directory reported by `qtpaths6`
   instead. Note that `ryoku/hyprland/modules/env.lua:66-79` only adds
   `~/.local/lib/qt6/qml`.
2. **Quickshell availability.** It is not in trixie main or resolute. trixie-bpo
   has 0.3.0 and forky/sid have 0.3.2, both built against Debian's Qt (6.8.2 on
   trixie, versus Arch's newer Qt). Resolute needs a PPA or Ryoku-built package.
   I found no Qt API newer than 6.8 in the Hub, but that is a grep, not a
   qmllint run against Qt 6.8.
3. **polkit `wheel` group.** The rules for network-kill, timedate, wifi-backend,
   power and gpu-mux grant no-password pkexec to group `wheel`
   (`system/**/4x-5x-*.rules`; comments at ConnectionsPage.qml:512, 819). Debian
   and Ubuntu use `sudo`.
   - ConnectionsPage.qml:69 runs `pkexec … ryoku-network-kill status` as soon as
     the page loads (`running: true`), so on Debian every visit to Connections
     would ask for a password.
   - pkexec is a separate package on Debian and must be a dependency.
4. **PAM paths.**
   - The grosshack check looks in `/usr/lib/security`; Debian's PAM modules are
     in `/usr/lib/x86_64-linux-gnu/security`.
   - `/etc/pam.d/polkit-1` does not exist on Debian (polkitd ships
     `/usr/lib/pam.d/polkit-1`, checked against the trixie file list). The
     polkit "on" toggle would fail and its status would always read off.
   - Using `sed -i "1i"` on Debian PAM files works against the pam-auth-update
     model.
5. **Wi-Fi backend default.** `ryoku-wifi-backend get` treats "no drop-in" as
   iwd (`system/hardware/network/ryoku-wifi-backend:26-28`). Debian's
   NetworkManager defaults to wpa_supplicant, so the page would report the wrong
   backend unless the installer pins iwd.
6. **Name collision with `pacman`.** Debian has a `pacman` game (10-21, in
   `/usr/games`, which is on users' PATH) and `pacman-package-manager` (7.0.0).
   Any presence check like `command -v pacman`, `sys.Has` or `LookPath`, and
   `pacman -Qq` in ryoku-sysinfo:71, could misfire. Gate on the distro, not on
   the binary.
7. **Missing in Debian/Ubuntu:** voxtype, gpk, limine, grub-btrfs,
   pam-fprintd-grosshack, looking-glass-module-dkms, matugen.
   looking-glass-client is sid-only; gpu-screen-recorder (used by
   ryoku-cmd-screenrecord) is forky/sid only (5.13.8); openrgb is
   forky/sid/resolute only; asusctl is absent.
8. **Hardcoded terminal.** kitty is hardcoded at 11 of 12 sites; only
   LockscreenPage.qml:326 respects `$TERMINAL`. trixie's kitty is 0.41.1.
9. **Dead code.** `pages/LightingTab.qml` is unreferenced at this commit and can
   be left out of the port.
10. **Tooling bug in the port repo.** `tools/pkgver` only matches suites exactly
    named `stable`, `testing`, etc., so it misses `stable/non-free` and contrib.
    That is why nvidia-smi showed "-". I got its real versions from madison by
    hand (listed above).
11. **Stale comment.** The "kernel cmdline token" claim at gpuapply.go:7 is not
    implemented anywhere.
12. **Not checked:** I did not run anything; no QML was linted or launched.

## Files referenced

Paths relative to `/home/me/src/ryokudebian-installer`.

- Hub front end:
  - `ryoku/hub/quickshell/` — Hub.qml, shell.qml, pages/_.qml,
    Singletons/{Updates,SysInfo,LiveStats,Settings}.qml,
    CompositorSwitchSheet.qml, schema/_.js, *.test.mjs
  - `ryoku/hub/ryoku-hub.desktop`
- Hub backend:
  `ryoku/hub/backend/{lock,gpuapply,gpuhook,gpumode,gpumux,gputune,cputune,hwcaps,outputs,wm,shellpref,import,import_apply}.go`
- Launch and update daemon: `ryoku/shell/ipc/{control,updates}.go`
- ryoku CLI: `ryoku/cli/internal/updater/update.go`,
  `ryoku/cli/internal/sys/sys.go`, `ryoku/cli/internal/keyboard/keyboard.go`
- Helper scripts: `ryoku/shell/scripts/{ryoku-sysinfo,ryoku-profile-stats}`,
  `system/extras/ryostore-install`, `system/hardware/{network,power,gpu}/*`
- Packaging: `release/packages/{ryoku-desktop,ryoku-hub}/PKGBUILD`
- Tests: `tests/shell-unit-tests.sh`, `.github/workflows/shell-unit-tests.yml`
- Shared UI: `ryoku/ui/Singletons/Tokens.qml`
- Package sets: `system/packages/{base,aur}.packages`

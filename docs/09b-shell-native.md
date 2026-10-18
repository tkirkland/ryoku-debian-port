# 09b: Shell native components and helper scripts

Scope: everything under `ryoku/shell/` that is compiled or executed outside QML,
plus the separately packaged native apps the shell drives: the `ryoku-shell` Go
daemon (`ryoku/shell/ipc`, including its GNOME keyring prompter, polkit agent,
clipboard, lock and control socket), the `Ryoku.Blobs` C++ QML plugin
(`ryoku/shell/plugin`), the C video-wallpaper player (`ryoku/shell/livewall`,
shipped twice as `ryoku-livewall` and `ryogami-live`), the Ryogami wallpaper
daemon and its QML picker (`ryoku/shell/ryogami`), the palette bridge
(`ryoku/palette-bridge`), every helper script in `ryoku/shell/scripts` and
`ryoku/shell/bin`, the shell's systemd user units / `environment.d` / generator,
and the two external native apps the shell hands off to: `ryomotion` (Electron)
and `ryotunes` (Tauri, prebuilt externally). Source pinned at
`98a0368253d9628be72b853985878a5db90e1547`. QML of the shell itself is out of
scope (09a); `ryoku/wm`, `ryoku/cli`, `ryoku/hub`, `system/hardware` are only
cross-referenced where this code calls into them.

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| ryoku-shell daemon | `ryoku/shell/ipc` | PARTIAL | Medium | `go 1.26` (trixie needs backports Go); `matugen` >= 4.1.0 and `wl-clip-persist` not in any Debian/Ubuntu suite; Arch QML path literal `daemon.go:411` |
| GNOME keyring prompter (in daemon) | `ryoku/shell/ipc/prompter.go`, `secretexchange.go` | YES | Low | none: wire protocol reimplemented in Go, gnome-keyring on every suite drives the same `org.gnome.keyring.SystemPrompter` |
| Polkit agent (in daemon) | `ryoku/shell/ipc/polkit.go` | YES | Low | none in code; trixie uses the setuid-helper path, forky/sid/resolute the socket path; admin group is `sudo` on Debian (not `wheel`) |
| Ryoku.Blobs QML plugin | `ryoku/shell/plugin` | PARTIAL | Low | install dir `/usr/lib/qt6/qml` -> multiarch; ABI-pin policy (decision) |
| livewall (`ryogami-live`, `ryoku-livewall`) | `ryoku/shell/livewall` | YES | Low | none (builds against FFmpeg 7.1 .. 9.0, Wayland from every suite) |
| Ryogami daemon + wall-ui | `ryoku/shell/ryogami` | PARTIAL | Medium | `waifu2x-ncnn-vulkan` and `matugen` not packaged; `steamcmd` is i386 non-free in `/usr/games` (not on Ryoku's PATH); Steam root default misses Debian's Steam layout |
| Palette bridge | `ryoku/palette-bridge` | YES | Low | integrations target Spotify/spicetify/Vesktop/Zen, none packaged in Debian |
| Shell helper scripts | `ryoku/shell/scripts`, `ryoku/shell/bin` | PARTIAL | Medium | `pacman` calls (`ryoku-sysinfo`, `ryoku-profile-stats`, `stash-install.sh`); gawk-only `strtonum` (`ryoku-cmd-folders`); `gpu-screen-recorder` absent in trixie/resolute and shipped without `cap_sys_admin` in forky/sid; `songrec`, `voxtype`, `hyprpicker` (trixie) missing; `ryostage` Python range 3.11-3.13 |
| ryomotion | `release/packages/ryomotion` (upstream ryoku-dev/ryomotion) | PARTIAL | Medium | needs `gpu-screen-recorder`; electron-builder can emit `.deb` directly |
| ryotunes | external, `release/repo/import-ryotunes.sh` | NO | High | upstream publishes only `.pkg.tar.zst`; Ryoku's updater installs it with `pacman -U` |
| Shell systemd user units + env | `ryoku/shell/systemd`, `ryoku/shell/environment.d` | YES | Low | session `PATH` omits `/usr/games`; no uwsm involved |

---

### ryoku-shell daemon (`ryoku/shell/ipc`)

**What it does:** One binary, two roles. `ryoku-shell daemon` supervises the
single Quickshell instance (`components = {"shell", true}`, `daemon.go:31-36`)
by exec'ing `qs -c shell` (`daemon.go:761`, selector `actions.go:48-53`), owns
`$XDG_RUNTIME_DIR/ryoku-shell.sock` (`main.go:18-26`) guarded by an exclusive
lock file (`daemon.go:273`, `467-470`), and in `bootstrap()` starts every
in-process service: settings store, keypress overlay, clipboard history,
StatusNotifier tray host, weather, music metadata, calendar, power profiles,
NetworkManager, night light, OSD, the GNOME keyring prompter, session actions,
the polkit agent, update status, palette/stage workers, the WM watcher, audio
and power-sound watchers, idle parking and sleep/wake protection
(`daemon.go:429-462`). Any other argv forwards one command line to the socket
(`main.go:80-115`); `__clip-ingest`, `theme catalog`, `matugen-preview`,
`icons` and `browser-host` (WebExtension native-messaging host) run standalone
(`main.go:44-79`). It also writes a boot-OK marker to `/var/lib/ryoku/boot`
after the shell survives 45 s (`bootok.go:16-41`).

**Arch couplings:**
- `daemon.go:411` hardcodes `/usr/lib/qt6/qml/Ryoku/Blobs/qmldir` (Arch QML
  dir) to decide whether to prepend `~/.local/lib/qt6/qml` to
  `QML2_IMPORT_PATH`/`QML_IMPORT_PATH`. On Debian the packaged module lives in
  `/usr/lib/x86_64-linux-gnu/qt6/qml`, so the check is always false and the home
  dir is always prepended (a stale `~/.local/lib/qt6/qml/Ryoku` then shadows the
  packaged modules).
- `go.mod:3,5`: `go 1.26`, `toolchain go1.26.5`. Debian trixie's `golang-go` is
  1.24 and refuses the module with `GOTOOLCHAIN=local`.
- `vendor/ryoku-wm/reclaim.go` (vendored copy of `ryoku/wm/reclaim.go:205,255,276`)
  shells out to `pacman -Q/-Rs/-Qi`; it is linked into the binary but nothing in
  `ryoku/shell/ipc` calls `Reclaim` (grep `Reclaim` in `ipc/*.go`: no hit), so
  it is dead code for this binary (owned by the wm seam report).
- `updates.go:71` runs `ryoku status --json`, whose content on Arch is pacman
  data (CLI report).
- No `os-release`, `pacman`, `makepkg` or `/usr/share/libalpm` use in the daemon
  itself.

**External commands and system interfaces (complete list from `exec.Command*`,
`exec.LookPath`, D-Bus names, sockets and sysfs paths):**

| Call | Where | Provided by (Arch) | Debian/Ubuntu package | Notes |
|---|---|---|---|---|
| `qs -c <name>` / `qs -c <name> ipc call ...` | `daemon.go:761`, `actions.go:66,87`, `control.go:148,154,199`, `bar.go:1194` | quickshell | `quickshell` (ships `/usr/bin/qs` and `/usr/bin/quickshell` in trixie-bpo and forky) | Debian package links `libjemalloc2`, so `MALLOC_CONF` (`daemon.go:687-698`) keeps working |
| `flock -n -o /tmp/ryoku-hub.lock qs -c hub` | `control.go:179-180` | util-linux | `util-linux` | |
| `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+` etc. | `control.go:43-53,79` | wireplumber | `wireplumber` (pkg `wireplumber` ships `wpctl`) | |
| `pactl list sink-inputs`, `pactl subscribe` | `audiowatch.go:28,78` | libpulse | `pulseaudio-utils` | works against `pipewire-pulse` |
| `pw-play` then `paplay` | `sounds.go:91-94` | pipewire / libpulse | `pipewire-bin`, `pulseaudio-utils` | clips embedded (`sounds.go:21`) |
| `wl-copy --type`, `wl-paste --watch / --list-types / -n -t` | `clipboard.go:547,566,689,832,840` | wl-clipboard | `wl-clipboard` | history is in-daemon; `cliphist` is NOT used by the daemon |
| `wl-clip-persist --clipboard regular` | `clipboard.go:733,744` | wl-clip-persist | none in any suite | optional: absent -> copies die with their client (`clipboard.go:748-750`) |
| `gsettings get/set org.gnome.desktop.interface ...` (`icon-theme`, `color-scheme`, `gtk-theme`, `accent-color`, `font-name`, `document-font-name`, `monospace-font-name`) | `icons.go:126`, `matugen.go:1289,1361-1362,1390,1626-1628` | glib2 + gsettings-desktop-schemas | `libglib2.0-bin`, `gsettings-desktop-schemas` | `accent-color` key exists from schemas 47 |
| `matugen image ... -t -m --contrast --lightness-dark --lightness-light --source-color-index --prefer --json hex --dry-run` | `matugen.go:157-190`, `775` | matugen | none in any suite | `--prefer` required (`matugen.go:154-156`) -> matugen >= 4.1.0; `--source-color-index`/lightness -> >= 4.0.0 |
| `matugen -c <config> json <carrier>` | `matugen.go:1253` | matugen | none | template pass |
| `ffmpeg` (luma probe, frame grab with `-update 1`) | `matugen.go:251,307,377`, `walltone.go:88`, `theming.go:92` | ffmpeg | `ffmpeg` | |
| `pkill -USR1 -x kitty` | `matugen.go:1299,1631` | procps | `procps` | kitty reloads its config on SIGUSR1 |
| `pgrep -u <uid> -f ...` | `actions.go:253,421` | procps | `procps` | |
| `systemctl --user is-active/stop ...` | `actions.go:417`, `sleepwake.go:974,977` | systemd | `systemd` | |
| `systemctl reboot` / `poweroff` | `session.go:18-19,57` | systemd | `systemd` | |
| `nmcli connection import type wireguard file` | `network.go:750` | networkmanager | `network-manager` | |
| `voxtype record start/stop`, `voxtype status --follow --format json` | `actions.go:398-407`, `voicewatch.go:76-79` | voxtype-bin (AUR) | none | optional; upstream github.com/peteonrails/voxtype v1.1.1 (AUR URL voxtype.io) |
| `ryoku-qylock-lock` | `actions.go:380-384` | ryoku-desktop | Ryoku package | lock client pattern `actions.go:311` expects a process named `quickshell` |
| `ryoku-cmd-brightness`, `ryoku-cmd-nightlight`, `ryoku-reload-cover`, `ryostage`, `ryoku-plugins-place` | `control.go:91`, `nightlight.go:182-186`, `daemon.go:38-49`, `stage.go:289-328`, `bar.go:387-391,942` | ryoku-shell / ryoku-desktop | Ryoku packages | |
| `ryoku-hw-backlight`, `ryoku-power apply-profile`, `/usr/bin/ryoku-dns` | `osd.go:80`, `powerprofiles.go:369`, `network.go:861,702` | ryoku-desktop (`system/hardware/*/ryoku-*`, `release/packages/ryoku-desktop/PKGBUILD:518`) | Ryoku package | |
| `ryoku-hub lighting apply/accent` | `sleepwake.go:1018-1021`, `theming.go:26-38,320` | ryoku-hub | Ryoku package | `findHubBin` also probes `/usr/local/bin`, `/usr/bin` |
| `ryoku-cursor-material-recolor` | `matugen.go:583` | ryoku-cursor-material | Ryoku package | |
| `ryoku status --json` | `updates.go:71` | ryoku | Ryoku package | |
| `ryoku-wm-<provider>` (hyprland/niri) | `wm.Open()` `daemon.go:253`, `ryoku/wm/client.go:49,59,346` | ryoku-desktop-hyprland / -niri | Ryoku packages | |
| `/usr/lib/polkit-1/polkit-agent-helper-1`, `/run/polkit/agent-helper.socket` | `polkit.go:61,69` | polkit | `polkitd` | see polkit section |
| System bus: `org.freedesktop.NetworkManager` (+ `.Settings`, `.Device`, `.Device.Wireless`, `.AccessPoint`, `.Connection.Active`, `.Settings.Connection`) | `network.go:28-38,83` | networkmanager | `network-manager` | |
| System bus: `org.freedesktop.UPower.PowerProfiles` at `/org/freedesktop/UPower/PowerProfiles` | `powerprofiles.go:26-28,56` | power-profiles-daemon | `power-profiles-daemon` 0.30 everywhere | this bus name exists from ppd 0.20 |
| System bus: `org.freedesktop.login1` (`Manager.Inhibit`, `PrepareForSleep`, `GetSessionByPID`, `ListSessions`, `Session.Active`, `InhibitDelayMaxUSec`) | `sleepwake.go:23-24,74,122,791`, `polkit.go:489-494,581` | systemd | `systemd` (logind) | |
| System bus: `org.freedesktop.PolicyKit1.Authority`, exports `org.freedesktop.PolicyKit1.AuthenticationAgent` | `polkit.go:43-48,188` | polkit | `polkitd` | gated by `RYOKU_POLKIT_AGENT=1` (`polkit.go:180`) |
| Session bus: owns `org.kde.StatusNotifierWatcher`, talks `org.kde.StatusNotifierItem`, `com.canonical.dbusmenu` | `tray.go:32-36,123,139` | - | - | |
| Session bus: owns `org.gnome.keyring.SystemPrompter` | `prompter.go:31-36,80` | - | - | see prompter section |
| `/dev/input/event*`, `/sys/class/input` | `keypress.go:1028` | udev rule `system/hardware/input/72-ryoku-keyboard-uaccess.rules:7` (`TAG+="uaccess"`) | same mechanism under systemd-logind | rule must ship (system report) |
| `/sys/class/backlight`, `/sys/class/power_supply`, `/proc/<pid>/{cmdline,environ,comm,stat}`, `/proc/sys/kernel/random/boot_id` | `osd.go:79`, `powersounds.go:16`, `clipboard.go:718,775-782`, `nightlight.go:356`, `bootok.go:33` | kernel | kernel | |
| `$XDG_RUNTIME_DIR/quickshell/by-id`, `by-pid`, `by-path`, `by-shell`, `vfs` (pruned) | `qsruntime.go:28`, `qsruntime.go` `pruneQuickshellLinks` | quickshell layout | same in Debian quickshell | |
| `$XDG_RUNTIME_DIR/ryogami.sock` | `ryogami.go:42,49,199` | ryogami | Ryoku package | |
| HTTPS: open-meteo, ipwho.is, lrclib.net, api.deezer.com, itunes.apple.com, nagerholidays.com | `weather.go:38-41`, `music.go:37-40`, `calendar.go:19` | - | `ca-certificates` | pure-Go TLS reads `/etc/ssl/certs/ca-certificates.crt` |
| `/var/lib/ryoku/boot/ok-<uid>` | `bootok.go:16,40` | `ryoku` package tmpfiles | Ryoku package | sticky world-writable dir must exist (CLI/boot-guard report) |

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| go (make) | build (`release/packages/ryoku-shell/PKGBUILD:28`) | `golang-1.26-go` | - | 1.26.9-1~bpo13+1 | 1.26.9-1 | 1.26.9-1 | 1.26.8-1~ubuntu0.26.04.2 | 1.26 (`go.mod:3`); `toolchain go1.26.5` (`go.mod:5`) is satisfied by any local 1.26.x >= .5 |
| (vendored) godbus | D-Bus (`go.mod:7`) | `golang-dbus-dev` | 5.1.0-1 | - | 5.1.0-1 | 5.1.0-1 | 5.1.0-1 | v5.2.2 vendored (`vendor/modules.txt:1`); build uses `-mod=vendor`, Debian copy not needed |
| (vendored) x/sys | unix (`go.mod:9`) | `golang-golang-x-sys-dev` | 0.22.0-1 | 0.42.0-1~bpo13+1 | 0.49.0+dfsg-1 | 0.49.0+dfsg-1 | 0.38.0-1 | v0.27.0 vendored |
| quickshell | supervised surfaces (`daemon.go:761`) | `quickshell` | - | 0.3.0-1~bpo13+1 | 0.3.2-1 | 0.3.2-1 | - | Arch ships 0.3.2 (09a decides the floor) |
| wl-clipboard | clipboard (`clipboard.go:547-840`) | `wl-clipboard` | 2.2.1-2 | 2.3.0-1~bpo13+1 | 2.3.0-1 | 2.3.0-1 | 2.2.1-2build1 | `--watch`, `--list-types` (any 2.x) |
| wl-clip-persist | selection keeper (`clipboard.go:744`) | none | - | - | - | - | - | upstream Linus789/wl-clip-persist v0.5.0 (Arch 0.5.0-2) |
| wireplumber | `wpctl` (`control.go:79`) | `wireplumber` | 0.5.8-2 | 0.5.12-1~bpo13+1 | 0.5.18-1 | 0.5.18-1 | 0.5.13-1ubuntu1.1 | `set-volume -l` |
| libpulse | `pactl`, `paplay` (`audiowatch.go:28`, `sounds.go:94`) | `pulseaudio-utils` | 17.0+dfsg1-2+b1 | - | 17.0+dfsg1-3 | 17.0+dfsg1-3 | 1:17.0+dfsg1-2ubuntu4 | |
| pipewire | `pw-play` (`sounds.go:91`) | `pipewire-bin` | 1.4.2-1 | 1.6.9-2~bpo13+1 | 1.6.9-2 | 1.6.9-2 | 1.6.2-1ubuntu1.3 | |
| networkmanager | D-Bus + `nmcli` (`network.go:28-38,750`) | `network-manager` | 1.52.1-1 | - | 1.58.1-1 | 1.58.1-1 | 1.54.3-2ubuntu3.1 | wireguard import (any >= 1.20) |
| power-profiles-daemon | `org.freedesktop.UPower.PowerProfiles` (`powerprofiles.go:26`) | `power-profiles-daemon` | 0.30-1.1 | - | 0.30-2+b1 | 0.30-2+b1 | 0.30-2 | >= 0.20 (new bus name) |
| glib2 | `gsettings` (`matugen.go:1289`) | `libglib2.0-bin` | 2.84.4-3~deb13u5 | - | 2.90.1-2 | 2.90.1-2 | 2.88.0-1ubuntu0.1 | |
| gsettings-desktop-schemas | `accent-color` key (`matugen.go:1390`) | `gsettings-desktop-schemas` | 48.0-1 | - | 51.0-2 | 51.0-2 | 50.0-1ubuntu2 | >= 47 |
| matugen | palette (`matugen.go:157-190,775,1253`) | none | - | - | - | - | - | >= 4.1.0 (`--prefer`, upstream CHANGELOG 4.1.0 "prefer-color-option"); Arch 4.2.0-1 |
| ffmpeg | luma/frames (`matugen.go:251`, `theming.go:92`) | `ffmpeg` | 7:7.1.5-0+deb13u1 | - | 7:9.0.2-3 | 7:9.0.2-3 | 7:8.0.1-3ubuntu2 | |
| procps | `pgrep`/`pkill` | `procps` | 2:4.0.4-9 | - | 2:4.0.7-1 | 2:4.0.7-1 | 2:4.0.4-9ubuntu1 | |
| util-linux | `flock -o` (`control.go:179`) | `util-linux` | 2.41.5-0+deb13u1 | - | 2.42.4-1 | 2.42.4-1 | 2.41.3-3ubuntu2.3 | |
| polkit | agent helper (`polkit.go:61,69`) | `polkitd` | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | |
| gnome-keyring | prompter client | `gnome-keyring` | 48.0-1 | - | 51.1-3 | 51.1-3 | 50.0-1 | |
| kitty | SIGUSR1 reload (`matugen.go:1299`) | `kitty` | 0.41.1-2+deb13u2 | - | 0.48.2-1.1 | 0.48.2-1.1 | 0.45.0-1build1 | |
| ca-certificates | HTTPS (`weather.go:38`) | `ca-certificates` | 20250419 | - | 20260816 | 20260816 | 20260601~26.04.1 | |
| voxtype-bin (AUR) | dictation (`actions.go:398`) | none | - | - | - | - | - | optional; upstream v1.1.1 publishes x86_64 binaries and an `.rpm`, no `.deb` |
| jq, uv (runtime, PKGBUILD) | scripts / ryostage (`release/packages/ryoku-shell/PKGBUILD:18`) | see scripts section | | | | | | |

**As-is on Debian:** PARTIAL: compiles unchanged with Go 1.26; runtime needs two
unpackaged tools (matugen, wl-clip-persist) and one path edit.

**Port steps:**
1. Build-Depends: `golang-1.26-go` (trixie: enable `trixie-backports`), `gcc`,
   `pkgconf`, `libwayland-dev`, `libwayland-bin`, `wayland-protocols`,
   `libavformat-dev`, `libavcodec-dev`, `libavutil-dev`, `libswscale-dev`
   (the last six are for livewall, built in the same package by
   `release/packages/ryoku-shell/PKGBUILD:33`).
2. `debian/rules` build (offline, matches `PKGBUILD:28`):
   ```make
   export GOTOOLCHAIN=local CGO_ENABLED=0 GOFLAGS=-mod=vendor
   export GOCACHE=$(CURDIR)/debian/.gocache GOPATH=$(CURDIR)/debian/.gopath
   override_dh_auto_build:
   	cd ryoku/shell/ipc && /usr/lib/go-1.26/bin/go build -trimpath -mod=vendor -o $(CURDIR)/build/ryoku-shell .
   	ryoku/shell/livewall/build.sh $(CURDIR)/build/ryoku-livewall
   override_dh_auto_test:
   ```
   (`GOCACHE`/`GOPATH` because buildd `$HOME` is unwritable; `dh-golang` is not
   needed, the module is vendored.)
3. Install exactly what `PKGBUILD:36-63` installs: `/usr/bin/ryoku-shell`,
   `/usr/bin/ryoku-livewall`, every `ryoku/shell/scripts/ryoku-*` and
   `ryoku/shell/scripts/*.sh` to `/usr/bin` (mode 755), `ryostage` to
   `/usr/bin`, `ryoku/shell/quickshell/reload-cover/` to
   `/usr/share/ryoku/reload-cover/`.
4. Edit `ryoku/shell/ipc/daemon.go:411`:
   `"/usr/lib/qt6/qml/Ryoku/Blobs/qmldir"` ->
   `"/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku/Blobs/qmldir"` (Ryoku is
   `arch=('x86_64')` only, `release/packages/ryoku-shell/PKGBUILD` header).
5. `Depends:` `quickshell, wl-clipboard, wireplumber, pulseaudio-utils,
   pipewire-bin, libglib2.0-bin, gsettings-desktop-schemas, procps,
   util-linux, ffmpeg, jq, ca-certificates, matugen (>= 4.1.0)`;
   `Recommends: wl-clip-persist, network-manager, power-profiles-daemon,
   polkitd, gnome-keyring, kitty`; `Suggests: voxtype`. (Arch `depends` is only
   `quickshell ffmpeg wayland jq uv`, `PKGBUILD:18`; the rest come in through
   `ryoku-desktop`, `release/packages/ryoku-desktop/PKGBUILD:20-209`.)
6. Build `matugen` as a .deb: upstream `https://github.com/InioX/matugen`,
   tag `v4.2.0` (latest; Arch 4.2.0-1), Rust edition 2021, default features
   `dump-json jxl-image`. `cargo build --release --locked` with
   `rustc`/`cargo` from trixie-backports (1.96) or trixie's `rustc-web`
   1.96, forky/sid/resolute archive rustc; install `target/release/matugen`
   to `/usr/bin/matugen`. Build-Depends: `cargo, rustc, pkgconf`.
7. Build `wl-clip-persist` as a .deb: upstream
   `https://github.com/Linus789/wl-clip-persist` tag `v0.5.0`, edition 2024,
   `rust-version = "1.85.0"` (trixie's rustc 1.85.1 suffices).
   `cargo build --release --locked`, install to `/usr/bin/wl-clip-persist`.
8. Optional `voxtype` .deb: repackage upstream release binary
   `voxtype-1.1.1-linux-x86_64-avx2` (or `-baseline`) to
   `/usr/bin/voxtype`, plus its user unit (the shell expects
   `voxtype.service`, `actions.go:417`).

**Complexity:** Medium: the daemon is self-contained Go; the work is the Go
backport on trixie and two small Rust tool packages.

**Issues / risks:**
- `reclaim.go` (pacman) is compiled in via the vendored `ryoku-wm`; harmless
  unless a future daemon verb calls it.
- The vendored `vendor/ryoku-wm` is a copy of `ryoku/wm` (identical at this
  commit); any patch to `ryoku/wm` for Debian must be followed by
  `go mod vendor` in `ryoku/shell/ipc` and `ryoku/shell/ryogami/daemon`, or the
  `-mod=vendor` build silently uses the old copy.
- `matugen` JSON shape: `parseMatugenPalette` expects `colors.<role>.<mode>.{color|hex}`
  (`matugen.go:788-822`). Upstream changed JSON output in 4.0.0 ("change default
  json output and add `--old-json-output`") and 4.1.0 ("format new json
  output"); pin the Debian matugen to the same 4.2.0 Arch ships.
- Keypress overlay depends on the `uaccess` udev rule from `system/hardware`
  (`72-ryoku-keyboard-uaccess.rules:7`); without it `/dev/input` opens fail
  silently.

---

### GNOME keyring system prompter (`ryoku/shell/ipc/prompter.go`, `secretexchange.go`)

**What it does:** At bootstrap the daemon exports
`org.gnome.keyring.internal.Prompter` at `/org/gnome/keyring/Prompter` and
requests `org.gnome.keyring.SystemPrompter` on the session bus with
`ReplaceExisting|DoNotQueue` (`prompter.go:31-36,67-91`); on failure it logs and
leaves gcr's own prompter as the fallback. It implements gcr's prompter contract
(`BeginPrompting`/`PerformPrompt`/`StopPrompting`, callbacks `PromptReady`,
`PromptDone`, error `org.gnome.keyring.Prompter.Failed`, `prompter.go:24-40`) and
reimplements gcr's `sx-aes-1` secret exchange in pure Go: DH over the RFC 3526
1536-bit MODP group, HKDF-SHA256 to a 16-byte key, AES-128-CBC/PKCS#7, GLib
key-file wire form (`secretexchange.go:16-33`). It links no gcr library.

**Arch couplings:** none. The protocol is the one gcr 3 and gcr 4 share.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| gnome-keyring | client that drives the prompter | `gnome-keyring` | 48.0-1 | - | 51.1-3 | 51.1-3 | 50.0-1 | any; Debian's links `libgcr-base-3-1` (gcr 3 `GcrSystemPrompt`) on every suite; Arch 51.1 depends on both `gcr` and `gcr-4` |
| gcr | fallback `gcr-prompter` + D-Bus activation file `org.gnome.keyring.SystemPrompter.service` | `gcr` | 3.41.2-3 | - | 3.41.2-6+b1 | 3.41.2-6+b1 | 3.41.2-6 | trixie `gcr` ships `/usr/libexec/gcr-prompter` and `/usr/share/dbus-1/services/org.gnome.keyring.SystemPrompter.service` |
| gcr-4 | not used by the prompter path | `gcr4` | 4.4.0.1-3 | - | 4.4.1-3 | 4.4.1-3 | 4.4.0.1-8 | Debian `gcr4` ships no SystemPrompter service file |

**As-is on Debian:** YES.

**Port steps:**
1. None in code. Keep `gnome-keyring` (+ `libpam-gnome-keyring` for login
   unlock, system/installer report) installed; `gcr` comes in as its
   dependency.
2. Validation available in-tree: `prompter_interop_test.go` (gated by
   `RYOKU_KEYRING_INTEROP=1`, creates and unlocks a throwaway collection against
   the live `gnome-keyring-daemon`) and `gcr_interop_test.go` (gated by
   `GCRX_BIN`, compares against a compiled gcr reference).

**Complexity:** Low.

**Issues / risks:**
- Name race: if `gnome-keyring-daemon` asks for a prompt before the daemon has
  registered, D-Bus activation starts `gcr-prompter`; the daemon's
  `RequestName` then fails unless `gcr-prompter` allows replacement, and the
  prompt for that session is gcr's GTK dialog (`prompter.go:86-90`). Identical
  on Arch; noted because Debian's PAM auto-unlock timing differs per display
  manager.

---

### Polkit authentication agent (`ryoku/shell/ipc/polkit.go`)

**What it does:** When `RYOKU_POLKIT_AGENT=1` (`polkit.go:180`; set by
`ryoku-shell.service` `Environment=` and `environment.d/ryoku-session.conf:32`)
it registers as `org.freedesktop.PolicyKit1.AuthenticationAgent` for the login1
session (`polkit.go:43-48,481-494,569-581`) and runs PAM through
`polkit-agent-helper-1`: it dials `/run/polkit/agent-helper.socket` if present
(polkit >= 126 socket activation), else execs the helper directly, with
`argv[1]=user` when the helper is setuid, `--socket-activated` otherwise
(`polkit.go:61-112,441-454`).

**Arch couplings:** none; path `/usr/lib/polkit-1/polkit-agent-helper-1` is the
same on Debian and Ubuntu.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| polkit | helper + authority (`polkit.go:61,69`) | `polkitd` | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | any: trixie ships no `polkit-agent-helper.socket` and installs the helper setuid 4755 (`debian/polkitd.postinst:90`), so the daemon takes the setuid branch; forky/sid/resolute ship `polkit-agent-helper.socket` + `polkit-agent-helper@.service`, socket branch |
| polkit (pkexec) | `ryoku-cmd-game-mode:145`, `stash-install.sh:358` | `pkexec` (separate binary package in Debian) | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | |

**As-is on Debian:** YES.

**Port steps:**
1. Depend on `polkitd`. Nothing else in code.
2. The user must be in group `sudo` (Debian polkit is built with
   `-Dprivileged_group=sudo`, `debian/rules` of policykit-1 126-2); Ryoku's
   admin group on Arch is `wheel` (installer report). `polkitPickUser` takes the
   first `unix-user` identity polkitd offers (`polkit.go:456-478`), so the
   identity list comes from that group.

**Complexity:** Low.

---

### Ryoku.Blobs QML plugin (`ryoku/shell/plugin`)

**What it does:** C++ QML module `Ryoku.Blobs` 1.0: SDF metaball items
(`BlobGroup`, `BlobShape`, `BlobRect`, `BlobInvertedRect`) with a custom
`QSGMaterial` and baked shaders, plus `CameraFeed` (webcam via QtMultimedia)
(`CMakeLists.txt:22-33,49-56`). Built with `qt_add_qml_module`, AUTOMOC,
`qt_add_shaders` (GLSL `300es,330`, `BATCHABLE`), output
`<build>/qml/Ryoku/Blobs` containing the plugin `.so` with an `$ORIGIN` rpath to
its backing library `libryoku-blobs.so` (`CMakeLists.txt:39-47`).
`build.sh` runs `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release`, builds, copies the
module dir to `<dest>/Ryoku/Blobs` and deletes the `.qrc` byproduct
(`build.sh:24-35`).

**Toolchain facts:** `cmake_minimum_required(VERSION 3.28)` (`CMakeLists.txt:10`);
C++20 (`CMakeLists.txt:14-15`); `find_package(Qt6 6.5 REQUIRED COMPONENTS Quick
ShaderTools Multimedia)` and `qt_standard_project_setup(REQUIRES 6.5)`
(`CMakeLists.txt:18-20`); links `Qt6::Quick Qt6::Multimedia` only
(`CMakeLists.txt:37`). **No Qt private module is used**: no
`Qt6::QuickPrivate`/`GuiPrivate`/`QmlPrivate`, and every include is a public
header (`qquickitem.h`, `qsgmaterial.h`, `qsgmaterialshader.h`, `qsggeometry.h`,
`qsgnode.h`, `QSGImageNode`, `qqmlengine.h`, `qqmlregistration.h`, `QCamera`,
`QMediaCaptureSession`, `QMediaDevices`, `QVideoSink`, `QVideoFrame`; grep of
`plugin/*.cpp *.hpp`). No Rust/Cargo, no qmake.

**Arch couplings:**
- `release/packages/ryoku-blobs/PKGBUILD:33-37` installs to
  `/usr/lib/qt6/qml/Ryoku/Blobs` (Arch QML dir).
- `ryoku/shell/deploy.sh:473-485` (dev loop) stamps
  `~/.local/lib/qt6/qml/Ryoku/Blobs/.qt-version` from
  `pacman -Q qt6-base` (`deploy.sh:474`) and rebuilds when it changes.
- `build.sh:20` error text says `pacman -S cmake ninja qt6-shadertools`.
- `ryoku/shell/ipc/daemon.go:411` probes the Arch path (see daemon section).
- Doc vs code: `docs/development.md:69-73` says a QML plugin must be rebuilt on
  every Qt update because "Qt's private API carries no cross-version promise";
  the Blobs code uses only public API (above), which Qt keeps binary compatible
  across 6.x minors. The doctor check that moves a stale module aside lives in
  `ryoku/cli/internal/doctor/reconcile_quickshell.go:53-65` (CLI report).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| cmake (make) | configure (`build.sh:24`) | `cmake` | 3.31.6-2 | 4.3.4-1~bpo13+1 | 4.3.4-1 | 4.3.4-1 | 4.2.3-2ubuntu2 | 3.28 (`CMakeLists.txt:10`) |
| ninja (make) | `-G Ninja` (`build.sh:24`) | `ninja-build` | 1.12.1-1+b1 | - | 1.13.2-1+b1 | 1.13.2-1+b1 | 1.13.2-1 | |
| qt6-declarative (make) | Qt6::Quick, `qt_add_qml_module`, qmltyperegistrar | `qt6-declarative-dev`, `qt6-declarative-dev-tools` | 6.8.2+dfsg-7 | - | 6.11.2+dfsg-3 | 6.11.2+dfsg-3 | 6.10.2+dfsg-3 | 6.5 (`CMakeLists.txt:18`) |
| qt6-base (make) | Core/Gui headers | `qt6-base-dev` | 6.8.2+dfsg-9+deb13u2 | - | 6.11.2+dfsg-5 | 6.11.2+dfsg-6 | 6.10.2+dfsg-7 | 6.5 |
| qt6-shadertools (make) | `qt_add_shaders` / `qsb` | `qt6-shadertools-dev` (depends on `qt6-shader-baker`, which holds `qsb`) | 6.8.2-3 | - | 6.11.2-2 | 6.11.2-2 | 6.10.2-1 | 6.5 |
| qt6-multimedia (make+run) | CameraFeed (`CMakeLists.txt:37`) | `qt6-multimedia-dev` / `libqt6multimedia6` | 6.8.2-8 | - | 6.11.2-3 | 6.11.2-3 | 6.10.2-2 | 6.5; Debian `libqt6multimedia6` contains `plugins/multimedia/libffmpegmediaplugin.so`, the backend `ryoku-shell.service` forces with `QT_MEDIA_BACKEND=ffmpeg` |
| qt6-base, qt6-declarative (run) | runtime | `libqt6core6t64`, `libqt6gui6`, `libqt6qml6`, `libqt6quick6` | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | filled by `dh_shlibdeps` |
| (none private) | - | `qt6-base-private-dev`, `qt6-declarative-private-dev` | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | NOT needed by this plugin |

**The Qt ABI coupling on Debian (task item 2):**
- Debian's Qt packaging already encodes the "rebuild on every Qt update" rule
  for private-API users, automatically. `libqt6core6t64` declares
  `Provides: qt6-base-private-abi (= 6.8.2)` (qt6-base `debian/control:101-102`)
  and `libqt6qml6` declares `Provides: qt6-declarative-private-abi (= 6.8.2)`
  (qt6-declarative `debian/control:32-36`); forky's are `(= 6.11.2)`. Their
  symbols files map every `Qt_6_PRIVATE_API`-versioned symbol to an alternative
  dependency template: `libQt6Quick.so.6 libqt6quick6 #MINVER#` /
  `| libqt6quick6 #MINVER#, qt6-declarative-private-abi (= 6.8.2)` /
  `(symver)Qt_6_PRIVATE_API 0 1` (same for libQt6Qml and libQt6Core). So any
  binary that links a private symbol gets the exact-version pin from
  `dpkg-shlibdeps` with no manual work. Debian's own `quickshell` shows it:
  trixie-bpo `Depends: qt6-base-private-abi (= 6.8.2), qt6-declarative-private-abi (= ...)`,
  forky `(= 6.11.2)`, so apt holds Qt back (or removes quickshell) until
  quickshell is rebuilt.
- The virtual package name the task proposed (`qtdeclarative-abi-6-8-2`) is the
  Qt 5 scheme (`qtbase-abi-5-15-x`); it does not exist for Qt 6. The Qt 6 names
  are the versioned virtuals `qt6-base-private-abi (= X)`,
  `qt6-declarative-private-abi (= X)` (also `qt6-shadertools-private-abi`,
  `libqt6shadertools6` `debian/control:28`). X is the upstream Qt version, so
  Debian revision bumps (`+deb13u2`) do not break it.
- `QQmlPrivate::qmlregister` and the other registration symbols the generated
  `qt_add_qml_module` code calls are tagged `@Qt_6` (public), not
  `Qt_6_PRIVATE_API` (`libqt6qml6.symbols` lines 173-181), so Ryoku.Blobs as
  written gets NO automatic private-abi pin: only `libqt6quick6 (>= ...)` etc.
- Replication options are listed under Questions.

**As-is on Debian:** PARTIAL: builds unchanged; install path must change.

**Port steps:**
1. Build-Depends: `cmake (>= 3.28), ninja-build, g++, qt6-base-dev,
   qt6-declarative-dev, qt6-declarative-dev-tools, qt6-shadertools-dev,
   qt6-multimedia-dev`.
2. `debian/rules`:
   ```make
   QMLDIR := usr/lib/$(DEB_HOST_MULTIARCH)/qt6/qml
   override_dh_auto_configure override_dh_auto_test:
   override_dh_auto_build:
   	RYOKU_BLOBS_BUILD=$(CURDIR)/build/blobs ryoku/shell/plugin/build.sh $(CURDIR)/build/qml
   override_dh_auto_install:
   	install -d debian/ryoku-blobs/$(QMLDIR)/Ryoku
   	cp -a build/qml/Ryoku/Blobs debian/ryoku-blobs/$(QMLDIR)/Ryoku/
   	chmod -R u=rwX,go=rX debian/ryoku-blobs/$(QMLDIR)
   override_dh_shlibdeps:
   	dh_shlibdeps -l$(CURDIR)/debian/ryoku-blobs/$(QMLDIR)/Ryoku/Blobs
   ```
   (`QMLDIR` matches what Debian's quickshell uses:
   `-DINSTALL_QML_PREFIX=lib/$(DEB_HOST_MULTIARCH)/qt6/qml`.)
3. `Depends: ${shlibs:Depends}, ${misc:Depends}` (+ the explicit pin if chosen,
   see Questions).
4. `deploy.sh:474` (dev loop) `pacman -Q qt6-base` ->
   `dpkg-query -W -f='${Version}' libqt6core6t64`.
5. `build.sh:20` message `pacman -S cmake ninja qt6-shadertools` ->
   `apt install cmake ninja-build qt6-shadertools-dev`.

**Complexity:** Low.

**Issues / risks:**
- lintian will flag the custom `$ORIGIN` RUNPATH and the unversioned private
  `libryoku-blobs.so` in a QML dir (warnings only).
- `Ryoku.Ui`, `Ryoku.PluginKit`, `Ryoku.FrameBars`, `Ryoku.Wm.Hyprland` (pure
  QML) are installed by other PKGBUILDs to the same Arch path
  (`release/packages/ryoku-desktop/PKGBUILD:324-349`,
  `ryoku-desktop-hyprland/PKGBUILD:87-88`); they need the same multiarch move.

**Questions for the human:**
- Ryoku.Blobs ABI pin. (a) shlibs only: Blobs keeps loading across Qt 6.x
  updates per Qt's public-API binary compatibility; if Ryoku ever adds a private
  symbol, `dpkg-shlibdeps` adds the exact pin by itself. (b) explicit
  `Depends: qt6-declarative-private-abi (= <qt ver at build>)`, computed in
  `debian/rules` from `dpkg-query -W -f='${Provides}' libqt6qml6`: reproduces
  the Arch "rebuild on every Qt update" policy (`docs/development.md:69-73`);
  every Qt upload to forky/sid then blocks the Qt upgrade (or removes
  ryoku-blobs) until ryoku-blobs is rebuilt, exactly as quickshell already does.

---

### livewall: `ryogami-live` / `ryoku-livewall` (`ryoku/shell/livewall`)

**What it does:** C program that decodes a clip with libav (VA-API, CUDA, VDPAU,
DRM hwaccel, software fallback) and paints scaled frames into `wl_shm`
(`memfd_create`) buffers on a wlr-layer-shell BACKGROUND surface, upscaled by
`wp_viewporter` (`livewall.c:1-12,162,275-280`). Usage
`livewall <video> [cap_width] [fit] [output_name]` (`livewall.c:12`). Ryogami
execs it as `ryogami-live` (`ryogami/daemon/livewall.go:23`, `video.go:122`).
`build.sh` generates protocol glue with `wayland-scanner` from the bundled
`wlr-layer-shell.xml` and wayland-protocols' `stable/viewporter` and
`stable/xdg-shell`, then `cc -O2 -Wall ... $(pkg-config --cflags --libs
wayland-client libavformat libavcodec libavutil libswscale) -lm`
(`build.sh:20-37`).

**Arch couplings:** none. `release/packages/ryoku-shell/PKGBUILD:33,38` builds
and installs a second copy named `ryoku-livewall`; nothing execs that name any
more (only `pkill`/cleanup references: `ryoku/shell/deploy.sh:160`,
`ryoku/cli/internal/updater/update.go:1921`; `deploy.sh:310` builds only
`ryogami-live`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| wayland (make/run) | `wayland-client` (`build.sh:37`) | `libwayland-dev` / `libwayland-client0` | 1.23.1-3 | - | 1.26.0-1 | 1.26.0-1 | 1.24.0-2 | |
| wayland (make) | `wayland-scanner` (`build.sh:27-28`) | `libwayland-bin` | 1.23.1-3 | - | 1.26.0-1 | 1.26.0-1 | 1.24.0-2 | |
| wayland-protocols (make) | viewporter, xdg-shell (`build.sh:31-32`) | `wayland-protocols` | 1.44-1 | 1.47-1~bpo13+1 | 1.49-1 | 1.49-1 | 1.47-1 | stable protocols, any |
| ffmpeg (make/run) | libav* + libswscale (`build.sh:37`, `livewall.c:25-29`) | `libavformat-dev libavcodec-dev libavutil-dev libswscale-dev` | 7:7.1.5-0+deb13u1 | - | 7:9.0.2-3 | 7:9.0.2-3 | 7:8.0.1-3ubuntu2 | API used (`avcodec_send_packet`, `av_hwframe_transfer_data`, `sws_getContext`...) exists in 7.1; Arch builds it against 9.0.2 |
| (make) | `cc`, `pkg-config` | `gcc`, `pkgconf` | | | | | | |

**As-is on Debian:** YES.

**Port steps:**
1. Built inside the `ryoku-shell` and `ryogami` packages:
   `ryoku/shell/livewall/build.sh $(CURDIR)/build/ryogami-live`.
2. Runtime deps come from `dh_shlibdeps` (`libavcodec61`/`libavformat61`... on
   trixie, the 9.x sonames on forky/sid).

**Complexity:** Low.

**Questions for the human:**
- `ryoku-livewall`: ship the unused duplicate binary (byte-for-byte parity with
  the Arch `ryoku-shell` package) or drop it.

---

### Ryogami daemon + wall-ui (`ryoku/shell/ryogami`)

**What it does:** Go daemon (`ryogami`) owning the wallpaper catalog,
thumbnails, colour extraction, grading/effects, transitions, video wallpapers
(through `ryogami-live`), optional AI upscaling, and a line pub/sub on
`$XDG_RUNTIME_DIR/ryogami.sock` (`daemon/proto.go:88-92`); client verbs
`wallpaper`, `depth`, `upscale` (`daemon/main.go:29-55`). It spawns the resident
QML picker `quickshell -p /usr/share/ryogami/shell.qml` (`daemon/process.go:25-40,73-74`),
override `RYOGAMI_SHELL_QML`. Module `ryogami`, `go 1.22`, only dependency the
vendored local `ryoku-wm` (`daemon/go.mod:1-7`, `vendor/modules.txt`); built
`CGO_ENABLED=0 go build -trimpath -mod=vendor` (`release/packages/ryogami/PKGBUILD:40`).

**Arch couplings:**
- `daemon/upscale.go:68` hardcodes `waifu2x-ncnn-vulkan` models at
  `/usr/share/waifu2x-ncnn-vulkan/models-cunet` (Arch `extra/waifu2x-ncnn-vulkan`
  layout).
- `wall-ui/qml/Config.qml:101` defaults the Steam root to
  `~/.local/share/Steam`; Debian's `steam-installer` keeps Steam under
  `~/.steam/debian-installation` (overridable via `paths.steam`).
- `wall-ui/qml/wallpaper/SteamWorkshopDownloadProc.qml:66` execs bare
  `steamcmd`; Debian/Ubuntu install it as `/usr/games/steamcmd`, and the Ryoku
  session `PATH` is `$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin`
  (`ryoku/shell/environment.d/ryoku-session.conf:16`), so it does not resolve.
- `ryogami.service` sets jemalloc `MALLOC_CONF` for quickshell
  (`ryoku/shell/systemd/user/ryogami.service:26`); valid on Debian because
  Debian's `quickshell` depends on `libjemalloc2 (>= 5.3.0)`.

**External commands:**

| Call | Where | Debian/Ubuntu package |
|---|---|---|
| `magick` (thumbs, `RGB:-` sampling, grade `-modulate -brightness-contrast -vignette -negate -evaluate`, effects `png:-`, optimize) | `daemon/scan.go:245,276,296`, `grade.go:127,144-167`, `effects.go:300,339`, `optimize.go:282`; wall-ui `qml/services/ImageService.qml:26,47`, `FileMetadataService.qml:71` | `imagemagick` (IM7 on every suite; `/usr/bin/magick` via update-alternatives from `magick-im7.q16`) |
| `ffmpeg` / `ffprobe` (`nice -n 19`) | `daemon/livewall.go:73,187,199,229,233,310`, `scan.go:254,443,480,488,526,532`, `optimize.go:280,316,356`, `upscale.go:352`; wall-ui `ImageService.qml:32,40`, `FileMetadataService.qml:67` | `ffmpeg`, `coreutils` (`nice`) |
| `ryogami-live`, `pkill -x ryogami-live`, `pkill -f mpvpaper` | `daemon/video.go:122,255-256` | built in package; `procps` |
| `quickshell -p <shell.qml>`, `pkill -f "quickshell .*<qml>"` | `daemon/process.go:73-74` | `quickshell`, `procps` |
| `waifu2x-ncnn-vulkan` | `daemon/upscale.go:284-297,322-361` | none in any suite |
| `ryogami upscale-worker` (self re-exec) | `daemon/upscale_worker.go:57` | - |
| wall-ui: `curl` (Wallhaven, Steam Workshop, ryowalls registry) | `qml/wallpaper/WallhavenService.qml:149,210`, `SteamWorkshopService.qml:219,283`, `RyowallsSource.qml:88` | `curl` |
| wall-ui: `stdbuf -oL inotifywait -m ...` | `qml/services/WatcherService.qml:117` | `inotify-tools`, `coreutils` |
| wall-ui: `steamcmd` | `qml/wallpaper/SteamWorkshopDownloadProc.qml:66` | `steamcmd` (non-free, i386 only) |
| wall-ui: `bash -lc`, `sh -c`, `find`, `file`, `timeout`, `rm`, `mv` | `shell.qml:33,49,166`, `WallhavenService.qml:45`, `SteamWorkshopService.qml:132`, `FileMetadataService.qml:74` | `bash`, `dash`, `findutils`, `file`, `coreutils` |
| wall-ui: `ryoku-hub desktop matugen set`, `ryoku-hub rice files`, `ryoku-shell matugen-preview`, `brightnessctl` | `qml/services/DaemonClient.qml:237`, `qml/wallpaper/RiceWorkshop.qml:58`, `qml/services/PalettePreview.qml:35` | Ryoku packages, `brightnessctl` |

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| go (make) | build (`PKGBUILD:40`) | `golang-go` | 2:1.24~2 | 2:1.27~1~bpo13+1 | 2:1.27~1 | 2:1.27~1 | 2:1.26~1 | 1.22 (`daemon/go.mod:3`) |
| wayland, wayland-protocols (make) | livewall (`PKGBUILD:30,41`) | see livewall | | | | | | |
| imagemagick | thumbnails/grading (`PKGBUILD:29`) | `imagemagick` | 8:7.1.1.43+dfsg1-1+deb13u12 | - | 8:7.1.2.31+dfsg1-1 | 8:7.1.2.33+dfsg1-1 | 8:7.1.2.18+dfsg1-1 | IM7 `magick` binary |
| ffmpeg | probe/transcode (`PKGBUILD:29`) | `ffmpeg` | 7:7.1.5-0+deb13u1 | - | 7:9.0.2-3 | 7:9.0.2-3 | 7:8.0.1-3ubuntu2 | |
| quickshell | wall-ui (`PKGBUILD:29`) | `quickshell` | - | 0.3.0-1~bpo13+1 | 0.3.2-1 | 0.3.2-1 | - | |
| curl | remote sources (`PKGBUILD:29`) | `curl` | 8.14.1-2+deb13u5 | 8.21.0-2~bpo13+1 | 8.22.0-1 | 8.23.0-1 | 8.18.0-1ubuntu2.8 | |
| inotify-tools | folder watcher (`PKGBUILD:26-29`) | `inotify-tools` | 4.23.9.0-2+b1 | - | 4.25.9.0-1+b1 | 4.25.9.0-1+b1 | 4.25.9.0-1 | |
| matugen | palette on apply (`PKGBUILD:21-22`) | none | - | - | - | - | - | see daemon section |
| waifu2x-ncnn-vulkan | upscale (`upscale.go:68`; `system/packages/base.packages:263-265`) | none | - | - | - | - | - | upstream nihui/waifu2x-ncnn-vulkan `20250915` (Arch 20250915) |
| (Steam) steamcmd | Workshop downloads | `steamcmd` (non-free, i386) | 0~20180105-5 | - | 0~20180105-5 | 0~20180105-5 | 0~20180105-5build1 | |
| brightnessctl | wall-ui | `brightnessctl` | 0.5.1-3.1+b1 | - | 0.5.1-3.1+b2 | 0.5.1-3.1+b2 | 0.5.1-3.1build1 | |

**As-is on Debian:** PARTIAL: daemon builds with trixie's own Go 1.24; upscaling
and Steam Workshop need packaging and path work.

**Port steps:**
1. `debian/rules`: `cd ryoku/shell/ryogami/daemon && CGO_ENABLED=0 GOTOOLCHAIN=local go build -trimpath -mod=vendor -o $(CURDIR)/build/ryogami .`
   then `ryoku/shell/livewall/build.sh $(CURDIR)/build/ryogami-live`.
2. Install as `PKGBUILD:44-60`: `/usr/bin/ryogami`, `/usr/bin/ryogami-live`,
   `/usr/lib/systemd/user/ryogami.service`, `wall-ui/.` to `/usr/share/ryogami/`,
   `/usr/share/applications/ryogami-wall.desktop`, license.
3. `Depends: imagemagick, ffmpeg, quickshell, curl, inotify-tools, coreutils,
   procps, matugen`; `Recommends: waifu2x-ncnn-vulkan`; `Suggests: steamcmd`.
4. Build `waifu2x-ncnn-vulkan` .deb: upstream
   `https://github.com/nihui/waifu2x-ncnn-vulkan` tag `20250915`, CMake in
   `src/`, ncnn from the bundled git submodule (Debian has no `libncnn-dev`),
   Build-Depends `cmake, g++, libvulkan-dev, glslang-dev, glslang-tools,
   libwebp-dev`; `git submodule update --init --recursive`, `cmake -S src -B
   build -DCMAKE_BUILD_TYPE=Release && cmake --build build`; install the binary
   to `/usr/bin/waifu2x-ncnn-vulkan` and `models/models-cunet` (plus the other
   model dirs) to `/usr/share/waifu2x-ncnn-vulkan/` so `upscale.go:68` resolves.
5. `steamcmd` on Debian: `dpkg --add-architecture i386`, enable `non-free`
   (Ubuntu: `multiverse`), and either add `/usr/games` to the session `PATH`
   (`environment.d/ryoku-session.conf:16`:
   `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin` ->
   `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/games`) or change
   `SteamWorkshopDownloadProc.qml:66` to resolve `/usr/games/steamcmd`.
6. Steam root: add `~/.steam/debian-installation` (and `~/.steam/steam`) to the
   default chain in `wall-ui/qml/Config.qml:101`, or seed `paths.steam`.

**Complexity:** Medium (two foreign tools; daemon itself is trivial).

**Issues / risks:**
- Debian's `/etc/ImageMagick-7/policy.xml` carries resource limits (memory,
  width/height, area, disk) that Arch's stock policy does not; very large
  source wallpapers can fail thumbnailing with "cache resources exhausted".
  The in-repo cage `ryoku/hyprland/scripts/magick-policy/policy.xml` is applied
  only via `MAGICK_CONFIGURE_PATH` by `cliphist-thumbs.sh:1-5` when run from the
  hypr scripts dir, not by ryogami.

---

### Palette bridge (`ryoku/palette-bridge`)

**What it does:** Stdlib-only Go HTTP server on `127.0.0.1:47616`
(`main.go:241`) publishing the wallpaper palette (reads
`$XDG_CACHE_HOME/ryoku/...`, `main.go:236`) to Spotify (spicetify extension),
Vesktop and Zen; `/healthz`, `/v1/palette` (`doctor.sh:55-62`). User unit
`packaging/systemd/ryoku-palette-bridge.service` (`WantedBy=default.target`).
`install-integrations.sh` wires spicetify (`:87-95`), Vesktop quickCss +
theme (`:99-110`), Zen `userChrome.css`/`user.js` in the detected profile under
`~/.config/zen` (`:112-170`); `remove-integrations.sh` undoes them and runs
`ryoku materialize` / `ryogami wallpaper repaint` (`:90-92`).

**Arch couplings:** none in code. `go.mod` has no requirements and no vendor
dir; `PKGBUILD:24` still passes `-mod=vendor` (works with zero requirements).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| go (make) | build (`PKGBUILD:24`) | `golang-go` | 2:1.24~2 | 2:1.27~1~bpo13+1 | 2:1.27~1 | 2:1.27~1 | 2:1.26~1 | 1.24 (`go.mod:3`) |
| curl, systemd, jq | `doctor.sh:18-28` | `curl`, `systemd`, `jq` | 8.14.1 / 257.13 / 1.7.1 | | 8.22.0 / 262 / 1.8.2 | | 8.18.0 / 259.9 / 1.8.1 | |
| spicetify, spotify, vesktop, zen (user-installed) | integrations | none packaged (`spotify-client` comes from Spotify's own apt repo; Vesktop/Zen via Flatpak/upstream) | - | - | - | - | - | |

**As-is on Debian:** YES.

**Port steps:**
1. `cd ryoku/palette-bridge && CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o build/ryoku-palette-bridge .`
2. Install as `PKGBUILD:27-40` (binary, `ryoku-palette-bridge-doctor`,
   `ryoku-palette-bridge-remove-integrations`, user unit, `/usr/share/ryoku/palette-bridge`, license).

**Complexity:** Low.

**Issues / risks:**
- Zen profile detection only looks in `$XDG_CONFIG_HOME/zen`
  (`install-integrations.sh:112-125`); a Flatpak Zen keeps profiles under
  `~/.var/app/app.zen_browser.zen/...` and needs `ZEN_PROFILE_ROOT`. Same on
  Arch with Flatpak; on Debian Flatpak is the likely Zen source.

---

### Shell helper scripts (`ryoku/shell/scripts`, `ryoku/shell/bin`)

**What it does:** Leaf tools the bar, launcher, Hub, keybinds and daemon call by
bare name; all `ryoku-*` and `*.sh` plus `ryostage` install to `/usr/bin` from
`ryoku-shell` (`release/packages/ryoku-shell/PKGBUILD:39-60`); the three AI
collectors go to `/usr/bin` from `ryoku-desktop` (`ryoku-desktop/PKGBUILD:481-487`).
Shebangs: `#!/bin/bash` or `#!/usr/bin/env bash` (bash 5 features: `mapfile`,
`{fd}<`), `cliphist-thumbs.sh` is `#!/bin/sh`, collectors are Python 3 stdlib.

**Arch couplings:**
- `ryoku-sysinfo:71` `pacman -Qq | wc -l` (package count on the profile plate).
- `ryoku-profile-stats:51-52` `pacman -Qen | wc -l`, `pacman -Qm | wc -l`
  (explicit native / foreign counts behind the "package wave",
  `docs/profile.md:39`).
- `stash-install.sh:40,50,57-58,350-366,387-388`: classifies
  `*.pkg.tar.{zst,xz,gz}` and `.PKGINFO` tarballs as `pacman` and installs with
  `pkexec pacman -U --noconfirm`; `.deb` and `.rpm` are only unpacked with
  `bsdtar` into a per-user app store (`:308-336`), never installed with dpkg.
  Comment `:304` assumes bsdtar is "always around via pacman".
- `ryostage:362` message `install it: sudo pacman -S uv`.
- `ryoku-cmd-folders:36` uses `strtonum()`, a gawk extension. Debian's default
  `awk` is `mawk` (Arch's is gawk); under mawk the awk program errors, `color`
  is empty and the script silently falls back to blue folders (`:40`).
- `ryoku-sysinfo:58` reads `PRETTY_NAME` from `/etc/os-release` for display
  only (no ID check).

**External commands per family:**

| Family | Commands (cite) | Debian packages |
|---|---|---|
| Recorder chain: `ryoku-cmd-screenrecord`, `-studiorecord`, `-recording-saved`, `-edit-recording`, `-discord-compress` | `gpu-screen-recorder -w <out|screen|region|portal> -f -fm -q -k -encoder -c mp4 -cursor [-region WxH+X+Y] [-a default_output|default_input] [-sc hook] [-restore-portal-session yes] -o` (`ryoku-cmd-screenrecord:630-639,689-695`), `--list-capture-options` (`:202`); `wf-recorder -r -o -g --audio[=dev] -c h264_vaapi -d <node> -p qp= -F scale_vaapi=format=nv12` / `-c libx264 -p preset=veryfast -p crf=` (`:792-824`); `slurp -f "%wx%h+%x+%y"` (`:314`); `pactl get-default-sink/-source` (`:381-389`); `ryoku-hub outputs` + `jq` (`:362-365`); `pgrep`/`pkill`/`pidof` (`:90-146`); `timeout`; `notify-send -a ryoku --action=...` (`ryoku-cmd-recording-saved:69`); `ffprobe` (`:50`, `ryoku-cmd-discord-compress:67`); `ffmpeg -c:v libx264 ... -pass 1/2 -c:a aac` (`ryoku-cmd-discord-compress:112-118`); `ryomotion` (`ryoku-cmd-edit-recording:49`, `ryoku-cmd-studiorecord:123-124`); `ryoku-cursor-track` (`ryoku-cmd-studiorecord:54-63`, lives in `ryoku/hyprland/scripts/ryoku-cursor-track`, uses `hyprctl cursorpos`); `setsid`, `xdg-open`, `wl-copy`, `numfmt`, `stat` | `gpu-screen-recorder-cli` (forky/sid only), `wf-recorder`, `slurp`, `pulseaudio-utils`, `jq`, `procps`, `coreutils`, `util-linux`, `libnotify-bin`, `ffmpeg`, `xdg-utils`, `wl-clipboard` |
| Screen tools | `zbarimg --raw` (`ryoku-cmd-qr-scan:34`), `tesseract <img> -` (`ryoku-cmd-ocr:36`), `ryoku-shell clip-copy` (`:47`), `hyprpicker -f hex` (`ryoku-cmd-color-picker:18`), `songrec recognize` (`ryoku-cmd-songrec:13`), `curl -F files[]=@ https://uguu.se/upload` + `jq` + `xdg-open` (`ryoku-cmd-google-lens:37-46`), `grim -g`, `slurp` | `zbar-tools`, `tesseract-ocr`, `tesseract-ocr-eng`, `hyprpicker` (trixie-bpo+), `songrec` (none), `curl`, `jq`, `xdg-utils`, `grim`, `slurp`, `wl-clipboard`, `libnotify-bin` |
| Toggles | `brightnessctl -d <dev> set N%+/-` (`ryoku-cmd-brightness:27-29`), `ddcutil detect --brief`, `ddcutil --bus N --noverify setvcp 10 +/- N` (`:58,66`), `flock`, `cksum`; `ryoku wm caps` / `ryoku wm act nightlight.on|off` + `pgrep -x` (`ryoku-cmd-nightlight:36,43,60,69`); `systemd-run --user --collect` + `systemd-inhibit --what=idle:sleep` (`ryoku-cmd-caffeine:66-80`); `powerprofilesctl get/set` (`ryoku-cmd-game-mode:104-108`), `pkexec ryoku-wifi-powersave` (`:145`), `ryoku-game-tune`, `ryoku-idle on-battery`, `ryoku wm status/act`; Papirus copy + `gtk-update-icon-cache -qf` + `gsettings set ... icon-theme` (`ryoku-cmd-folders:19,84,101`) | `brightnessctl`, `ddcutil`, `util-linux`, `systemd`, `power-profiles-daemon` (ships `powerprofilesctl`), `pkexec`, `papirus-icon-theme`, `gtk-update-icon-cache`, `libglib2.0-bin`, `gawk` |
| Radio | `mpv --no-video --no-terminal --really-quiet` (`ryoku-cmd-radio:218`), `yt-dlp -q -f bestaudio/best --print urls --print thumbnail` under `timeout --foreground` (`:90`), `jq`, `setsid -f`, `flock`, `ps -o pgid=` | `mpv`, `yt-dlp`, `jq`, `util-linux`, `procps`, `coreutils` (`mpv-mpris` from `ryoku-desktop/PKGBUILD:103-104`) |
| Calculator | `qalc -t` (`ryoku-cmd-calc:31`), `python3` AST fallback (`:43`) | `qalc`, `python3` |
| Equalizer `ryoku-eq` | writes a PipeWire `filter-chain` config with `bq_peaking` bands and `filter.smart*` props (`ryoku-eq:76-136`), `systemctl --user restart ryoku-eq.service` (`:180`), `pw-dump`, `pw-cli s <id> Props`, `pw-metadata -n filters <id> filter.smart.target/.disabled` (`:70,149,162,193,210`), `pactl get-default-sink` (`:67`), `jq` | `pipewire-bin`, `wireplumber`, `pulseaudio-utils`, `jq` |
| Stage engine `ryostage` | `python3.13/3.12/3.11/python3 -m venv` (`:63,80,335-354`), `uv python install 3.13 && uv venv --python 3.13` (`:359`), `pip install rembg[cpu]` (`:383`), embedded Python using `rembg`, `numpy`, `PIL`, `scipy` (`:186-205,263-318`); state `~/.local/state/ryoku/ryostage/{venv,models}` (`docs/stage.md:21,212`) | `python3`, `python3.13-venv` / `python3-venv`, `uv` (forky/sid only) |
| Stash + LocalSend | `yt-dlp --no-playlist ...` (`stash-download.sh:25`); `ffmpeg -c:v libx264 / libwebp`, `magick -strip` (`stash-compress.sh:40-44`); `curl` + `jq` against a cobalt API (`stash-cobalt.sh:19,37-123`); `docker run -d --name ryoku-cobalt -p 127.0.0.1:9000:9000 ghcr.io/imputnet/cobalt:11` or helper `ryoku-docker` (`stash-cobalt-server.sh:15-22,96`); `bsdtar`, `flatpak install --user`, `pkexec pacman -U`, AppImage `--appimage-extract` (`stash-install.sh:158-191,316,342,358`); LocalSend v2 protocol implemented in `python3` stdlib + `curl -sk` + `openssl req/rand` + `file -b --mime-type` (`localsend.sh:13-25,116-126`) | `yt-dlp`, `ffmpeg`, `imagemagick`, `curl`, `jq`, `docker.io`, `libarchive-tools`, `flatpak`, `python3`, `openssl`, `file` |
| `cliphist-thumbs.sh` | `cliphist list/decode`, `magick` (`:17,33-34`) | `cliphist`, `imagemagick` |
| `ryoku-app`, `ryoku-summon`, `ryoku-sysinfo`, `ryoku-profile-stats`, `ryoku-reload-cover` | `jq`, `notify-send`, fallbacks `zen`/`zen-browser`/`chromium`/`kitty`/`nautilus` (`ryoku-app` fallback block); `ryoku wm act window.summon`; `lspci` (`ryoku-sysinfo:13`), `ryoku-hub outputs` (`:40`), `free`, `df`, `nproc`, `hostname`, `pacman` (`:71`); hwmon/power_supply sysfs, `ps -e`, `ryoku wm status` (`ryoku-profile-stats:38`), `pacman` (`:51-52`); `qs -p <dir> ipc call reload-cover ...`, `setsid env ... qs -p` (`ryoku-reload-cover:41-44,109`), `od`, `jq` | `jq`, `libnotify-bin`, `pciutils`, `procps`, `coreutils`, `hostname`, `quickshell`, `util-linux` |
| AI usage collectors (`ryoku/shell/bin`) | Python 3 stdlib (`json`, `sqlite3`, `urllib`, `subprocess`), optional `claude --version`, `codex` (`claude-usage:13-25`, `codex-usage:11,50,113`, `opencode-usage:10-16`) | `python3` |

**Dependencies (packages and versions):**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| gpu-screen-recorder | recorder (`ryoku-cmd-screenrecord:630`) | `gpu-screen-recorder-cli` | - | - | 5.13.8-1+b1 | 5.13.8-2 | - | every flag Ryoku passes (`-region`, `-restore-portal-session`, `-fm`, `-encoder`, `-sc`, `-cursor`, `--list-capture-options`) is present in 5.13.8's `src/args_parser.c`; Arch 6.1.4 |
| wf-recorder | fallback recorder (`:792-824`) | `wf-recorder` | 0.5.0-2 | - | 0.6.0-1+b2 | 0.6.0-1+b2 | 0.6.0-1build1 | |
| grim / slurp | region capture | `grim` / `slurp` | 1.4.0+ds-2+b2 / 1.5.0-1+b1 | - | 1.5.0+ds-1 / 1.6.0really1.5.0-1 | same | 1.4.0+ds-2build3 / 1.6.0-1 | |
| libnotify | `notify-send --action` (`ryoku-cmd-recording-saved:69-73`) | `libnotify-bin` | 0.8.6-1 | - | 0.8.8-1+b1 | 0.8.8-1+b1 | 0.8.8-1 | `--action` (>= 0.7.10) |
| zbar | QR | `zbar-tools` | 0.23.93-8 | - | 0.23.93-10 | 0.23.93-10 | 0.23.93-9ubuntu1 | |
| tesseract, tesseract-data-eng | OCR | `tesseract-ocr`, `tesseract-ocr-eng` | 5.5.0-1+b1, 1:4.1.0-2 | - | 5.5.0-1.1 | 5.5.0-1.1 | 5.5.0-1build1 | |
| hyprpicker | colour picker | `hyprpicker` | - | 0.4.7-1~bpo13+1 | 0.4.7-1+b2 | 0.4.7-1+b2 | 0.4.6-1 | |
| songrec | music ID | none | - | - | - | - | - | upstream marin-m/SongRec 0.7.6 (Arch extra 0.7.5); `rust-version = "1.88"`, edition 2024 |
| brightnessctl | backlight | `brightnessctl` | 0.5.1-3.1+b1 | - | 0.5.1-3.1+b2 | 0.5.1-3.1+b2 | 0.5.1-3.1build1 | |
| ddcutil | DDC/CI | `ddcutil` | 2.2.0-2 | 2.2.7-1~bpo13+1 | 2.2.7-1 | 2.2.7-1 | 2.2.5-1 | |
| papirus-icon-theme | folder tints (`ryoku-cmd-folders:19`) | `papirus-icon-theme` | 20250501-1 | - | 20260801-1 | 20260801-1 | 20250501+git20260316-0ubuntu1 | same `/usr/share/icons/Papirus` path |
| gawk | `strtonum` (`ryoku-cmd-folders:36`) | `gawk` | 1:5.2.1-2+b2 | - | 1:5.3.2-1+b1 | 1:5.3.2-1+b1 | 1:5.3.2-1ubuntu1.1 | gawk must be the `awk` alternative, or call `gawk` explicitly |
| mpv, mpv-mpris, yt-dlp | radio, stash | `mpv`, `mpv-mpris`, `yt-dlp` | 0.40.0-3+deb13u1, 0.7.1-1+b2, 2025.04.30-1 | -, 1.2-1~bpo13+1, 2026.08.19-1~bpo13+1 | 0.41.0-2+b4, 1.3-1+b1, 2026.08.19-1 | same | 0.41.0-2ubuntu4, 1.2-1, 2026.08.19-1~bpo26.04.1 | yt-dlp must be current for YouTube; trixie's 2025.04.30 is not |
| libqalculate | calculator | `qalc` | 5.5.2-1+b1 | - | 5.13.2-1 | 5.13.2-1 | 5.9.0-1 | |
| pipewire, wireplumber | `ryoku-eq` smart filter | `pipewire-bin`, `wireplumber` | 1.4.2-1, 0.5.8-2 | 1.6.9-2~bpo13+1, 0.5.12-1~bpo13+1 | 1.6.9-2, 0.5.18-1 | same | 1.6.2-1ubuntu1.3, 0.5.13-1ubuntu1.1 | WirePlumber 0.5 smart-filter policy (`filter.smart`, `pw-metadata -n filters`) |
| python, uv | ryostage, collectors, localsend, calc | `python3`, `python3.13-venv`, `uv` | 3.13.5-1, 3.13.5-2+deb13u5, - | - | 3.14.7-3, 3.13.15-1, 0.9.17+ds1-6 | same | 3.14.3-0ubuntu2, -, - | ryostage accepts only Python 3.11-3.13 (`ryostage:339`) |
| jq | everywhere | `jq` | 1.7.1-6+deb13u3 | - | 1.8.2-1 | 1.8.2-1 | 1.8.1-4ubuntu2 | |
| cliphist | `cliphist-thumbs.sh` | `cliphist` | 0.5.0-1+b9 | - | 0.5.0-1+b11 | 0.5.0-1+b11 | 0.5.0-1build1 | |
| imagemagick | thumbs, stash | `imagemagick` | 8:7.1.1.43+dfsg1-1+deb13u12 | - | 8:7.1.2.31+dfsg1-1 | 8:7.1.2.33+dfsg1-1 | 8:7.1.2.18+dfsg1-1 | `magick` (IM7) |
| docker | cobalt container | `docker.io` | 26.1.5+dfsg1-9+deb13u1 | - | 28.5.2+dfsg4-5 | 28.5.2+dfsg4-5 | 29.1.3-0ubuntu4.1 | |
| libarchive | `bsdtar` | `libarchive-tools` | 3.7.4-4+deb13u1 | - | 3.8.9-1 | 3.8.9-1 | 3.8.5-1ubuntu2.3 | |
| pciutils, procps, coreutils, util-linux, file, openssl, curl, xdg-utils, systemd, pkexec | misc | same names | 1:3.13.0-2, 2:4.0.4-9, 9.7-3, 2.41.5, 1:5.46-5, 3.5.7, 8.14.1, 1.2.1-2, 257.13, 126-2 | | 1:3.15.0-2, 2:4.0.7-1, 9.10-1, 2.42.4, 1:5.47-4, 3.6.5, 8.22.0, 1.2.1-2, 262, 127-3 | | 1:3.14.0-1build2, 2:4.0.4-9ubuntu1, 9.7-3ubuntu2.1, 2.41.3, 1:5.46-5build2, 3.5.5, 8.18.0, 1.2.1-2ubuntu2, 259.9, 127-2ubuntu1.1 | |

**As-is on Debian:** PARTIAL: most scripts run unchanged; the pacman calls,
gawk dependency, recorder capabilities and four unpackaged tools differ.

**Port steps:**
1. `ryoku-sysinfo:71`: `pacman -Qq 2>/dev/null | wc -l` ->
   `dpkg-query -f '${binary:Package}\n' -W 2>/dev/null | wc -l`.
2. `ryoku-profile-stats:51`: `pacman -Qen | wc -l` (explicit, from repos) ->
   `apt-mark showmanual 2>/dev/null | wc -l`; `:52` `pacman -Qm | wc -l`
   (foreign, in no repo) -> `apt list --installed 2>/dev/null | grep -c ',local\]'`
   (apt marks packages with no archive origin `[installed,local]`).
3. `stash-install.sh`: add a `deb` branch that installs natively, mirroring
   `install_pacman` (`:350-362`):
   `pkexec apt-get install -y "$src"` (absolute path) and read the name with
   `dpkg-deb -f "$src" Package`; keep the current `pacman` branch or route
   `.pkg.tar.*` to the existing tarball extraction. Fix comment `:304`; add
   `libarchive-tools` to Depends.
4. `ryoku-cmd-folders:36`: depend on `gawk` and change `awk -v c=...` to
   `gawk -v c=...` (or replace `strtonum("0x" ...)` with a hex lookup that mawk
   accepts).
5. `ryostage:362` message -> `sudo apt install python3.13-venv` (trixie, forky,
   sid) / `uv`; extend `pick_python`'s accepted versions (`:339`
   `3.11 | 3.12 | 3.13`) to include `3.14` if resolute must work without uv
   (onnxruntime 1.31.0 publishes `cp314` manylinux_2_28 wheels; rembg 2.0.85
   `requires_python >=3.11,<4.0`). Resolute has no `python3.13` and no `uv`.
6. `gpu-screen-recorder`: forky/sid use `gpu-screen-recorder-cli`; trixie and
   resolute need a backport/build: upstream `https://git.dec05eba.com/gpu-screen-recorder`
   (latest tag 6.1.4; Debian's packaging `salsa.debian.org/amin_modaresi/gpu-screen-recorder`,
   meson), Build-Depends exactly as Debian's `debian/control`: `meson, pkgconf,
   libwayland-bin, libavcodec-dev, libavformat-dev, libavutil-dev, libx11-dev,
   libxcomposite-dev, libxrandr-dev, libxfixes-dev, libpulse-dev,
   libswresample-dev, libavfilter-dev, libva-dev, libdrm-dev, libwayland-dev,
   libcap-dev, libpipewire-0.3-dev, libspa-0.2-dev, libdbus-1-dev,
   libxdamage-dev, libvulkan-dev`.
7. Capability for KMS capture: Arch runs `setcap cap_sys_admin=ep
   usr/bin/gsr-kms-server` in `gpu-screen-recorder.install` `post_install`;
   upstream's meson option `capabilities` does the same at `meson install`
   (`meson_options.txt`, `meson.build:125-126`). Debian's package has no
   postinst setcap and dpkg does not carry file capabilities, so every KMS
   recording (Ryoku's default backend, `ryoku-cmd-screenrecord:14-22`) prompts
   for a password through pkexec. Reproducing Arch: a postinst
   `setcap cap_sys_admin=ep /usr/bin/gsr-kms-server` (Depends `libcap2-bin`) in
   a Ryoku package or a rebuilt gsr package (see Questions).
8. `songrec` .deb: upstream `https://github.com/marin-m/SongRec` tag `0.7.6`,
   `cargo build --release --locked`; needs rustc >= 1.88 (trixie-bpo 1.96 or
   `rustc-web` 1.96; trixie's 1.85 too old); default features
   `gui ffmpeg pulse mpris pipewire` need `libgtk-4-dev` (gtk4 `v4_14`) and
   `libadwaita-1-dev` >= 1.8 (`v1_8`): trixie has libadwaita 1.7.6, so on
   trixie build CLI-only (`--no-default-features --features ffmpeg,pulse`); the
   shell only calls `songrec recognize` (`ryoku-cmd-songrec:13`). Other
   Build-Depends: `libasound2-dev, libpulse-dev, libssl-dev, libdbus-1-dev,
   pkgconf`. Ubuntu also has upstream PPA `ppa:marin-m/songrec`.
9. `hyprpicker` on trixie: from `trixie-backports` (0.4.7).
10. `yt-dlp` on trixie: from `trixie-backports` (2026.08.19).

**Complexity:** Medium.

**Issues / risks:**
- `cliphist-thumbs.sh` has no caller in the repo (grep of `*.qml *.js *.go
  *.lua *.kdl`: none) while `docs/launcher.md:93` documents the `;` clipboard
  mode as "cliphist history"; the daemon owns history itself (`clipboard.go`)
  and `cliphist` is only a package dependency (`ryoku-desktop/PKGBUILD:110`).
- `system/packages/base.packages:186` says the cobalt script lives at
  `ryoku/hyprland/scripts/stash-cobalt-server.sh`; it is at
  `ryoku/shell/scripts/stash-cobalt-server.sh`.
- `ryoku-cursor-track` (studio recording zoom) is Hyprland-only (`hyprctl
  cursorpos`) and ships from the Hyprland tree, not with the shell.
- `stash-install.sh`'s AppImage path runs `--appimage-extract` only; running the
  installed AppImage needs FUSE 2 (`libfuse2t64`), not installed by default on
  Debian.
- trixie `python3.13 -m venv` fails without `python3.13-venv`
  (ensurepip split); `ensure_venv` then falls through to `uv`, absent on
  trixie (`ryostage:350-363`).

**Questions for the human:**
- gsr `cap_sys_admin`: (a) set it in postinst like Arch: password-free KMS
  capture, `gsr-kms-server` runs with CAP_SYS_ADMIN for every user; (b) leave
  Debian's default: pkexec prompt on each KMS recording, or switch Ryoku's
  default backend to `portal` (`RYOKU_SCREENRECORD_BACKEND`,
  `ryoku-cmd-screenrecord:22`), which shows the portal picker once.
- `ryoku-profile-stats` "foreign" count: Debian has no AUR; `[installed,local]`
  counts manually installed .debs, which is the nearest equivalent. Keep the
  plate field with that meaning or relabel it (QML label is 09a scope).

---

### ryomotion (`release/packages/ryomotion/PKGBUILD`, upstream ryoku-dev/ryomotion)

**What it does:** Electron screen-demo recorder/editor (OpenScreen fork),
built at `_commit=60ea129dabfed8c4936aa6264dc43452c1ed8ab5` (`PKGBUILD:32`)
with a downloaded `node-v22.22.1-linux-x64` (`PKGBUILD:33-35,43`): `npm ci`,
`npm run build-vite`, `electron-builder --linux dir` with productName/
executableName/appId overrides (`PKGBUILD:49-57`), installed to `/opt/ryomotion`
with `/usr/bin/ryomotion` symlink, a hand-written `.desktop` and icons
(`PKGBUILD:60-88`). Upstream `package.json`: `ryomotion` 1.5.0, `electron
^41.2.1`, `electron-builder ^26.8.1`, `vite ^7.3.2`, `esbuild ^0.27.0`.
`electron/recording/linuxCapture.ts` spawns `gpu-screen-recorder` (override
`OPENSCREEN_GSR_EXE`, line 16) with `-w -f -fm -q -k -c -cursor -a -o`
(lines 90-120) and lists monitors with `hyprctl monitors -j` (line 62).

**Arch couplings:** none in the build beyond PKGBUILD form.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| gtk3 | Electron | `libgtk-3-0t64` | 3.24.49-3 | - | 3.24.52-2 | 3.24.52-2 | 3.24.52-0ubuntu1 | |
| nss | Electron | `libnss3` | 2:3.110-1+deb13u4 | - | 2:3.130-1 | 2:3.131-1 | 2:3.120-1ubuntu2.1 | |
| alsa-lib | Electron | `libasound2t64` | 1.2.14-1+deb13u1 | 1.2.16.1-1~bpo13+1 | 1.2.16.1-2 | 1.2.16.1-2 | 1.2.15.3-1ubuntu1.1 | |
| libnotify | Electron | `libnotify4` | 0.8.6-1 | - | 0.8.8-1+b1 | 0.8.8-1+b1 | 0.8.8-1 | |
| pipewire, xdg-desktop-portal | screen capture fallback | `pipewire`, `xdg-desktop-portal` | 1.4.2 / 1.20.3+ds-1 | | 1.6.9 / 1.22.1+ds-1 | | 1.6.2 / 1.21.1+ds-1ubuntu3.1 | |
| gpu-screen-recorder | native capture (`PKGBUILD:28-29`) | `gpu-screen-recorder-cli` | - | - | 5.13.8-1+b1 | 5.13.8-2 | - | |
| (electron-builder deb defaults) | - | `libxss1, libxtst6, xdg-utils, libatspi2.0-0t64, libuuid1, libsecret-1-0` | present | | present | | present | |

**As-is on Debian:** PARTIAL (needs gsr on trixie/resolute; build recipe is
distro-neutral).

**Port steps:**
1. Same build as `PKGBUILD:41-58` (fetch node 22.22.1 tarball, sha256
   `9a6bc82f...ba3aa`), then either keep `--linux dir` and wrap `/opt/ryomotion`
   in a debhelper package, or call `electron-builder --linux deb` with the same
   `--config.*` overrides (electron-builder has a native `deb` target; add
   `--config.deb.depends` for `gpu-screen-recorder-cli`).
2. `options=('!strip')` -> `override_dh_strip:` and `override_dh_shlibdeps:`
   empty (prebuilt Electron binaries), explicit `Depends:` from the table.

**Complexity:** Medium (network build: npm + Electron download).

**Issues / risks:**
- Monitor discovery via `hyprctl` (`linuxCapture.ts:62`) means native capture
  has no monitor list under niri (same on Arch).

---

### ryotunes (external: github.com/ryoku-dev/ryotunes)

**What it does:** Ryoku's music app, released on its own cadence; the
`[ryoku]` repo imports the prebuilt `ryotunes-<ver>-<rel>-x86_64.pkg.tar.zst`
from GitHub releases, verifies sha256 and `.PKGINFO` (epoch 1) and re-signs it
(`release/repo/import-ryotunes.sh:8-22,59-80`, `build-repo.sh:202-204`).
`ryoku update` installs newer releases with `pacman -U`
(`docs/updates.md:55-82`, `ryoku/cli/internal/updater/ryotunes.go:14-17`).
Upstream v1.2.1 (2026-10-17) assets: `.pkg.tar.zst`, `.pkg.tar.zst.sha256`,
source `.tar.gz` (+sha256). Rust workspace (`rust-version = "1.80"`,
edition 2021), Tauri 2.11.5 / wry 0.55.1, `libmpv2` crate 4.1.0 (links
libmpv), `souvlaki` (MPRIS over zbus), `webkit2gtk` 2.0 `v2_40`, Svelte UI via
pnpm; crates `ryotunesd`, `ryotunes-cli`, `sync-server`; ships a quickshell UI
(`packaging/linux/ryotunes-qml`) and `ryotunesd.socket/.service` user units.
Upstream Arch PKGBUILD depends: `webkit2gtk-4.1 libappindicator-gtk3 mpv yt-dlp
ffmpeg openssl librsvg desktop-file-utils hicolor-icon-theme xdg-utils polkit
quickshell`; makedepends `cargo nodejs pnpm appmenu-gtk-module xdotool`;
`ryotunes.install` enables `ryotunesd.socket` globally and per logged-in user
via `systemctl --user -M uid@`. matugen renders its skin to
`~/.config/ryotunes/skins/matugen/skin.json` (`docs/theming.md:24-25`).

**Arch couplings:**
- Only an Arch package is published; the importer requires `bsdtar` + `.PKGINFO`
  (`import-ryotunes.sh:59`), and the updater uses `pacman -U` / pacman metadata.
- Doc vs code: `docs/updates.md:80-82` says the `[ryoku]` repo "still builds
  the `ryotunes` package (a sha256-pinned source tarball)"; the code imports the
  prebuilt release (`import-ryotunes.sh:8-13`, `build-repo.sh:202-204`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| webkit2gtk-4.1 | Tauri webview | `libwebkit2gtk-4.1-dev` / `-0` | 2.52.6-1~deb13u1 | - | 2.52.6-1 | 2.54.1-1 | 2.52.6-0ubuntu0.26.04.1 | `v2_40` feature |
| mpv | `libmpv2` crate | `libmpv-dev` / `libmpv2` | 0.40.0-3+deb13u1 | - | 0.41.0-2+b4 | 0.41.0-2+b4 | 0.41.0-2ubuntu4 | |
| libappindicator-gtk3 | tray | `libayatana-appindicator3-dev` / `-1` | 0.5.94-1 | - | 0.5.94-1.1 | 0.5.94-1.1 | 0.5.94-1build1 | |
| librsvg | icons | `librsvg2-dev` | 2.60.0+dfsg-1 | - | 2.63.2+dfsg-1 | 2.63.2+dfsg-1 | 2.61.3+dfsg-3ubuntu0.1 | |
| cargo | build | `cargo`/`rustc` | 1.85.1 | 1.96.1 | 1.96.1 | 1.97.1 | 1.93.1 | 1.80 |
| nodejs, pnpm | UI build | `nodejs` / pnpm none | 20.19.2 | - | 24.21.0 | 24.22.0 | 22.22.1 | pnpm via corepack/npm |
| xdotool | build | `libxdo-dev` | 1:3.20160805.1-5.1 | | | | | |
| yt-dlp, ffmpeg, quickshell, polkit, desktop-file-utils, xdg-utils | runtime | same names | | | | | | |

**As-is on Debian:** NO (no Debian artifact upstream; update path is pacman).

**Port steps:**
1. Build from the release source tarball: `cd ui && pnpm install
   --frozen-lockfile && pnpm build`, then `cargo build --release --locked
   --package ryotunes --package sync-server --package ryotunesd --package
   ryotunes-cli` (upstream `packaging/arch/PKGBUILD` `build()`), install the
   same files the Arch package does (binaries, `ryotunes-qml`, desktop file,
   metainfo, `ryotunesd.{socket,service}`).
2. Port `ryotunes.install` to `postinst`/`prerm`/`postrm` (the systemd commands
   are distro-neutral; `gtk-update-icon-cache`/`update-desktop-database` become
   dpkg triggers).
3. Updater/importer change belongs to the update-delivery report
   (`docs/05-update-delivery.md` row "Ryotunes external channel").

**Complexity:** High.

**Questions for the human:**
- Source of the Debian ryotunes: (a) ask upstream ryoku-dev/ryotunes to publish
  a `.deb` asset beside the `.pkg.tar.zst` (Tauri can bundle `--bundles deb`),
  keeping the "external channel" model with `apt install ./file.deb` replacing
  `pacman -U`; (b) build it in the Debian Ryoku repo from the source tarball,
  making it an ordinary repo package and dropping the separate channel.

---

### Shell systemd user session (`ryoku/shell/systemd`, `ryoku/shell/environment.d`)

**What it does:**
- `ryoku-session.target`: `BindsTo=graphical-session.target`,
  `Wants=graphical-session-pre.target graphical-session.target`
  (`systemd/user/ryoku-session.target:1-6`). Started by
  `ryoku-power-cutover session-start-logged` from compositor autostart
  (`ryoku/hyprland/modules/autostart.lua:34`, `ryoku/niri/autostart.kdl:30`;
  system/hardware report). No uwsm anywhere in the repo (grep `uwsm`: no hit).
- Units `PartOf/After/WantedBy=ryoku-session.target`, `Slice=session.slice`,
  `ConditionEnvironment=WAYLAND_DISPLAY`: `ryoku-shell.service`
  (`ExecStartPre=-/usr/bin/ryoku-shell quit`, `ExecStartPre=/usr/bin/ryoku-qylock-activate`,
  `ExecStart=/usr/bin/ryoku-shell daemon`, `ExecStop=/usr/bin/ryoku-qylock-activate --prepare-stop`,
  `ExecStartPost=-/usr/bin/ryoku-power-cutover qylock-guards-stop`,
  `KillMode=process`, env `RYOKU_POLKIT_AGENT=1`, `QT_MEDIA_BACKEND=ffmpeg`,
  `QT_FFMPEG_DECODING_HW_DEVICE_TYPES=`; `ryoku-shell.service:1-44`),
  `ryogami.service` (`:1-29`), `ryoku-idle.service`, `ryoku-clamshell.service`.
- `ryoku-eq.service`: `/usr/bin/pipewire -c %t/ryoku/eq/filter-chain.conf`,
  `PartOf=pipewire.service` (`ryoku-eq.service:7-16`).
- `ryoku-bootstrap.service` (`ryoku materialize` once,
  `WantedBy=default.target`), `ryoku-ai-usage.{service,timer}`, drop-ins
  `xdg-desktop-portal-gnome.service.d/10-ryoku.conf` (`UnsetEnvironment=GDK_BACKEND`)
  and `niri.service.d/ryoku-bootstrap.conf`.
- `environment.d/ryoku-session.conf` (cursor, `QML_IMPORT_PATH`/`QML2_IMPORT_PATH=$HOME/.local/lib/qt6/qml`,
  `PATH`, `QT_QPA_PLATFORMTHEME=qt6ct`, `GDK_BACKEND`, `QT_QPA_PLATFORM`,
  `GSK_RENDERER=gl`, `RYOKU_POLKIT_AGENT=1`, `EDITOR=nvim`) installed to
  `/usr/lib/environment.d/99-ryoku-session.conf` and the config tree
  (`ryoku-desktop/PKGBUILD:385-386,494-495`).
- `user-environment-generators/60-ryoku-xdg-dirs` exports `XDG_*_DIR` via
  `xdg-user-dir` (`:17-25`).
- Delivery: the whole `systemd/user/` tree is copied to
  `/usr/share/ryoku/config/systemd/user` and reaches `~/.config/systemd/user`
  through `ryoku materialize` (`ryoku-desktop/PKGBUILD:468-473`); only
  `ryogami.service`, `ryoku-ai-usage.*`, `ryoku-bootstrap.service` also land in
  `/usr/lib/systemd/user` (`ryogami/PKGBUILD:49-50`, `ryoku-desktop/PKGBUILD:484-491`).

**Arch couplings:** none in the units: every directive used
(`ConditionEnvironment=`, `session.slice`, `environment.d`,
`user-environment-generators`, `UnsetEnvironment=`) is in systemd 257 (trixie),
259.9 (resolute), 262 (forky/sid).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| systemd | user manager | `systemd`, `dbus-user-session` | 257.13-1~deb13u1, 1.16.2-2 | - | 262-1, 1.16.2-8 | 262.1-1, 1.16.2-8 | 259.9-0ubuntu0.1, 1.16.2-2ubuntu4 | `ConditionEnvironment=` (>= 246) |
| xdg-user-dirs | generator (`60-ryoku-xdg-dirs:19-22`) | `xdg-user-dirs` | 0.18-2 | - | 0.20-1 | 0.20-1 | 0.19-1 | |
| pipewire | `ryoku-eq.service:13` | `pipewire-bin` (`/usr/bin/pipewire`) | 1.4.2-1 | 1.6.9-2~bpo13+1 | 1.6.9-2 | 1.6.9-2 | 1.6.2-1ubuntu1.3 | |

**As-is on Debian:** YES.

**Port steps:**
1. None in unit content. `/usr/bin/pipewire`, `/usr/bin/ryoku-*` paths hold.
2. Add `/usr/games` to `PATH` in `environment.d/ryoku-session.conf:16` if
   `steamcmd` (Ryogami) must resolve (see Ryogami section); Debian's default
   user `PATH` contains `/usr/games`, Ryoku's override drops it.

**Complexity:** Low.

**Issues / risks:**
- `ryoku-shell.service` is shipped by `ryoku-desktop` (config tree), not by the
  `ryoku-shell` package, and its `ExecStartPre`/`ExecStartPost` call
  `ryoku-qylock-activate` and `ryoku-power-cutover` from other packages; a
  Debian split must keep those binaries co-installed (`ryoku-desktop` pins
  `ryoku-shell=$pkgver`, `ryoku-desktop/PKGBUILD:25-29`).

---

## Cross-cutting findings

- **Qt private-ABI pinning is automatic on Debian.** Anything that links a
  `Qt_6_PRIVATE_API` symbol (quickshell, Hyprland plugins, any future Ryoku
  C++ module) gets `qt6-base-private-abi (= X)` / `qt6-declarative-private-abi (= X)`
  from `dpkg-shlibdeps` when built with debhelper. Ryoku packages that use
  private Qt API must be rebuilt in lockstep with Qt uploads on forky/sid; on
  trixie Qt stays 6.8.2 for the release. The Qt 5 style virtual
  `qtdeclarative-abi-6-8-2` does not exist.
- **QML install dir:** every Ryoku QML module (`Ryoku.Blobs`, `Ryoku.Ui`,
  `Ryoku.PluginKit`, `Ryoku.FrameBars`, `Ryoku.Wm.Hyprland`) is installed by
  PKGBUILDs to `/usr/lib/qt6/qml`, which Debian Qt does not search; move all to
  `/usr/lib/$(DEB_HOST_MULTIARCH)/qt6/qml` and fix the literal probe in
  `ryoku/shell/ipc/daemon.go:411` (also `ryoku/hyprland/modules/env.lua:66-67`
  and `ryoku/shell/deploy.sh:523` comments/logic, compositor/dev reports).
- **Go toolchain:** `ryoku-shell` needs Go >= 1.26 (`go.mod:3`): trixie must
  pull `golang-1.26-go` from trixie-backports; forky/sid/resolute have it.
  `ryogami` (1.22) and `palette-bridge` (1.24) build with trixie's Go 1.24.
  Builds must run with `GOTOOLCHAIN=local` and `-mod=vendor` (offline).
- **Vendored `ryoku-wm` copies** exist in `ryoku/shell/ipc/vendor/ryoku-wm` and
  `ryoku/shell/ryogami/daemon/vendor/ryoku-wm`; any Debian patch to `ryoku/wm`
  needs `go mod vendor` in both.
- **Unpackaged tools the shell needs** (build-from-source list): `matugen`
  (>= 4.1.0, palette, used by daemon and ryogami), `wl-clip-persist`,
  `waifu2x-ncnn-vulkan` (models at `/usr/share/waifu2x-ncnn-vulkan/models-cunet`),
  `songrec`, `voxtype` (optional), `gpu-screen-recorder` (trixie, resolute),
  `hyprpicker` (resolute ok, trixie via bpo), `uv` (trixie, resolute).
- **gpu-screen-recorder capability:** Debian's gsr has no `cap_sys_admin` on
  `gsr-kms-server`; Arch sets it in its install hook. Affects the shell recorder
  and ryomotion.
- **Admin group:** Debian polkit admin identity is group `sudo`
  (Ubuntu also `admin`); the installer must put the user there for the
  daemon's polkit agent and the scripts' `pkexec` calls to authenticate as the
  user.
- **`awk` is mawk on Debian:** at least `ryoku-cmd-folders:36` needs gawk;
  other subsystems' scripts should be grepped for `strtonum|gensub|asort|systime|strftime|PROCINFO`.
- **Session PATH drops `/usr/games`** (`environment.d/ryoku-session.conf:16`):
  Debian installs `steamcmd` (and other games) there.
- **ImageMagick:** Debian ships IM7 with `/usr/bin/magick` via alternatives on
  every suite; Debian's stricter `/etc/ImageMagick-7/policy.xml` resource
  limits apply to ryogami and stash.
- **`tools/pkgver` caveat (before the coordinator's fix):** madison prints
  non-main components as `stable/non-free`; earlier batches that matched only
  `stable` reported `steamcmd` as absent. Re-run any non-free/contrib lookups
  done before the fix. Every resolute `-` in this file (quickshell,
  gpu-screen-recorder(-cli), uv, python3.13(-venv), matugen, wl-clip-persist,
  songrec, waifu2x-ncnn-vulkan, pnpm) was re-queried in small batches after the
  second pkgver fix and is confirmed absent; `g++` is 4:14.2.0-1 / 4:16.1.0-3 /
  4:15.2.0-5ubuntu1 (trixie / forky+sid / resolute).
- **Doc/code mismatches found:** `docs/development.md:69-73` (Blobs uses only
  public Qt API); `docs/launcher.md:93` (clipboard history is the daemon's, not
  cliphist; `cliphist-thumbs.sh` has no caller); `docs/updates.md:80-82`
  (ryotunes is imported prebuilt, not built from a tarball);
  `system/packages/base.packages:186` (cobalt script path).

## Debian packages needed (this section)

Build: `golang-1.26-go`, `golang-go`, `gcc`, `g++`, `pkgconf`, `cmake`,
`ninja-build`, `qt6-base-dev`, `qt6-declarative-dev`, `qt6-declarative-dev-tools`,
`qt6-shadertools-dev`, `qt6-shader-baker`, `qt6-multimedia-dev`,
`libwayland-dev`, `libwayland-bin`, `wayland-protocols`, `libavformat-dev`,
`libavcodec-dev`, `libavutil-dev`, `libswscale-dev`, `debhelper`, `cargo`,
`rustc` (or `rustc-web`/`cargo-web` on trixie), `libvulkan-dev`, `glslang-dev`,
`glslang-tools`, `libwebp-dev`, `libgtk-4-dev`, `libadwaita-1-dev`,
`libasound2-dev`, `libpulse-dev`, `libssl-dev`, `libdbus-1-dev`, `meson`,
`libx11-dev`, `libxcomposite-dev`, `libxrandr-dev`, `libxfixes-dev`,
`libswresample-dev`, `libavfilter-dev`, `libva-dev`, `libdrm-dev`, `libcap-dev`,
`libpipewire-0.3-dev`, `libspa-0.2-dev`, `libxdamage-dev`,
`libwebkit2gtk-4.1-dev`, `libmpv-dev`, `libayatana-appindicator3-dev`,
`librsvg2-dev`, `libxdo-dev`, `nodejs`.

Runtime: `quickshell`, `libjemalloc2`, `libqt6core6t64`, `libqt6gui6`,
`libqt6qml6`, `libqt6quick6`, `libqt6multimedia6`, `wl-clipboard`,
`wireplumber`, `pipewire`, `pipewire-bin`, `pulseaudio-utils`,
`libglib2.0-bin`, `gsettings-desktop-schemas`, `procps`, `util-linux`,
`coreutils`, `findutils`, `file`, `ffmpeg`, `imagemagick`, `jq`, `curl`,
`ca-certificates`, `inotify-tools`, `network-manager`, `power-profiles-daemon`,
`polkitd`, `pkexec`, `gnome-keyring`, `gcr`, `kitty`, `systemd`,
`dbus-user-session`, `xdg-user-dirs`, `libnotify-bin`, `xdg-utils`, `grim`,
`slurp`, `wf-recorder`, `gpu-screen-recorder-cli`, `libcap2-bin`, `zbar-tools`,
`tesseract-ocr`, `tesseract-ocr-eng`, `hyprpicker`, `brightnessctl`, `ddcutil`,
`papirus-icon-theme`, `gtk-update-icon-cache`, `gawk`, `mpv`, `mpv-mpris`,
`yt-dlp`, `qalc`, `python3`, `python3.13-venv`, `python3-venv`, `uv`,
`cliphist`, `docker.io`, `libarchive-tools`, `flatpak`, `openssl`, `pciutils`,
`hostname`, `steamcmd` (non-free, i386), `libgtk-3-0t64`, `libnss3`,
`libasound2t64`, `libnotify4`, `xdg-desktop-portal`, `libxss1`, `libxtst6`,
`libatspi2.0-0t64`, `libuuid1`, `libsecret-1-0`, `libwebkit2gtk-4.1-0`,
`libmpv2`, `libayatana-appindicator3-1`, `desktop-file-utils`.

Build-from-source .debs (not in any suite): `matugen`, `wl-clip-persist`,
`waifu2x-ncnn-vulkan`, `songrec`, `voxtype`, `ryotunes`; plus
`gpu-screen-recorder` for trixie/resolute and `uv` for trixie/resolute.

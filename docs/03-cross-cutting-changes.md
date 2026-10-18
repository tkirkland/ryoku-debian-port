# 03 — Cross-cutting changes to the Ryoku tree

These changes repeat across several sections. Each one is listed once here with every
known site, so the port can make it in one pass. Cites are to the Ryoku tree at
`98a0368`; the cited section holds the per-file detail.

## C-01 Qt QML install path
Arch: `/usr/lib/qt6/qml`. Debian/Ubuntu: `/usr/lib/x86_64-linux-gnu/qt6/qml`. Packages
should read it from `qtpaths6 --query QT_INSTALL_QML` (package `qt6-base-dev-tools`).
Unchanged, the shell, Hub and lock screen do not load at all.
- Installers: `release/packages/ryoku-desktop/PKGBUILD:324-349` (Ryoku.Ui, FrameBars,
  PluginKit), `ryoku-desktop-hyprland/PKGBUILD:87-88` (Ryoku.Wm.Hyprland),
  `ryoku-blobs/PKGBUILD:33-37`.
- Readers: `ryoku/shell/ipc/daemon.go:411`,
  `installation/tests/container-install.sh:184-185`, `bin/ryoku-dev-lint-qml:28`.
  Comments or logic in `ryoku/shell/environment.d/ryoku-session.conf:11`,
  `ryoku/hyprland/modules/env.lua:66-79` and `ryoku/shell/deploy.sh:523`.
- 18 committed symlinks in
  `ryoku/lockscreen/qylock/quickshell-lockscreen/imports/QtGraphicalEffects/` point at
  `/usr/lib/qt6/qml/Qt5Compat/GraphicalEffects/` and dangle.
- Qt tools (`qsb`, `qmllint`) are in `/usr/lib/qt6/bin` and not on PATH;
  `qt6-shader-baker` provides `qsb`. The 42 committed `.qsb` files load on Qt 6.8,
  6.10 and 6.11 unchanged.
- Arch's `qt6-declarative` is one package; Debian splits it into per-module
  `qml6-module-*` packages (list in [09a](09a-shell-qml.md), [10](10-hub-ui-lockscreen.md)).
- `ryoku/cli/internal/doctor/reconcile_quickshell.go:20,27,75` hardcodes
  `/usr/lib/libQt6Core.so.6`.
[04, 09a, 09b, 10, 11]

## C-02 Admin group `wheel`
Debian/Ubuntu have no `wheel` group; polkit's admin identity is `unix-group:sudo`
(Ubuntu also adds `admin`).
- 11 polkit rules test `isInGroup("wheel")`:
  - `system/policy/52-ryoku-timedate.rules:8`
  - `system/hardware/network/{48-ryoku-wifi-regdom,49-ryoku-wifi-powersave,50-ryoku-dns,51-ryoku-wifi-backend,55-ryoku-network-kill}.rules`
  - `system/hardware/power/{47-ryoku-power,53-ryoku-game-tune}.rules`
  - `system/hardware/gpu/45-ryoku-gpu-mux.rules:13`
  - `system/hardware/bluetooth/54-ryoku-bluetooth-a2dp.rules:11`
  - `system/containers/46-ryoku-docker.rules:22`
- Installer: `useradd -m -G wheel,video,input` (`installation/backend/lib/chroot.sh:117`)
  aborts on Debian; it also writes `%wheel ALL=(ALL:ALL) ALL` (`chroot.sh:131-134`).
- The Connections page runs `pkexec … ryoku-network-kill status` on load
  (`ConnectionsPage.qml:66-69`), so every visit prompts if the rule misses.
- `pkexec` is its own package on Debian/Ubuntu and must be a `Depends:` of every package
  whose helpers re-exec through it.
Decision D-23. [04, 07, 08, 10]

## C-03 The package-manager seam
Every pacman, yay, makepkg, checkupdates and AUR call has to target apt/dpkg. The
largest clusters:
- **CLI:** `ryoku/cli/internal/sys/sys.go` (`PkgInstalled` is `pacman -Q`, so about 47
  of 118 doctor reconcilers no-op or report false faults), `internal/updater/update.go`
  (`checkupdates` :1698-1724, `yay -Qua` :1726-1744, `pacman -Sl ryoku` :1675-1688),
  `doctor/doctor.go:1091` (`pacman -Sy`), `reconcile_multilib.go`,
  `reconcile_shipped_apps.go:72-93`, `reconcile_qmk.go:18`,
  `reconcile_limine.go:694-696`. The channel is read from `/etc/pacman.conf`
  (`internal/sys/release.go:35-37,53-120`) and becomes `ryoku.sources` `URIs:`/`Suites:`
  plus a pin. Version comparison moves from vercmp to `dpkg --compare-versions`. The
  release manifest (`ryokumanifest/generate.go:117-120`, `manifest.go:28-34,117-133`)
  carries package names.
- **ryoku-wm:** `ryoku/wm/reclaim.go:204-292`,
  `ryoku/wm/hyprland/config_plugins_tier.go:691`, and the package lists in
  `ryoku/wm/hyprland/caps.go:66-81` / `ryoku/wm/niri/caps.go:64-81`. `ryoku-wm` is
  vendored into **five** modules (cli, hub/backend, rashin/backend, shell/ipc,
  shell/ryogami/daemon), so every edit needs `go mod vendor` in each.
- **Hub backend:** `ryoku/hub/backend/wm.go:171-174` (`pacman -Si`),
  `gpuapply.go:40-42,68-97,203-226,303-310`, `hwcaps.go:280`.
- **Rashin:** `quicktools.go:106-112`, `index.go:438-455`.
- **Scripts:** `ryoku/shell/scripts/ryoku-sysinfo:71`, `ryoku-profile-stats:51-52`,
  `stash-install.sh:40-58,158-159`, `system/extras/ryostore-install`, the
  `ryoku-pkg-*` wrappers, and `ryoku/apps/ryovm/bin/ryovm:145-147`.
- **QML:** the launcher's `gpk --manager pacman,aur` (`Packages.qml:217`); the bar
  watches `/var/log/pacman.log`, which becomes `/var/log/apt/history.log`;
  `ProfilePage.qml:47` reads the install date from `pacman.log`; and
  `UpdatesPage.qml:595` shows "sudo pacman -Syu".
- **Distro detection:** Debian has a `pacman` game in `/usr/games` and a
  `pacman-package-manager` package, so "is pacman on PATH" is not a distro test. Gate on
  `/etc/os-release`.
- **Behaviour differences:**
  - `apt-get remove` removes dependents, where `pacman -R` refuses.
  - apt installs Recommends (D-25).
  - dpkg locks are fcntl locks on files that always exist, so an existence check like
    `ryoku-power-cutover:960`'s `/var/lib/pacman/db.lck` has no equivalent.
Decision D-03. [05, 07, 09a, 09b, 10, 11]

## C-04 libalpm hooks, mkinitcpio and kernel identity
- **alpm hooks:** `94/95-ryoku-power-cutover*.hook`, `ryoku-nvidia.hook`, the Limine
  hooks and limine-snapper-sync's lock hook. They become preinst/postinst scripts,
  dpkg file triggers, `/etc/kernel/postinst.d`/`postrm.d`, or apt
  `DPkg::Pre-Install-Pkgs`/`Post-Invoke`. Nothing may install to
  `/usr/share/libalpm/hooks/`. The `RYOKU_MANAGED_UPDATE` deferral in
  `ryoku-desktop.install:118-140` exists only because libalpm can't run a newly
  extracted hook; dpkg runs the new maintainer scripts, so the postinst can act
  synchronously.
- **mkinitcpio becomes initramfs-tools or dracut (D-41):**
  - Config and module files: `/etc/mkinitcpio.conf.d/{ryoku,nvidia}.conf` and
    `/usr/lib/initcpio/install/ryoku-gpu-trim`, which becomes
    `/usr/share/initramfs-tools/hooks/ryoku-gpu-trim`.
  - `mkinitcpio -P` calls in `ryoku/cli/internal/keyboard/keyboard.go:195,268-272`,
    `cmd.go:184-250` and `reconcile_hardware.go:363-368`.
  - Files that write these paths: `chroot.sh:137-239`, `deploy.sh:254-265`,
    `nvidia.sh:223-225,251-276`, `bootloader.sh:301-312,729-743`,
    `ryoku/shell/deploy.sh:436-437` and `ryoku-boot-apply`.
- **Kernel identity:** Arch pkgbase (`linux`, `linux-cachyos`) is read from
  `/usr/lib/modules/*/pkgbase` by the installer, `nvidia.sh`, limine-entry-tool and
  the doctor (`reconcile_limine.go:970-978`, `reconcile_limine_images.go:46,172-184`).
  Debian kernels are versioned and have no pkgbase file. Image names change too:
  `vmlinuz-linux` / `initramfs-linux.img` become `vmlinuz-<ver>` / `initrd.img-<ver>`.
  Decision D-39.
- `cryptdevice=` on the cmdline (`bootloader.sh:258-259`) is mkinitcpio-only. Debian
  uses `/etc/crypttab`, or `rd.luks.*` with dracut.
[04, 05, 06, 07, 08]

## C-05 Arch-only `/etc` and system paths
| Arch | Debian/Ubuntu | Sites |
|---|---|---|
| `/etc/locale.conf` | `/etc/default/locale` | installer, doctor, Hub |
| `/etc/vconsole.conf` | `/etc/default/keyboard` (vconsole.conf is a symlink to it when present; localed's setters are denied by policy) | `ryoku-greeter:97-118`, `ryoku/cli/internal/keyboard/keyboard.go`, Hub Input page |
| `/etc/conf.d/snapper` | `/etc/default/snapper` | `snapshots.sh:67`, doctor |
| `/etc/conf.d/wireless-regdom` | cfg80211 `ieee80211_regdom=` modprobe option | `system/hardware/network/ryoku-wifi-regdom:10,32` |
| `/usr/lib/security/*.so` | `/usr/lib/x86_64-linux-gnu/security/` | `LockscreenPage.qml:933`, `reconcile_fingerprint.go:37` |
| PAM `include system-login` | `@include common-auth` / `common-session` | `ryoku/lockscreen/sddm/setup:109,112`, `ryoku/cli/internal/keyring/pam.go:51-99`, `ryoku-shell-installer/engine.go:1096-1104` |
| `/etc/pam.d/polkit-1` | `/usr/lib/pam.d/polkit-1` (on Arch too, so the toggle fails on both) | `LockscreenPage.qml:133-160` |
| `/run/archiso/bootmnt` | `/run/live/medium` (live-boot), `/cdrom` (casper) | `installation/tui/system.go:256-260` |
| `/etc/pacman.d/hooks`, `/usr/share/libalpm/hooks` | dpkg triggers, `/etc/kernel/*.d`, apt.conf.d | C-04 |
| `/usr/bin/agetty` (live autologin) | `/usr/sbin/agetty` | ISO airootfs ([06](06-iso-boot.md)) |
| `hwclock` in util-linux | `util-linux-extra` | installer |
| no `127.0.1.1` line in `/etc/hosts` | Debian expects `127.0.1.1 <hostname>` | installer |
| OVMF `OVMF_CODE.fd` | `OVMF_CODE_4M.fd` | `ryoku/hub/backend/hwcaps.go:574-585` |
| `/etc/chromium-flags.conf` | `/etc/chromium.d/` | `ryoku/apps/chromium-flags.conf` |

`/etc/pam.d/{sddm,sudo}` and `/etc/bluetooth/main.conf` are dpkg conffiles on Debian.
Ryoku's in-place edits (fingerprint, keyring, u2f, `ryoku-bluetooth-tune`) cause
conffile prompts on upgrade unless they move to drop-ins or `pam-auth-update` profiles.

## C-06 Session PATH and binary names
- `ryoku/shell/environment.d/ryoku-session.conf:16` sets
  `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin`. Arch merges sbin into bin;
  Debian doesn't, so `rfkill`, `iw`, `nft`, `modinfo`, `modprobe` and `usermod` break
  by bare name. `/usr/games` (where `steamcmd` lives) is dropped too. Debian's sddm
  compiles `DefaultPath=/bin:/usr/bin`.
- Renamed binaries and moved packages:
  - `fd` is `fdfind`. Callers: `ryoku/apps/fish/config.fish:58`,
    `ryoku/apps/terminal-shell/env.sh:12`, yazi and the launcher. No Debian package
    owns `/usr/bin/fd`, so a Ryoku-shipped symlink fixes every caller.
  - `bat` is `batcat`; `magick` comes through alternatives.
  - `pactl` is in `pulseaudio-utils`; `modetest` in `libdrm-tests`; `dbus-monitor` in
    `dbus-bin`; `swtpm_setup` in `swtpm-tools`.
  - `luac` comes through alternatives.
- `/bin/sh` is dash and the default awk is mawk. `ryoku/shell/scripts/ryoku-cmd-folders:36`
  uses a gawk-only function; add `Depends: gawk`, and grep every script for
  `strtonum|gensub|asort|systime|strftime|PROCINFO`.
- The zsh plugin paths in `ryoku/apps/zsh/ryoku.zsh:45-50` differ on Debian.

## C-07 Packaging behaviour Debian adds
- Packages auto-enable their units: `docker.io` (docker.service/socket), the snapper
  timers, `wpa_supplicant.service`, Debian's `openrgb.service` (globally enabled user
  unit). Ryoku's "deliberately not enabled" units (`base.packages:180-186`) need
  explicit disables in the installer and doctor. `ryoku-rashin.service` must be
  installed with `dh_installsystemduser --no-enable`.
- Recommends are installed by default (D-25). `xdg-desktop-portal-gnome` Recommends
  gnome-shell and gnome-settings-daemon and Depends on nautilus.
- Packages that link Qt private API get `qt6-*-private-abi (= X)` automatically from
  `dpkg-shlibdeps`. Debian's Hyprland Provides `hyprland-abi-<sha7>`; plugins built
  with `${hyprland:ABI}` pin to it (D-13).
- Debian's `go.env` defaults to `GOTOOLCHAIN=auto` and silently downloads a newer Go.
  Build with `GOTOOLCHAIN=local -mod=vendor`.
- AppArmor is on by default. libvirt's QEMU profile blocks `/dev/kvmfr0` (the Hub's
  passthrough lane); nothing in Ryoku handles AppArmor.
- Hyprland's `version.h` must carry the upstream commit. A tarball self-build without
  `GIT_COMMIT_HASH` writes `unknown`, which disables the plugin ABI receipt, staleness
  check and rebuild (`ryoku/wm/hyprland/config_plugins_tier.go:179`).

## C-08 Creator infrastructure to re-point
The full table is in [04 §6](04-packaging-repo-ci.md). In summary:
- `repo.ryoku.dev`, `iso.ryoku.dev`, `docs.ryoku.dev`, `ryoku.dev`.
- The release key fingerprint, `keys/ryoku-release-key.pub.asc` and `ryoku-keyring`.
- GitHub slugs `ryoku-dev/ryoku-arch`, `ryoku-dev/ryoku`, `ryoku-dev/ryostore` and
  `ryoku-dev/ryotunes`.
- R2 bucket secrets, Discord webhooks, GitHub Projects, OpenRouter i18n.
- CI images `archlinux:latest` and `cachyos/cachyos:latest`.
- The ryostore catalogue URL (`ryoku/apps/ryostore/backend/paths.go:12,16`).

The repo URL also changes shape (apt layout), so these are rewrites, not string swaps.

## C-09 i18n
Every reworded Arch string ("sudo pacman -Syu", AUR, GlazePKG, base-devel,
"performance Arch", SDDM fingerprint text…) is a catalog key present in 35 languages.
After rewording: `ryoku/i18n/tools/sync.py extract` then `sync` (the Google engine
needs no key; the LLM engine needs `RYOKU_I18N_KEY`). `/usr/bin/ryoku-i18n` itself
crashes on every packaged system today (`sync.py:64-77`).

## C-10 Fonts, themes and cursors the port must ship
None of these are in any Debian/Ubuntu suite unless noted:
- **Fonts:** Material Symbols (variable), JetBrainsMono/FiraCode/Hack Nerd Fonts,
  Fraunces, Maple Mono NF, Space Grotesk (only resolute has it), `fonts-adwaita` (absent
  on trixie). SpaceMono Nerd Font is referenced but unshipped even on Arch (D-32).
- **Themes:** `adw-gtk3` (hardcoded `adw-gtk3-dark` in `ryoku/hyprland/modules/autostart.lua:13`
  and `ryoku/niri/autostart.kdl:19`).
- **Cursors:** `Bibata-Modern-Ice` with hyprcursor data. Debian's `bibata-cursor-theme`
  2.0.6 has none, so `ryoku-cursors` is built with `hyprcursor-util`.

## C-11 Release mechanics that change shape on apt
- apt rejects a Release file whose Codename changes, so "stable" can't be a byte copy of
  a tagged release.
- Debian debs are per base suite: the repo gains a trixie/forky/resolute dimension.
- Ryotunes' in-client updater uses `pacman -U` on a `.pkg.tar.zst`.
- Three sources disagree on when work reaches users: `publish-repo.yml` publishes on
  `unstable-dev` pushes and `v*` tags, while `AGENTS.md` and `ryoku-dev-verify-delivery`
  say a `main` fast-forward.
- `aur.packages` says `ryoku update` never revisits that set, yet `reconcileManifest`
  installs it via yay.
[05]

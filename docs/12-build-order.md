# 12 — Build order: Ryoku on Debian, end to end

This is the implementation sequence. Each phase only needs the earlier ones, and
each step points at the section that holds its exact commands, file edits and
recipes. Steps that depend on a decision name it (`D-xx`, see
[00-decisions.md](00-decisions.md)). Where a step differs by base, the variants
are labelled **[T]** trixie(+bpo), **[F]** forky/sid and **[R]** Ubuntu 26.04.

## Phase 0 — Decisions that gate the plan

D-01 (base), D-02 (bootloader), D-03 (fork vs dual), D-04 (Secure Boot), D-05
(NVIDIA), D-06 (kernel/CachyOS). Everything below assumes they are set.

## Phase 1 — Your infrastructure

1. **Signing key** (D-11). Generate it and keep the private half as a CI secret.
   The public half becomes the `ryoku-archive-keyring` deb, installed at
   `/usr/share/keyrings/ryoku-archive-keyring.gpg` and referenced by
   `Signed-By:` ([04 §2](04-packaging-repo-ci.md)).
2. **Repo tool and hosting** (D-08, D-09). Lay out suites for the base dimension
   × channel (D-10). Publish an empty signed repo and verify that
   `apt-get update` accepts it from a clean `debian:<suite>` / `ubuntu:26.04`
   container.
3. **Build workers.** Use an sbuild/pbuilder chroot or container per target
   suite (`debian:trixie` + `trixie-backports`, `debian:forky`, `ubuntu:26.04`).
   Enable `contrib non-free non-free-firmware` (Debian) or
   `universe multiverse restricted` (Ubuntu) and `dpkg --add-architecture i386`
   for the lib32 set ([02 cross-cutting]). Set `GOTOOLCHAIN=local` globally.
4. **Fork and re-point the creator's infrastructure** (C-08): the repo/ISO/docs
   hosts, GitHub slugs, the ryostore catalogue fork, the ryotunes source (D-17),
   secrets, and removing the Discord and Projects hooks.

## Phase 2 — Toolchain and base-level rebuild stacks (base-dependent)

- **[T]:**
  - From trixie-backports: `golang-1.26-go`, `rustc`/`cargo` 1.96, `mesa` 26.1,
    `pipewire` 1.6, the `linux` 7.2 kernel (if D-06 picks it), `quickshell` (not
    usable as shipped; it is rebuilt below), `hyprland-dev` 0.55 (not
    sufficient).
  - Qt 6.11 stack (D-01b): rebuild forky's `qt6-base`, `qt6-declarative`,
    `qt6-wayland`, `qt6-svg`, `qt6-multimedia`, `qt6-5compat`,
    `qt6-imageformats`, `qt6-shadertools` and the KF6 syntax-highlighting source
    on trixie ([02 MISSING-BUILD], [09a]).
  - GCC 16 route (D-01a), then the Hyprland 0.56 stack (D-01c). Order:
    `wayland wayland-protocols xkbcommon libinput lua hyprwayland-scanner hyprutils hyprlang hyprcursor hyprgraphics hyprland-protocols hyprwire aquamarine hyprland`,
    then hypridle, hyprpicker, hyprpolkitagent, xdg-desktop-portal-hyprland and
    hyprsunset ([11 §Hyprland]). Keep `GIT_COMMIT_HASH` in `version.h` (C-07).
  - Rebuild `quickshell` 0.3.2 against the new Qt.
- **[F]:** nothing. Qt 6.11.2, quickshell 0.3.2, Hyprland 0.56.2 +
  `hyprland-dev`, Go 1.26 and rustc 1.96 all come from the archive.
- **[R]:** the Qt 6.11 backport or the patched launcher (D-01b), the Hyprland
  0.56 stack (D-01c), quickshell 0.3.2, and python3.13 for ryostage ([09b]).

## Phase 3 — Third-party packages Debian lacks

These have no edges among themselves and can build in parallel. Each recipe is
in [02 §MISSING-BUILD](02-package-map.md); the section noted carries the detail.

- **Desktop runtime:** `matugen` 4.2.0 (cargo, rustc ≥ 1.88; [09a]),
  `wl-clip-persist`, `gpu-screen-recorder` [T] [R] (with the D-27 capability),
  `waifu2x-ncnn-vulkan` (models at
  `/usr/share/waifu2x-ncnn-vulkan/models-cunet`), `songrec`, `voxtype` (upstream
  ships a deb), `nvibrant`, `yazi` (MSRV 1.99, built with rustup), `uv` [T] [R].
- **Compositors:** `niri` ≥ 26.04 and `xwayland-satellite` (cargo; D-35 on [T]),
  `hyprland-preview-share-picker`.
- **Look and feel** (C-10): `adw-gtk3`, `ryoku-cursors` (Bibata + hyprcursor
  data via `hyprcursor-util`), `ryoku-cursor-material`, the
  vimix/phinger/catppuccin/apple cursor sets, Material Symbols, the
  JetBrainsMono/FiraCode/Hack Nerd Fonts, Maple Mono NF, Fraunces (D-32), Space
  Grotesk [T] [F], SpaceMono Nerd (D-32), `fonts-adwaita` [T].
- **Shell helpers:** `blesh`, `zsh-history-substring-search`, `ryoku-oh-my-zsh`,
  `gpk` (Depends `apt` instead of `pacman`), `prowl-agent` (Go 1.26.4), `mise`.
- **Hardware:** `asusctl` (cargo, MSRV 1.93), `qmk_hid`, `game-devices-udev`,
  `broadcom-bt-firmware`, `xpadneo-dkms` [T] [R], `dualsensectl`, `openrgb` [T]
  (with udev rules; Debian's ships none), `pam-fprint-grosshack` (D-31),
  `looking-glass` + `kvmfr` DKMS (Hub passthrough), `sddm` without Xorg (D-30
  c).
- **Boot chain** (D-02): either `limine` 12.9.3 plus `limine-entry-tool` and
  `limine-snapper-sync` (GraalVM 25 + Gradle 9.6.1, vendored offline; [06
  §Limine]), or `grub-btrfs`.
- **Kernel** (D-06): the CachyOS kernel deb (`make bindeb-pkg`) and, for the
  full variant, `cachyos-settings`, `ananicy-cpp` + rules, `scx-scheds`, and the
  `proton-cachyos-slr` tarball ([06 §Kernels]).
- **NVIDIA** (D-05): nothing to build for (a)/(b)/(c); for (d), driver debs from
  the `.run`.
- **Browsers** (D-36): wire Mozilla's APT repo or a chromium source if chosen;
  ship `zen-browser` as a deb if D-28 picks that route.

## Phase 4 — Port changes to the Ryoku tree

Apply in the fork or behind the `debian` build tag (D-03). The global edits are
listed once in [03-cross-cutting-changes.md](03-cross-cutting-changes.md):

1. C-01 QML path, C-02 admin group, C-05 paths, C-06 PATH and binary names, C-07
   unit enables, C-10 theme/cursor names.
2. C-03 package-manager seam: the apt/dpkg backend in `ryoku/cli/internal/sys`,
   the `ryoku/wm` reclaim/caps package lists, the hub backend, Rashin and
   scripts; then re-vendor `ryoku-wm` into all five modules.
3. C-04 hooks: replace alpm hooks with dpkg triggers, `/etc/kernel/postinst.d`,
   the initramfs hook (`ryoku-gpu-trim`) and apt hooks; mkinitcpio becomes
   initramfs-tools or dracut (D-41).
4. The update lane, doctor and rollback ([05](05-update-delivery.md)):
   `ryoku update` on apt with a snapper pair (D-18, D-19), `ryoku status --json`
   from apt (D-22, schema unchanged), rollback on the chosen boot chain (D-02),
   channel state in `ryoku.sources`, all 118 reconcilers triaged per [05 §3] (28
   Arch-only, 19 partly), and updated Go tests.
5. Hardware helpers ([07](07-hardware-system.md)): `nvidia.sh` and the guard for
   the D-05 source (module names, `/etc/initramfs-tools/modules`),
   `ryoku-power-cutover` lock detection, `ryoku-wifi-regdom`,
   `ryostore-install` + `ryoku-pkg-*` on apt with the D-28/D-29 route table,
   `ryoku-docker` for D-24, and D-44 fixes if chosen.
6. Hub and lock ([10](10-hub-ui-lockscreen.md)): the Updates, Profile,
   Dictation, Plugins, Add-ons, compositor switch, GPU passthrough (OVMF `_4M`,
   AppArmor), Input (`update-initramfs`, `/etc/default/keyboard`) and Lockscreen
   (PAM paths, `pam-auth-update` or grosshack, D-31) pages; the greeter keyboard
   from `/etc/default/keyboard`; and `/var/lib/ryoku/greeter-primary` via
   tmpfiles.
7. Shell ([09a](09a-shell-qml.md), [09b](09b-shell-native.md)): `fdfind`, the
   `apt/history.log` feed, `gpk --manager apt`, gawk, the `/usr/games` PATH, and
   `ryoku-sysinfo`/`ryoku-profile-stats` on dpkg.
8. C-09 i18n: reword the strings, run `sync.py extract && sync`, and fix the
   `ryoku-i18n` crash.

## Phase 5 — Debian packaging of Ryoku's own packages

Write a `debian/` tree per D-07 for all 34 recipes
([04 §1, §4](04-packaging-repo-ci.md); the per-recipe control fields, rules,
maintainer scripts and triggers are there). Stage order, from [04 §5]:

1. Leaves: `ryoku-archive-keyring`, `gpk`, `prowl-agent`, `ryoku-oh-my-zsh`,
   fonts, cursors, `broadcom-bt-firmware`, `game-devices-udev`, `asusctl`,
   `xwayland-satellite`, `ryoku-palette-bridge`, `ryomotion`, and the Limine
   stack if kept.
2. Hyprland-ABI packages, rebuilt on every Hyprland upload (D-12, D-13):
   `hypr-dynamic-cursors`, `ryoku-hypr-plugins`, `hyprglass`, `imgborders`,
   `ryoku-keysounds`, `hyprland-preview-share-picker`.
3. The monorepo set: `ryoku-shell`, `ryoku-hub`, `ryoku`, `ryoku-blobs` (D-34),
   `ryoku-rashin` (prowl-agent hard dep; user unit `--no-enable`), `ryogami`,
   `ryoku-desktop` (QML modules to the multiarch dir, polkit rules per D-23,
   `/etc` files per D-16, the alpm hooks rewritten as triggers),
   `ryoku-desktop-hyprland`, and `ryoku-desktop-niri`.
4. Imported: `ryotunes` (D-17).
5. **Publish gate:** in a clean container per suite,
   `apt-get install ryoku-desktop` (plus `ryoku-desktop-niri` beside it) from
   the freshly indexed repo. This is the Debian form of
   `installation/tests/container-install.sh`.

## Phase 6 — Boot chain

Per D-02/D-04/D-38/D-39/D-41 ([06](06-iso-boot.md)):

- the bootloader install (BIOS + UEFI);
- the entry-generation hooks on kernel install and remove;
- snapshot entries (limine-snapper-sync or grub-btrfs);
- the initramfs config, mapped line by line from mkinitcpio HOOKS/MODULES/FILES
  (initramfs-tools `conf.d`/`modules`/`hooks`, or `dracut.conf.d`);
- the Plymouth theme (`/usr/share/plymouth/themes`,
  `plymouth-set-default-theme`, initramfs inclusion);
- the kernel cmdline (drop `cryptdevice=`, use crypttab or `rd.luks.*`);
- Secure Boot signing if D-04 picks (b)–(d).

## Phase 7 — Installer

Per [08](08-installer.md):

- **Backend:**
  - `pacstrap` becomes `mmdebstrap` (with an include list and the right
    components).
  - `arch-chroot` becomes a chroot with `--make-rslave` binds, efivars and a
    private `/run`. `policy-rc.d` blocks service starts during install.
  - `genfstab` becomes a generated fstab; the ESP layout follows D-38.
  - reflector/mirrors become a Debian mirror probe.
  - Locale goes through `locales` + debconf, and keyboard through
    `/etc/default/keyboard` + `dpkg-reconfigure`.
  - LUKS uses crypttab plus `cryptsetup-initramfs` or dracut.
  - btrfs subvolumes: `@pkg` becomes `/var/cache/apt/archives`.
  - Snapper config goes in `/etc/default/snapper`.
  - The user is created per D-23, with `127.0.1.1` in `/etc/hosts`.
  - The deploy step adds `ryoku.sources` + the keyring, then
    `apt-get install ryoku-desktop`.
  - The drivers step follows D-05; the AUR step follows D-28.
  - Unwanted units are disabled explicitly (C-07).
- **TUI:** detect the live medium at `/run/live/medium` (and `/cdrom` on
  Ubuntu), apply the base-specific gates, and change the Arch strings.
- **No-ISO shell installer:** D-43.
- **Tests:** rewrite the mocked fixtures and `container-install.sh`, and drive
  `install-vm.py` against the Debian live prompt.

## Phase 8 — ISO

Per D-40 ([06 §ISO](06-iso-boot.md)):

- Map the archiso profile file by file: `airootfs/` becomes `includes.chroot`,
  `packages.x86_64` becomes package lists, and customize hooks become live
  hooks.
- live-boot/live-config replace the archiso hooks (`copytoram`/cow,
  `/run/live/medium`).
- The installer autostart uses `/usr/sbin/agetty`; console fonts come from
  Debian's set.
- The offline package closure (D-42) is rewritten on apt (`offline-repo.sh`).
- Reproducibility: `SOURCE_DATE_EPOCH` is honoured by mmdebstrap, mksquashfs,
  mkinitramfs, mkfs.fat and xorriso, and `snapshot.debian.org` /
  `snapshot.ubuntu.com` replaces the Arch Linux Archive.
- UEFI with Debian's signed GRUB needs `/.disk/info` and `mmx64.efi` in the EFI
  image.

## Phase 9 — CI

Port the 47 workflows ([04 §3](04-packaging-repo-ci.md)):

- Container images: `archlinux:latest` becomes `debian:<suite>` /
  `ubuntu:26.04`.
- `makepkg` becomes `dpkg-buildpackage`/sbuild, and the repo publish uses the
  D-08 tool.
- ISO builds run in a Debian container.
- Delete the Arch-only jobs (keyring recovery, the CachyOS ISO unless D-06 keeps
  it).
- Reconcile the "when does work reach users" contract (C-11).

## Phase 10 — Validation

1. Container install per suite (the Phase 5 gate).
2. VM unattended install per strategy (whole disk, alongside) and per profile
   (vm, amd, intel, amd-nvidia), mirroring the dry-run matrix in
   `docs/development.md`.
3. First login: the shell, Hub and lock screen load (catches C-01 regressions);
   matugen theming follows the wallpaper; the Hyprland plugins load; the niri
   session starts.
4. `ryoku update` → `ryoku rollback` → `ryoku doctor` round trip on the chosen
   boot chain.
5. The real-hardware classes from `docs/installation-hardware.md`: Intel VMD,
   Secure Boot, NVIDIA modeset (per D-05 branch), Windows dual-boot, Broadcom,
   clock skew, NVRAM, USB media. Also re-test the greeter workarounds tuned on
   Arch (NVIDIA pixman, numlock, settle loop) against Debian's weston/sddm
   versions ([10 cross-cutting]).

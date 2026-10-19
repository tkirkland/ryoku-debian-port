# 01 — Base comparison

Each row is a hard requirement taken from Ryoku's code, with the version each
candidate base ships. Versions were queried on 2026-10-17 with `tools/pkgver`. The
cites point at the section that established the requirement.

Legend: **OK** means the archive meets the floor. **BUILD** means the archive
misses it and the port has to build the package (a build recipe exists in the cited
section). **GAP** means the base can't meet the floor without a larger rebuild.

## Hard floors

| Requirement | Why Ryoku needs it | trixie (13) | trixie + backports | forky (testing) | sid (unstable) | Ubuntu 26.04 (resolute) |
|---|---|---|---|---|---|---|
| **Qt ≥ 6.11** for an identical shell (6.9 is the floor for the default bar to load at all) | `RectangularShadow` (Qt 6.9) at 17 sites incl. the default bar `qsbar/BarSlot.qml:179`; `PillShadow.qml` used by 21 files. Its per-corner radii (Qt 6.11) are used in the default hero launcher `hero/LauncherSurface.qml:466-469` ([09a](09a-shell-qml.md)) | 6.8.2 **GAP** (default bar fails) | 6.8.2 **GAP** (no Qt backport) | 6.11.2 **OK** | 6.11.2 **OK** | 6.10.2 **GAP** (bar loads, hero launcher falls back to okshell) |
| **Quickshell ≥ 0.3.0**, built against the same Qt | `//@ pragma DefaultEnv`, `IdleInhibitor`, `PwNodePeakMonitor`, `Quickshell.Networking`, `Quickshell.WindowManager` ([09a](09a-shell-qml.md), [10](10-hub-ui-lockscreen.md)) | absent **BUILD** | 0.3.0, but built against Qt 6.8 **BUILD** | 0.3.2 **OK** | 0.3.2 **OK** | absent **BUILD** |
| **Hyprland ≥ 0.56.0** | Lua config needs ≥ 0.55; `hl.get_loaded_plugins` at `ryoku/wm/hyprland/config_plugins.go:114` needs 0.56 ([11](11-compositors-apps-theming.md)) | absent **BUILD** | 0.55.2 **BUILD** | 0.56.2 **OK** | 0.56.2 **OK** | 0.53.3 **BUILD** (no Lua config) |
| **GCC 16** (Debian has only built Hyprland 0.56 with it) | C++26 ([11](11-compositors-apps-theming.md)) | g++ 14 **GAP** | g++ 14 **GAP** | 16.2.0 **OK** | 16.2.0 **OK** | 16 snapshot `16-20260322` |
| **Go ≥ 1.26.4** | `installation/tui/go.mod:3-5`, `ryoku/hub/backend/go.mod:3`, shell ipc, ryostore, ryovm ([04](04-packaging-repo-ci.md)) | 1.24 **GAP** | golang-1.26 1.26.9 **OK** | 1.26.9 **OK** | 1.26.9 **OK** | 1.26.8 **OK** |
| **rustc ≥ 1.88** (matugen 4.2.0); yazi 26.9.1 needs 1.99 everywhere | ([09a](09a-shell-qml.md), [02](02-package-map.md)) | 1.85.1 **GAP** | 1.96.1 **OK** | 1.96.1 **OK** | 1.97.1 **OK** | 1.93.1 **OK** |
| **Kernel with sched_ext, ntsync, asus-armoury** | scx schedulers, Proton, ASUS mux ([06](06-iso-boot.md), [07](07-hardware-system.md)) | 6.12.107 missing | 7.2.9 **OK** | 7.2.11 **OK** | 7.2.11 **OK** | 7.0.0 (config not checked) |
| **NVIDIA ≥ 570** (RTX 50) and **≥ 555** (Wayland explicit sync), from the archive | ([07](07-hardware-system.md)) | 550.163 **GAP** | 550.163 **GAP** | 550.163 **GAP** (open module missing) | 550.163 **GAP** | 580 / 595 / 615 **OK** |
| **NVIDIA 580 branch** (Maxwell–Volta, which NVIDIA's own Debian 13 repo does not carry) | ([07](07-hardware-system.md)) | 550 covers them | 550 | 550 | 550 | 580 **OK** |
| **Python 3.11–3.13** (ryostage) | ([09b](09b-shell-native.md)) | 3.13.5 **OK** | 3.13.5 **OK** | 3.13.15 **OK** | 3.13.15 **OK** | 3.14 only **BUILD** |
| **ISO toolchain** | ([06](06-iso-boot.md)) | live-build 20250505 **OK** | **OK** | live-build 20250814 **OK** | **OK** | live-build 3.0~a57 unusable; use the mmdebstrap/xorriso script |
| **Login greeter without Xorg** | Debian's sddm depends on `xserver-xorg \| xserver` ([10](10-hub-ui-lockscreen.md)) | pulls Xorg | pulls Xorg | pulls Xorg (same sddm as sid) | pulls Xorg | no Xorg dependency |
| **Browsers as debs** | the `browser` role, `/usr/bin/chromium` ([02](02-package-map.md), [11](11-compositors-apps-theming.md)) | firefox-esr 140, chromium | same | firefox, chromium | firefox, chromium | snap only (firefox, chromium) |
| **Limine** | the boot chain, if kept ([06](06-iso-boot.md)) | absent **BUILD** | absent **BUILD** | absent **BUILD** | absent **BUILD** | absent **BUILD** |
| **niri** ≥ 26.04 and **xwayland-satellite** | ([11](11-compositors-apps-theming.md)) | absent; rustc 1.85 is a zero-margin MSRV | absent **BUILD** | absent **BUILD** | absent **BUILD** | absent **BUILD** |

## Totals

| | trixie | trixie + backports | forky | sid | resolute |
|---|---|---|---|---|---|
| Arch packages to build or repackage (of 248 distinct; [02](02-package-map.md)) | 72 | 64 | 50 | 48 | 53 |
| Plus Ryoku's own packages (every base) | 15 | 15 | 15 | 15 | 15 |
| Build list needed on every base | 45 | 45 | 45 | 45 | 45 |
| Extra rebuild stacks needed to hit the floors above | Qt 6.11 (about 9 source packages + private-ABI rebuilds), Hyprland 0.56 stack + GCC 16, quickshell | same as trixie | none | none | Qt 6.11 (or a patched launcher), Hyprland 0.56 stack, quickshell |
| Mesa | 25.0.7 | 26.1.6 | 26.1.6 | 26.2.5 | 26.0.8 |
| systemd | 257.13 | 257.13 | 262 | 262.1 | 259.9 |
| PipeWire | 1.4.2 | 1.6.9 | 1.6.9 | 1.6.9 | 1.6.2 |
| Release model | frozen stable, security-supported | frozen stable + backports | rolling until it becomes Debian 14 (release date not announced); the Debian security team does not cover testing | rolling, no freeze | frozen LTS (standard support to 2031) |

## What only one base has

- **forky/sid** is the only base where Qt, Quickshell and Hyprland all clear their
  floors from the archive with no rebuild stack. It shares Arch's rolling model, and
  Debian's own rebuilds of quickshell and the Hyprland stack follow each Qt or
  Hyprland upload.
- **Ubuntu 26.04** is the only base whose archive carries current NVIDIA branches
  (580/595/615, with prebuilt signed modules through `ubuntu-drivers`), and whose
  sddm doesn't pull Xorg. It lacks quickshell, Hyprland 0.56, Qt 6.11 and live-build,
  and its browsers are snaps.
- **trixie** is the only frozen Debian base. To reach the floors it needs a
  self-maintained Qt 6.11 stack, a Hyprland 0.56 stack built with GCC 16 (not in
  trixie), and quickshell. Pinning sid's g++-16 for the Hyprland build pulls sid's
  `libc6`/`libstdc++6` onto installed systems.

The base is decision **D-01** in [00-decisions.md](00-decisions.md).

# Ryoku on Debian

Instructions for reproducing [Ryoku](https://github.com/Ryoku-dev/ryoku) (an Arch Linux
desktop distro: Hyprland/niri, Quickshell shell, Go control plane, TUI installer, live ISO)
on a Debian base: Debian 13 trixie, Debian testing/sid, or Ubuntu 26.04.

Analysed against Ryoku commit `98a0368253d9628be72b853985878a5db90e1547`
(2026-09-26, 0.75.5-beta.20).

Work in progress: the per-subsystem deep dive is in `docs/`.

- `findings/BRIEF.md`: the method and output contract every section follows.
- `tools/pkgver`: prints a package's version in trixie, trixie-backports, forky, sid and
  Ubuntu 26.04 (resolute).

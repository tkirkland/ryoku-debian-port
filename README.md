# Ryoku on Debian

Instructions for reproducing [Ryoku](https://github.com/Ryoku-dev/ryoku) on a
Debian base: pure Debian (13 trixie, testing/forky, sid) or Ubuntu 26.04. Ryoku
is an Arch Linux distribution made of a Hyprland/niri desktop, a Quickshell
(QML) shell, a Go control plane, a Go TUI installer, an archiso live ISO and a
signed pacman repo. The target is the same look, feel and behaviour on Debian.

Analysed against Ryoku commit `98a0368253d9628be72b853985878a5db90e1547`
(2026-09-26, 0.75.5-beta.20). Every claim about Ryoku cites `path:line` in that
tree.

## Verdict

Nothing in Ryoku blocks a Debian reproduction; every gap has a concrete build or
rewrite path in these documents. The work concentrates in four places:

1. **Version floors** that decide the base: Qt ≥ 6.11, Quickshell ≥ 0.3.0,
   Hyprland ≥ 0.56 (built with GCC 16), and Go ≥ 1.26. Only forky/sid meet all
   four from the archive ([01](docs/01-base-comparison.md)).
2. **The package-manager seam.** `ryoku update`/`status`/`rollback`/`doctor`,
   the store, the Hub and a set of scripts call pacman/AUR directly and are
   rewritten on apt/dpkg ([05](docs/05-update-delivery.md),
   [03 C-03](docs/03-cross-cutting-changes.md)).
3. **The boot chain.** Limine and its two entry/snapshot tools exist only for
   pacman + mkinitcpio; they are either ported with a Debian hook layer or
   replaced by GRUB + grub-btrfs ([06](docs/06-iso-boot.md)).
4. **Your own infrastructure:** a signed apt repo, hosting, channels and CI in
   place of the creator's ([04](docs/04-packaging-repo-ci.md)).

Build counts (out of 248 distinct Arch packages, plus 15 of Ryoku's own on every
base):

| trixie | trixie + bpo | forky | sid | Ubuntu 26.04 |
| ------ | ------------ | ----- | --- | ------------ |
| 72     | 64           | 50    | 48  | 53           |

## Read in this order

| Doc                                                                   | What it holds                                                                                                                                                   |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [00-decisions.md](docs/00-decisions.md)                               | Every open decision (D-01…D-44) with options and consequences, in three tiers                                                                                   |
| [01-base-comparison.md](docs/01-base-comparison.md)                   | Each hard requirement against trixie / bpo / forky / sid / resolute                                                                                             |
| [03-cross-cutting-changes.md](docs/03-cross-cutting-changes.md)       | Edits that recur across the tree (QML path, `wheel`, pacman seam, hooks, paths, PATH, packaging behaviour, infrastructure, i18n, fonts)                         |
| [12-build-order.md](docs/12-build-order.md)                           | The implementation sequence, phase by phase, pointing into the sections                                                                                         |
| [02-package-map.md](docs/02-package-map.md)                           | All 354 package lines mapped to Debian/Ubuntu names, with versions in five suites, status, and recipes for every missing package                                |
| [04-packaging-repo-ci.md](docs/04-packaging-repo-ci.md)               | All 34 PKGBUILDs as `debian/` packaging, the signed apt repo and channels, 47 CI workflows, every creator URL/secret to re-point, package build order           |
| [05-update-delivery.md](docs/05-update-delivery.md)                   | The `ryoku` CLI: every subcommand, every external call and its apt equivalent, all 118 doctor reconcilers, snapshots/rollback, the Go change plan               |
| [06-iso-boot.md](docs/06-iso-boot.md)                                 | archiso → live-build or an mmdebstrap/xorriso script, Limine and its hooks, mkinitcpio → initramfs-tools/dracut, Plymouth, kernels (incl. CachyOS), Secure Boot |
| [07-hardware-system.md](docs/07-hardware-system.md)                   | GPU/NVIDIA, power, audio, network helpers, polkit, the store (ryostore) catalogue, containers, hardware-support packages                                        |
| [08-installer.md](docs/08-installer.md)                               | The install sequence step by step, the `RYOKU_*` contract, each step's Debian rewrite, the TUI, the no-ISO shell installer, tests                               |
| [09a-shell-qml.md](docs/09a-shell-qml.md)                             | The Quickshell front end: Qt modules and minimum versions, external commands, shaders, matugen, fonts                                                           |
| [09b-shell-native.md](docs/09b-shell-native.md)                       | The shell daemon, Ryoku.Blobs, ryogami, ryomotion, ryotunes, palette-bridge, helper scripts                                                                     |
| [10-hub-ui-lockscreen.md](docs/10-hub-ui-lockscreen.md)               | Ryoku Settings (Hub), Rashin, Ryoku.Ui, qylock + SDDM, PAM, i18n, OpenRGB                                                                                       |
| [11-compositors-apps-theming.md](docs/11-compositors-apps-theming.md) | Hyprland 0.56 (Lua) stack and plugins, niri, the wm seam, every app config, fonts/cursors/themes, portals                                                       |

`findings/` holds the method brief every section followed (`BRIEF.md`) and two
raw sub-reports that were folded into sections 05 and 10.

## Tools

`tools/pkgver <pkg>...` prints each package's version in trixie,
trixie-backports, forky, sid and Ubuntu 26.04 (any component, Debian or Ubuntu
name).

## Status

- **Done:** the read-only deep dive of the whole tree. Nothing has been built or
  booted yet; versions are as of 2026-10-17.
- **Next:** the Tier 1 decisions in [00-decisions.md](docs/00-decisions.md),
  then Phase 1 of [12-build-order.md](docs/12-build-order.md).

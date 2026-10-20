# 00 — Decisions for the human

Every point the deep dive could not settle from code, deduplicated across the
ten sections. Each entry lists the options with their concrete consequences and
the section that holds the detail.

**Tier 1** decisions shape the whole plan and gate everything in
[12-build-order.md](12-build-order.md). **Tier 2** decisions gate the
infrastructure phase. **Tier 3** decisions can wait until work reaches that
component.

**Status marks:** ✅ decided (a **Decided** line follows the heading), ⬜ open.
Inside a decided entry, ✅ marks the option taken and ❌ one rejected. Tier 1: 7
of 7 decided (D-01a/b/c settled by D-01; D-02a added 2026-10-20). Tier 2: 6
of 11. Tier 3: 1 of 27.

---

## Tier 1: plan-shaping

### ✅ D-01 Base suite

**Decided 2026-10-19: trixie (+bpo), on the Debian13-Hyprland framework** (the
build running on the reference machine). Goal: behaviour identical to Arch
Ryoku, no local patching.

Options: Debian 13 trixie (+ backports), Debian forky (testing), Debian sid,
Ubuntu 26.04 (resolute). Facts: [01-base-comparison.md](01-base-comparison.md).

- ❌ **forky/sid:** Qt 6.11.2, Quickshell 0.3.2 and Hyprland 0.56.2 are all in
  the archive, so there are no rebuild stacks. 50/48 packages to build. Rolling,
  like Arch. NVIDIA archive tops out at 550 (see D-05).
- ✅ **trixie (+bpo):** frozen and security-supported. Needs a self-maintained
  Qt 6.11 stack (about 9 source packages, every Qt security fix redone by hand),
  a Hyprland 0.56 stack plus a GCC 16 route (D-01a) and quickshell. 64 packages
  with bpo.
- ❌ **resolute:** frozen LTS. Current NVIDIA (580/595/615). Needs Qt 6.11 (or
  the launcher fallback, D-01b), the Hyprland 0.56 stack and quickshell.
  Browsers are snaps (D-36) and live-build is unusable (D-40). 53 packages.

What the framework already provides, so these are inherited rather than rebuilt:
the GCC 16 build root (D-01a), the Hyprland stack from git (D-01c), NVIDIA from
the CUDA repo (D-05), Secure Boot via Debian's signed shim + signed GRUB +
signed kernel with a per-install MOK key signing every DKMS module (D-04), the
installer and the ISO pipeline. Still to add: Qt 6.11 + quickshell (D-01b),
Go >= 1.26.4, and the snapshot/rollback chain (D-02).

### ✅ D-01a GCC 16 route for Hyprland ≥ 0.56 (trixie)

**Decided 2026-10-19: (a), inherited from the framework.**

- ✅ (a) Pin sid's `g++-16` into the build root. Installed systems carry sid's
  `libstdc++6` and `libgcc-s1` only; `libc6` stays trixie's. Verified 2026-10-20
  on the reference machine (libc6 2.41-12+deb13u4 with libstdc++6 and libgcc-s1
  16.1.0-2) and against sid's dependency floors (libstdc++6 16.2.0-3 needs
  `libc6 >= 2.38`). The built Hyprland needs GLIBCXX_3.4.34, which trixie's
  gcc-14 libstdc++6 (3.4.33) lacks, and GLIBC_2.38, which trixie's glibc covers.
  Those two libraries sit outside trixie's security updates, and a future sid
  libstdc++6 may raise its libc6 floor past 2.41, so the build must keep using
  the cached GCC 16 debs rather than sid of the day.
- ❌ (b) Backport `gcc-16` to trixie: a clean graph, but a multi-hour toolchain
  build redone for each GCC point release.
- ❌ (c) Try gcc-14 with Debian's patch set first, falling back to (a) or (b).

[11 §Hyprland]

### ✅ D-01b Qt route (trixie)

**Decided 2026-10-19: (a), still to build.**

- ✅ (a) Backport the Qt 6.11.2 source packages from forky, then rebuild every
  private-ABI consumer (quickshell, Hyprland plugins) on each Qt change.
- ❌ (b) Resolute only: stay on Qt 6.10 and accept that the default hero
  launcher falls back to okshell, or patch `hero/LauncherSurface.qml:466-469`.
  Not pixel-identical either way, and moot since resolute was rejected.

[09a]

### ✅ D-01c Hyprland stack source (trixie)

**Decided 2026-10-19: T2, inherited from the framework.**

- ❌ T1 Rebuild Debian's forky sources: Debian package names, `hyprland-abi-*`
  Provides, the least code to own.
- ✅ T2 A from-git builder: Arch-identical paths; owns every library,
  wayland/xkbcommon/libinput included.

[11]

### ✅ D-02 Bootloader and rollback chain

- ✅ **(a) Limine, as on Arch:** package `limine` (an easy build) plus
  `limine-entry-tool` and `limine-snapper-sync`. Both are GraalVM 25 + Gradle
  9.6.1 native builds whose hooks are pacman/mkinitcpio-only, so they need a
  Debian hook layer (kernel `postinst.d`/`postrm.d`, initramfs `post-update.d`,
  dpkg triggers, an apt hook). The rollback UX stays identical. Secure Boot
  through Debian's shim chain holds with D-04 (d), proven in 13.
- ✅ **(b) GRUB + grub-btrfs:** grub-btrfs is one shell project to package.
  Secure Boot works with `shim-signed` + `grub-efi-amd64-signed`. A restore
  helper must be written or the subvolume layout changed. The boot guard,
  `restoreGuide` and five doctor reconcilers are rewritten, and the Limine
  branding becomes a GRUB theme. [05 §6, 06 §Limine]

**Tested 2026-10-19 ([13](13-limine-secure-boot-zfs-test.md)):** stock Limine
12.9.4 runs behind Debian's shim + MOK once a `.sbat` section is added at
packaging time, and it boots a builtin-ZFS kernel's ZFS root and ZFS snapshots
from the ESP. Secure Boot is only enforced with the config hash enrolled, so
every menu rewrite needs `enroll-config` + `sbsign` with the per-install MOK
key. So (a) no longer loses Secure Boot, and D-04 (d) is proven in a VM.

**Decided 2026-10-19: both, chosen at install time.** The installer offers GRUB
or Limine, both behind shim + MOK. Cost: the boot guard, the restore guide and
the boot doctor reconcilers exist once per bootloader, and the snapshot-entry
tool writes both menu formats.

### ✅ D-02a Root filesystem

**Decided 2026-10-20: both, chosen at install time.** The installer offers btrfs
or ZFS for the root filesystem, like the bootloader (D-02) and kernel (D-06)
choices. Snapshots and rollback (D-10) exist on either: snapper on btrfs, ZFS's
own snapshots on ZFS. Every kernel variant has ZFS builtin (D-06). Entries
elsewhere that assume btrfs (D-02 (a), D-18, D-19, D-38) describe the btrfs path
and need a ZFS counterpart.

- ❌ btrfs only: matches Arch Ryoku exactly, least to change.
- ❌ ZFS only: matches the user's Debian projects and the kernels, proven in 13,
  but drops Ryoku's btrfs/snapper path.
- ✅ Both, chosen at install time (user: "if you're not going to make ZFS
  available, why did I make a custom kernel with it built in?").

### ✅ D-03 One codebase or a fork

- ✅ **(a) Fork:** replace pacman with apt in place. The smallest diff, but it
  diverges from upstream Ryoku on every file that touches packages.
- ❌ **(b) Dual:** `internal/sys/pkg_{pacman,apt}.go` behind a `debian` build
  tag, plus tagged twins (or skips) for the 28 Arch-only and 19 partly-Arch
  doctor reconcilers. A smaller merge surface against upstream. [05 Q-1]

**Decided 2026-10-19: (a) fork, used as the port's own original.** Debian
changes are made in place. A scheduled workflow fetches upstream
`Ryoku-dev/ryoku` and merges it; a clean merge that passes the build/tests lands
directly, while a conflict (or a clean merge that fails the checks) opens a PR
instead.

### ✅ D-04 Secure Boot target

**Decided: (b) and (d), shim + MOK under either bootloader.** (b) for GRUB
(2026-10-19 with D-01), (d) for Limine (confirmed by the user 2026-10-20 as the
meaning of D-02's "both"; proven in [13](13-limine-secure-boot-zfs-test.md)).

- ❌ (a) None: refuse Secure Boot, as Ryoku does today.
- ✅ (b) Debian shim + signed GRUB + MOK: works on Microsoft-keyed firmware. The
  chain on GRUB installs (D-02 (b)).
- ❌ (c) Limine + own keys: `sbctl` built from source, firmware Setup Mode per
  machine, and DKMS modules need a signing story.
- ✅ (d) Limine behind shim + MOK: proven in a VM on 2026-10-19 (13); real
  hardware not yet tested.

On Debian/Ubuntu kernels, Secure Boot turns on lockdown. Lockdown refuses
unsigned DKMS modules (NVIDIA) and disables hibernation (`resume=`). [06 §Secure
Boot, 08 Q5]

### ✅ D-05 NVIDIA driver source

**Decided 2026-10-19 with D-01: (b) the NVIDIA CUDA repo, as Debian13-Hyprland
does.**

- **(a) Debian archive 550.163** (Claude, not decided: the CUDA repo has no
  driver for Maxwell/Pascal/Volta, so those cards would fall here)**:** signed
  by Debian and security-supported. No RTX 50, no explicit sync, and the open
  module is missing in forky. Modules are renamed
  `nvidia-current`/`nvidia-current-open`, so Ryoku's `modinfo nvidia` probes (in
  `nvidia.sh`, the guard and `reconcile_hardware.go`) must accept those names.
- ✅ **(b) NVIDIA CUDA repo for debian13 (590–615, `nvidia-open`):**
  Arch-equivalent versions and module names. A third-party repo whose `dkms`
  overrides Debian's. No Maxwell/Pascal/Volta branch, so those cards fall back
  to (a), which means two origins and pinning.
- ❌ **(c) Ubuntu `ubuntu-drivers`:** resolute only; 580/595/615 with prebuilt
  signed modules.
- ❌ **(d) Port-built debs from NVIDIA's `.run`:** full control; the port
  carries the driver packaging.

Kepler has no driver on trixie, forky or resolute. [07 §NVIDIA, 08 Q4]

### ✅ D-06 Kernel and the CachyOS layer

- **Kernel per base:** stock (trixie 6.12 lacks sched_ext/ntsync/asus-armoury;
  trixie-bpo/forky 7.2 and Ubuntu 7.0 have them), or the trixie-backports kernel
  by default on trixie.
- **CachyOS:**
  - ❌ (a) Drop the CachyOS ISO variant and the Hub opt-in.
  - ❌ (b) Opt-in only, as in `docs/kernels.md`: a Ryoku-built CachyOS kernel
    deb (from the pre-patched tarball + BORE patch + config, `make bindeb-pkg`,
    clang ThinLTO).
  - ✅ (c) Full variant: that kernel plus `cachyos-settings`, `ananicy-cpp` +
    rules, `scx-scheds` and the `proton-cachyos` tarball, all self-built.
  - (d) A variant on Debian's own 7.2 kernel (sched_ext present, no BORE) plus
    self-built scx/ananicy/settings. Moot: a CachyOS kernel exists (below).

  A clang-built kernel needs DKMS modules (NVIDIA) built with `LLVM=1`; whether
  Debian's dkms does that automatically was not verified. A self-built kernel
  needs MOK signing under Secure Boot (D-04). [02 §CachyOS, 06 §Kernels, 07 Q4]

**Decided 2026-10-20: CachyOS layer = (c), the full variant.** Picking the
CachyOS kernel at install time brings `cachyos-settings`, `ananicy-cpp` + rules,
`scx-scheds` and `proton-cachyos` with it, all port-built, as on Arch. The layer
is bound to the CachyOS kernel: it installs with that kernel and only with it,
and a later kernel switch carries it along. No separate Hub toggle on the Debian
kernels (user, 2026-10-20: "keep Cachy together with Cachy and Debian together
with Debian").

**Decided 2026-10-19: kernel chosen at install time.**

- **Debian line (default):** Debian's own 6.12 LTS and 7.x kernels, rebuilt from
  Debian's source package with ZFS builtin, published by
  `tkirkland/ryokudebian-kernel` (public).
- **CachyOS:** CachyOS kernel with ZFS builtin, published by
  `tkirkland/ryokudebian-kernel-cachyos` (public).

Three variants (Debian 6.x, Debian 7.x, CachyOS), all ZFS builtin, in two repos.
The Debian variants build from Debian's own kernel source package. Each variant
keeps its current and previous release only (six releases at most) so a bad
build can be rolled back.

Both are self-built, so on Secure Boot machines they boot inside a UKI signed
with the per-install MOK key (proven in
[13](13-limine-secure-boot-zfs-test.md)). Two follow-ups this creates: these
kernels lack Debian's "lock down under Secure Boot" patch, so lockdown needs
`lockdown=integrity` in the signed UKI cmdline or that patch carried in the
build; and a clang-built CachyOS kernel needs NVIDIA's DKMS modules built with
`LLVM=1` (unverified).

---

## Tier 2: infrastructure

### ✅ D-07 Source-package shape

**Decided 2026-10-20: A, one native source for the monorepo.** Automated
upstream-version PRs for the stack are noted in [future.md](future.md), not part
of this phase.

- ✅ **A:** one `3.0 (native)` source for the monorepo. Exact pins via
  `${binary:Version}`; one source of about 300 MB per build (239 MB of it
  `ryoku/assets`). Plugins, oh-my-zsh and keysounds stay separate sources.
- ❌ **B:** one source per PKGBUILD (mirrors Arch). The 300 MB tree is
  duplicated per source, pins go through a substvar, and all sources must
  publish together. [04 §1.2]

### ✅ D-08 Repo tool

**Decided 2026-10-20: apt-ftparchive.** Stateless: the publish job builds, runs
apt-ftparchive over the output, signs the index, uploads to the host (D-09).
GitLab's Debian package registry was considered and ruled out on 2026-10-20:
GitLab's own docs list it as an Experiment, off by default, "not ready for
production use", with known security vulnerabilities.

Options were apt-ftparchive (stateless, closest to `build-repo.sh`, no by-hash),
reprepro (persistent db, one version per suite), or aptly (persistent db, native
snapshots, `publish switch` for the stable pointer, S3 publish, by-hash). [04
Q2]

### ✅ D-09 Hosting

- ❌ S3-compatible bucket (today's R2 model).
- ✅ Own server. The user's VPS (2026-10-20), which already runs their
  self-hosted GitLab. A plain directory: rsync the apt-ftparchive output, nginx
  serves it. No size caps, kernels and packages could share one repository.
  Uptime, patching, backups and TLS are ours.

**Decided 2026-10-20: the user's VPS**, a plain directory behind nginx holding
the apt-ftparchive output (D-08). Kernels stay on GitHub Releases until there is
a reason to move them.

[04 Q3]

### ✅ D-10 Channel layout and downgrades

**Decided 2026-10-20: one suite, `stable`, no channels; no apt downgrade path.**
Testing happens on the user's own machines before a release is tagged, not on a
public channel. "Go back" means booting the previous filesystem snapshot (ZFS or
btrfs, whichever the install chose) and the package set returns with it; no
`--allow-downgrades`, no 1001 pin. `ryoku track` and `ryoku rollback --to <tag>`
leave the fork (user: "ZFS and btrfs are there as your oh-shit button").

Options were:

- **Layout:**
  - D1: per-channel repo roots (the CLI switches `URIs:`).
  - D2: one root with suites (requires `ryoku-desktop` to stop embedding
    `CHANNEL=`).

  Either way the repo needs a base-suite dimension (trixie/forky/resolute) on
  top of stable/testing/tags. "Stable" can't be a byte copy of a release,
  because apt rejects a Release file whose Codename changes.

- **Downgrades:**
  - Explicit `<pkg>=<ver> --allow-downgrades`: only `ryoku update` moves the set
    down.
  - An origin pin at 1001: every apt run prefers Ryoku's versions, downgrades
    included.

[04 Q4, 05 Q-3]

### ✅ D-11 Signing key

**Decided 2026-10-20: offline primary + signing subkey.** The primary (ed25519,
no expiry) is the trust anchor shipped in the keyring package; it lives on a
thumb drive held by the user plus an encrypted off-site copy, with a
pre-generated revocation certificate beside it. A signing subkey (two-year
expiry) is held by the CI publish job (D-08) and signs every published index; a
leaked subkey is revoked and reissued without replacing the trust anchor on
installed machines. No debsigs on the .deb files; apt ignores them.

The open points were:

Who holds it (a GitHub secret only, or an offline primary + CI subkey), the
algorithm (ed25519 works with trixie's `sqv`), the expiry, and whether `.deb`
files also carry `debsigs` signatures (apt ignores them). [04 Q5]

### ✅ D-12 Debian's packages vs own builds where both exist

**Decided 2026-10-20: Debian's package whenever one exists at a version Ryoku
works with.** Own builds only where Debian lacks the package, ships one too old
for a floor Ryoku needs, or Ryoku patches it (user: "why would I provide
something that is byte for byte the same?"). Today that puts the Hyprland stack,
its plugins and quickshell in the own-build column and ble.sh, dualsensectl,
xpadneo-dkms, uv, bibata-cursor-theme and gpu-screen-recorder in Debian's. The
plugin-directory concern is moot since the plugins are own builds.

The list and the two poles were:

ble.sh, dualsensectl, xpadneo-dkms, bibata-cursor-theme, quickshell, uv,
gpu-screen-recorder, hyprbars/hyprfocus, the Hyprland stack:

- Use Debian's: fewer builds and Debian security updates, but versions and paths
  differ. Plugins land in `/usr/lib/x86_64-linux-gnu/hyprland/plugins/` without
  `.abi` receipts, which needs a Go change to the plugin tier.
- Always ship `[ryoku]` builds: Arch parity, but the pins block Debian updates.

[04 Q6, 11 §plugins]

### ✅ D-13 Hyprland plugin dependency strength

**Decided 2026-10-20: (a), hard pins.** Hyprland, the desktop package and the
five plugins are one matched set, built together from the monorepo and published
together. A new upstream Hyprland arrives as a pull request with the plugins
rebuilt against it; the user reviews, merges, and the publish job ships the set
(user: "hard coding the desktop and the plugins to whatever is installed at
release time"). No local plugin rebuilds on user machines.

- ✅ (a) Keep the hard `=` pins from `ryoku-desktop-hyprland` to all five
  plugins. Every Debian Hyprland upload or binNMU then blocks or removes the
  desktop until `[ryoku]` republishes the plugins.
- ❌ (b) Make them Recommends. Upgrades never block; a stale plugin shows "Needs
  rebuild" in the Hub and the doctor rebuilds it locally, as on Arch.

[11 §plugins]

### ✅ D-14 Compiler on user machines

**Decided 2026-10-20: gcc-16 installed by default, beside gcc-14.** The image
carries build-essential as Debian ships it (gcc-14 stays the default
`gcc`/`g++`; it is already there for the NVIDIA DKMS modules) plus the exact
sid-built gcc-16 and g++-16 debs the build root used (the frozen set, never sid
of the day, so they match the stack's libstdc++6). Debian's versioned GCC
packaging lets the two coexist; gcc-16 reuses build-essential's binutils, make
and libc6-dev. With the compiler present, `hyprpm` and hand builds against
Hyprland's C++26 headers work out of the box. Hyprland plugins beyond Ryoku's
five are published in the port's repo as pinned debs (D-13), not baked into the
image; which ones is a package-set question for later. No sid apt source on user
machines. Not a backport (that was D-01a (b), rejected).

The question as raised:

The runtime plugin rebuild (`ryoku doctor`, Hub > Plugins) compiles against
Hyprland's headers with the machine's default `c++`: g++ 14 on trixie, 15 on
resolute, 16 on forky/sid. Hyprland 0.56 headers are C++26. Decide which
compiler a user machine carries. [11 cross-cutting]

### ✅ D-15 Offline/vendored builds

**Decided 2026-10-20: (2), CI builds with network access.** Go and cargo lock
files pin what the build fetches; Debian's no-network build rule is not a goal.
Network is used at build time only. At install time nothing is downloaded:
mandatory packages are already in the squashfs; optional ones (ryomotion,
ryotunes, the Limine tools, and the like) sit as .debs in the ISO's local apt
repo and are installed only on the user's say-so at install time. That
install-time question is an installer requirement: see D-42 and 08.

The question as raised:

Fully vendored offline builds for Go, cargo, npm/Electron and Gradle/GraalVM
(ryomotion, ryotunes, limine tools; large component tarballs plus refresh
tooling), or CI builds with network access (simpler, but not reproducible in
sbuild). [04 Q9]

### ✅ D-16 `/etc` files shipped by packages

**Decided 2026-10-20: keep all four at the Arch paths (option 1).** systemd and
modules-load read /etc and /usr/lib alike, so nothing functional differs; the
Debian convention (package defaults under /usr/lib) only changes dpkg's conffile
handling: a prompt on upgrade if the user edited a file, and the file left
behind on remove until purge. Matching Ryoku wins (user: "if it ain't broke,
don't fix it"). The files: `/etc/ryoku-release`,
`/etc/systemd/logind.conf.d/10-ryoku-lid.conf`,
`/etc/modules-load.d/ryoku-i2c.conf`,
`/etc/modules-load.d/99-ryoku-uinput.conf`.

`/etc/ryoku-release`, the logind lid drop-in, two modules-load files:

- ✅ Keep them as conffiles at the Arch paths. Removing the package leaves them
  behind, and seeded files cause conffile prompts.
- ❌ Move them to `/usr/lib/...` vendor paths. That needs code changes wherever
  the CLI/doctor names the `/etc` paths.

[04 Q11]

### ✅ D-17 ryotunes

**Decided 2026-10-20: (b), built in the port's repo**, the separate GitHub
release channel and its code (`internal/ryotunesrelease`, `upgradeRyotunes`,
`reconcile_ryotunes`) leave the fork. ryotunes is optional on Arch (the
now-playing widget follows it when present), so under D-15 it ships as a .deb in
the ISO's local apt repo and is offered at install time, not baked into the
squashfs.

The options were:

(a) Ask upstream `ryoku-dev/ryotunes` to publish a `.deb` (Tauri can bundle one)
and keep the separate channel with `apt install ./file.deb`, or (b) build it in
the port's repo and delete the external channel code. [05 Q-4, 09b]

---

## Tier 3: per component

### Update system ([05](05-update-delivery.md))

- ⬜ **D-18 Snapshot pair per update:**
  - A: edit `/etc/default/snapper`.
  - B: divert `80snapper`.
  - C: use 80snapper's pair only.
  - D: accept four snapshots per update.

  Debian's `DISABLE_APT_SNAPSHOT` is read from `/etc/default/snapper`, not from
  the environment, so it can't replace `SNAP_PAC_SKIP` as-is.

- ⬜ **D-19 `snapper-boot.timer`:** Debian enables it, giving one snapshot per
  boot that counts against `NUMBER_LIMIT="10"`. Disable it in
  `reconcileSnapperCleanup`, or keep it.
- ⬜ **D-20 Held packages:** pass `--allow-change-held-packages` in the Ryoku
  lane (matches pacman's explicit targets), or skip held packages and report
  them.
- ⬜ **D-21 Cadence of formerly-AUR apps** (zen, localsend, voxtype, cursors):
  in the frozen release (they update only on a tag), or in a separate rolling
  suite (another channel dimension).
- ⬜ **D-22 Status freshness:** a private apt tree refreshed by `ryoku status`
  (no root, network on each poll, bounded at 120 s), or
  `APT::Periodic::Update-Package-Lists "1"` (root, twice a day).

### System and hardware ([07](07-hardware-system.md), [08](08-installer.md))

- ⬜ **D-23 Admin group:**
  - (a) Rewrite all 11 polkit rules from `isInGroup("wheel")` to `"sudo"` and
    create the user in `sudo`. This is native: Debian's polkit is built with
    `-Dprivileged_group=sudo`.
  - (b) Create `wheel` and put the user in both `wheel` and `sudo`. The rules
    ship unchanged, but `wheel` alone would leave every non-Ryoku polkit prompt
    asking for a locked root password.

  Today the install aborts at `useradd -G wheel` (`chroot.sh:117`).

- ⬜ **D-24 Docker:** `docker.io` (Debian; 26.1.5 on trixie; starts on install,
  so it needs an explicit disable) or `docker-ce` (Docker Inc. 29.9.1, matching
  Arch; no forky suite).
- ⬜ **D-25 Recommends policy:** apt installs Recommends by default and pacman
  has none. Either `--no-install-recommends` plus a keep-list, or install
  Recommends.
- ⬜ **D-26 AAC Bluetooth codec:** (a) none (Debian/Ubuntu ship no fdk-aac), or
  (b) a rebuilt `pipewire` with fdk-aac in the Ryoku repo, which forks a core
  audio package that then tracks every pipewire update.
- ⬜ **D-27 gpu-screen-recorder capability:** (a) `setcap cap_sys_admin` on
  `gsr-kms-server` in postinst, as Arch does, or (b) Debian's default, which
  means a pkexec prompt per recording or switching `RYOKU_SCREENRECORD_BACKEND`
  to `portal`.

### Store and apps ([07](07-hardware-system.md), [11](11-compositors-apps-theming.md))

- ⬜ **D-28 AUR-routed catalogue items** (37 items, plus zen-browser, qmk-hid,
  Looking Glass/kvmfr, nvibrant, davinci-resolve):
  - Flatpak.
  - Vendor apt repos (each one adds a signing key).
  - Upstream `.deb` or tarball downloads (no updates unless re-fetched).
  - Ryoku-built debs.

  The choice also decides whether `bundle.json` gains per-distro fields upstream
  or the actuator carries a Debian route table.

- ⬜ **D-29 Bundle catalogue on Debian:**
  - (a) Hide the Bundles tab.
  - (b) Map names locally and drop items with no Debian equivalent.
  - (c) Publish a Debian-specific registry in your fork of ryostore.

### Desktop and login ([10](10-hub-ui-lockscreen.md), [11](11-compositors-apps-theming.md), [09a](09a-shell-qml.md), [09b](09b-shell-native.md))

- ⬜ **D-30 Xorg on the login path:**
  - (a) Let sddm pull `xserver-xorg` (20+ unused packages).
  - (b) Satisfy `xserver` with `xvfb`/`xserver-xephyr`.
  - (c) Rebuild sddm without the X dependency.

  Not needed on resolute.

- ⬜ **D-31 Fingerprint at sudo/SDDM/polkit:**
  - (a) Build `pam-fprint-grosshack` v0.3.0 as a deb (Arch behaviour).
  - (b) Use stock `pam_fprintd` through `pam-auth-update`, and rewrite the Hub
    toggles. The password prompt then waits for the scan to time out.
- ⬜ **D-32 Fonts:**
  - SpaceMono Nerd Font is the documented mono font (`docs/ui-ux.md:216`,
    `Tokens.qml:107`), but no Ryoku package installs it, even on Arch. Ship it
    (the font the code asks for), or don't (matches what Arch machines actually
    render).
  - Fraunces: hard-installed, or optional as on Arch.
- ⬜ **D-33 Hermes (Rashin):** keep the upstream per-user installer (its own
  uv/Python/Node in `~/.hermes`), or package it as a deb (a large Python tree
  that tracks frequent upstream releases).
- ⬜ **D-34 Ryoku.Blobs Qt ABI pin:** shlibs only (Blobs uses only public Qt
  API), or an explicit `qt6-declarative-private-abi (= X)` that copies Arch's
  "rebuild on every Qt update" rule.
- ⬜ **D-35 niri build base (trixie only):**
  - (a) trixie rustc 1.85.1: a zero-margin MSRV and libinput 1.28.
  - (b) Backports rustc 1.96 in the build chroot.
- ⬜ **D-36 Browsers:**
  - Debian: `firefox-esr` (140) or Mozilla's APT repo (current Firefox).
  - Resolute: Chromium is snap-only. Use the snap (flags and native-messaging
    paths live inside confinement), a third-party deb, or a different default
    browser.
- ⬜ **D-37 Small parity calls:**
  - `ryoku-livewall`: an unused duplicate binary; ship it or drop it.
  - The "foreign/AUR" package count on the Profile plate: show manually
    installed `.deb`s, or relabel it.

### Installer and ISO ([06](06-iso-boot.md), [08](08-installer.md))

- ⬜ **D-38 ESP layout:**
  - (A) Keep `/boot` as the FAT ESP. Arch parity and no Ryoku path changes, but
    dpkg writes kernels onto FAT (chmod/chown EPERM risk).
  - (B) ESP at `/efi`, `/boot` on btrfs `@`. Debian-native, and kernels are
    inside snapshots. Changes about 40 hardcoded `/boot/...` paths.
- ⬜ **D-39 Kernel entry naming:**
  - (a) One entry per Debian kernel version; `default_entry` is repointed on
    each kernel install.
  - (b) Stable `linux` + `linux-previous` entries, which keeps Ryoku's
    `linux`/`linux-cachyos` logic.
- ⬜ **D-40 ISO toolchain:**
  - (a) live-build: declarative, but Debian-only and GRUB-only for EFI.
  - (b) An mmdebstrap + squashfs + xorriso script: Debian and Ubuntu, any EFI
    loader.
- ⬜ **D-41 Initramfs generator:**
  - initramfs-tools: Debian default, crypttab-driven; UKIs need `ukify`.
  - dracut: a direct HOOKS mapping, `dracut --uefi`, and limine-entry-tool
    already has a dracut flavour.
- ✅ **D-42 Offline install:** **Decided 2026-10-20 with D-15: fully offline
  ISO.** Mandatory packages are in the squashfs; optional ones ship as .debs in
  the ISO's local apt repo and are offered at install time; nothing is
  downloaded during install. The options were a fully offline ISO (a baked
  package closure per suite, plus NVIDIA stores), or online-only first.
- ⬜ **D-43 No-ISO shell installer on Debian:**
  - Keep the existing `fromSource` Debian path. It compiles the desktop on the
    user's machine (against cardinal rule 7) and skips GPU drivers.
  - Switch it to the port's apt repo.
  - Drop Debian support until the repo exists.

### Ryoku's own bugs found during the dive (carry over unless fixed)

- ⬜ **D-44** decide per item whether the port fixes it:
  - `system/hardware/network/50-ryoku-dns.rules:10` grants password-free root to
    any program whose path ends in `ryoku-dns`, a user-writable copy included.
  - `54-ryoku-bluetooth-a2dp.rules` lacks `active`/`local` checks.
  - `/usr/bin/ryoku-i18n` crashes at import looking for `/usr/langs.json`
    (`ryoku/i18n/tools/sync.py:64-77`).
  - Doc/code drift is listed in each section's cross-cutting findings.

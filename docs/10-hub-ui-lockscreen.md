# 10. Ryoku Settings (Hub), Rashin, Ryoku.Ui, lockscreen/greeter, i18n

Scope: the Hub backend `ryoku-hub` (`ryoku/hub/backend`, incl. the OpenRGB SDK
client) and its Quickshell front end (`ryoku/hub/quickshell`, every page),
Rashin (`ryoku/rashin`: Go daemon, embedded dashboard, Hermes/ACP bridge, the
`rashin` terminal command and its fish/bash/zsh weave, plus its `prowl-agent`
dependency), the shared `Ryoku.Ui` QML module (`ryoku/ui`), the in-session
qylock lock and the SDDM greeter (`ryoku/lockscreen`), the i18n catalog and
tools (`ryoku/i18n`), and the browser theme extension (`ryoku/browser`), at
Ryoku commit `98a0368` (0.75.5-beta.20). Packaging sources:
`release/packages/{ryoku-hub,ryoku-rashin,ryoku-desktop,prowl-agent}/PKGBUILD`.
Debian/Ubuntu versions come from `tools/pkgver` (trixie / trixie-backports /
forky / sid / resolute; "-" = absent, now including contrib/non-free); SDDM,
weston, openrgb and Qt5Compat facts were checked by downloading and unpacking
the real `.deb`s (inspection only). The Hub page-by-page call inventory (197
call sites) is in `findings/hub-qml-pages.md`; this document folds in its
conclusions.

| Component                                        | Path                                                          | As-is on Debian                | Complexity | Blocking issues                                                                                                                                                                                                 |
| ------------------------------------------------ | ------------------------------------------------------------- | ------------------------------ | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hub backend `ryoku-hub`                          | `ryoku/hub/backend/`                                          | PARTIAL                        | Medium     | Go >= 1.26.4 (trixie needs backports); `pacman`/AUR calls in passthrough enable, compositor switch and Reclaim; OVMF probe misses Debian paths; AppArmor blocks `/dev/kvmfr0`                                   |
| Lighting (OpenRGB SDK, Aura, QMK)                | `ryoku/hub/backend/{openrgb,lighting,lightingfx,aura,qmk}.go` | PARTIAL (NO on trixie)         | Low-Medium | no openrgb in trixie; Debian's openrgb has no udev rules and auto-enables an all-interfaces user unit; asusctl, qmk_hid unpackaged                                                                              |
| Hub front end (Ryoku Settings)                   | `ryoku/hub/quickshell/`                                       | PARTIAL                        | Medium     | Ryoku.Ui/FrameBars install path; quickshell >= 0.3.0 (not in trixie main or resolute); ~15 Arch-specific UI paths (pacman, AUR, GlazePKG, multilib, CachyOS, mkinitcpio, Limine); polkit rules keyed on `wheel` |
| Rashin daemon + dashboard + Hermes               | `ryoku/rashin/backend/`, `ryoku/rashin/systemd/`              | PARTIAL                        | Medium     | Go 1.26; packages/updates views are pacman/checkupdates-only; agent prompts hardcode "Arch Linux"/pacman; Hermes needs `libatomic1`                                                                             |
| `rashin` command + shell weave                   | `ryoku/apps/{fish,bash,zsh}/…rashin.*`                        | YES (bash recipes need ble.sh) | Low        | `blesh` not in Debian                                                                                                                                                                                           |
| prowl-agent                                      | `release/packages/prowl-agent/`                               | NO                             | Low        | not packaged; pinned commit has no license file                                                                                                                                                                 |
| Ryoku.Ui (and PluginKit, FrameBars, Blobs, Wm.*) | `ryoku/ui/`                                                   | NO                             | Low        | installed to `/usr/lib/qt6/qml`; Debian Qt6 reads `/usr/lib/x86_64-linux-gnu/qt6/qml`                                                                                                                           |
| i18n                                             | `ryoku/i18n/`, `ryoku/ui/Singletons/I18n.qml`                 | YES                            | Low        | none for Debian; `/usr/bin/ryoku-i18n` is broken on both distros (path bug)                                                                                                                                     |
| qylock in-session lock                           | `ryoku/lockscreen/qylock/quickshell-lockscreen/`              | PARTIAL                        | Low        | 18 absolute symlinks into `/usr/lib/qt6/qml/Qt5Compat/...` dangle                                                                                                                                               |
| SDDM greeter                                     | `ryoku/lockscreen/sddm/`, theme `clockwork/orbital`           | PARTIAL                        | Medium     | sddm pulls Xorg on Debian; greeter keyboard layout not read from `/etc/default/keyboard`; `modetest` in `libdrm-tests`; PAM anchors `system-login`; grosshack AUR-only with `/usr/lib/security` path            |
| Browser theme extension                          | `ryoku/browser/`                                              | YES                            | Low        | none                                                                                                                                                                                                            |

## Components

### Ryoku Hub backend `ryoku-hub` (`ryoku/hub/backend/`)

**What it does:** Go helper the Hub's QML shells out to for every stateful
operation (`ryoku/hub/backend/main.go:2`): the single writer of
`~/.config/ryoku/desktop.json` (`desktop.go:32,239,555,564`), which it hands to
the compositor provider through the `ryoku-wm` seam (`Apply`, `Preview`,
`DryRun`, `State`, `ApplyOutputs`, `Binds`, `Act(ConfigReload)`:
`desktop.go:63,217,280,383,394`, `outputs.go:90,150`, `keybinds.go:40`); the
provider, not the hub, renders `hypr/settings.lua`/`rebinds.lua`
(`ryoku/wm/hyprland/apply.go:56,59`) or `settings.kdl`
(`ryoku/wm/niri/apply.go:52`). TOML is used only for `~/.config/ryoku/hub.toml`
via BurntSushi/toml (`config.go:29-34,47,68`). Other domains: GPU passthrough
VM, render mode, MUX and tuning (`gpu*.go`), CPU/power (`cputune.go`, wraps
`ryoku-power`/`ryoku-idle`), lighting (next section), schemes/matugen/GTK/kitty
(`schemes.go`, `matugen.go`), qylock skins + SDDM greeter (`lock.go`), outputs
and profiles (`outputs.go`), config import (`import*.go`), fastfetch editor,
voxtype, login shell (`shellpref.go`), rice capture/apply (`rice*.go`),
clipboard over the shell socket (`clipboard.go`, `daemonclient.go:26-30`).
Packaged by `release/packages/ryoku-hub/PKGBUILD:24-29`
(`CGO_ENABLED=0 go build -trimpath -mod=vendor`, `/usr/bin/ryoku-hub`,
`depends=()`, every runtime tool found by `LookPath`).

**Build:** `go 1.26.4`, `toolchain go1.26.5` (`ryoku/hub/backend/go.mod:3,5`).
Requires `github.com/BurntSushi/toml v1.6.0`,
`github.com/godbus/dbus/v5 v5.2.2`, `golang.org/x/sys v0.27.0` (direct:
`reloadcover.go:17`), `ryoku-wm` (`replace => ../../wm`), `ryostore`
(`replace => ../../apps/ryostore/backend`, only `ryostore/compat` used,
`rice.go:944`); all five vendored in `vendor/` (3.6 MB).

**Arch couplings:**

- `pacman -S --needed --noconfirm qemu-desktop libvirt edk2-ovmf swtpm dnsmasq`
  and `pacman -Q` (`gpuapply.go:200-205,303-310`).
- AUR: `ryoku-pkg-aur-add`, else `yay -S --needed`, else `paru -S --needed` for
  `looking-glass looking-glass-module-dkms` (`gpuapply.go:86-96,204`); hints
  "try: yay -S" (`gpuapply.go:80,226`, `hwcaps.go:282`).
- Compositor switch: `pacman -Si ryoku-desktop-<wm>` for availability
  (`wm.go:40,171-174`); the vendored `ryoku-wm` compiled into the hub runs
  `pacman -Q`, `pacman -Rs --print`, `pacman -Qi` for Reclaim
  (`vendor/ryoku-wm/reclaim.go:204-205,247-255,271-276`, reached from
  `wm.go:155`).
- Snapshots: `snapper -c root create` / `cleanup number` before passthrough
  enable and config import (`gpuapply.go:312-321`, `import_apply.go:342-350`);
  best-effort, silently skipped without a `root` config.
- OVMF probe only knows Arch/Fedora paths:
  `usr/share/edk2/x64/OVMF_CODE{.4m,}.fd`,
  `usr/share/edk2-ovmf/x64/OVMF_CODE.fd`, `usr/share/OVMF/OVMF_CODE.fd`
  (`hwcaps.go:574-584`). Debian trixie `ovmf` and forky/sid/resolute
  `ovmf`/`ovmf-generic` ship `/usr/share/OVMF/OVMF_CODE_4M.fd` and
  `/usr/share/ovmf/OVMF.fd`, so the passthrough verdict never reaches "ready"
  (`gpuvm.go:109-129`).
- `modinfo kvmfr` run as the user (`hwcaps.go:592`): on Debian
  `modinfo`/`modprobe` are in `/usr/sbin`, which Debian's `/etc/profile` PATH
  for non-root users (`/usr/local/bin:/usr/bin:/bin:/usr/games`) does not
  include; Arch has merged `/usr/sbin` into `/usr/bin`. Calls run as root
  through pkexec get pkexec's sanitized PATH and work.
- IOMMU hint assumes "modern kernels already default intel_iommu=on"
  (`hwcaps.go:233-238`); trixie's 6.12 kernel config has
  `# CONFIG_INTEL_IOMMU_DEFAULT_ON is not set`.
- `swtpm` presence is the only TPM check (`hwcaps.go:567`); Debian splits
  `swtpm_setup` into `swtpm-tools`, which libvirt needs for the domain's TPM
  (`gpudomain.go:203`).
- `voxtype.go:44` assumes the Arch `voxtype-bin` package's root-owned
  `/usr/bin/voxtype` engine symlink.
- `apps.go:36-40` default-app chips probe `firefox` (Debian trixie ships
  `firefox-esr`), `brave` (Brave's Debian package installs `brave-browser`),
  `google-chrome-stable`, `vivaldi-stable`.
- Compositor named directly despite AGENTS rule 2: `gpumode.go:19,137`
  (`~/.config/hypr/gpu.lua`, `AQ_DRM_DEVICES`), `import.go:391-397`,
  `apps.go:115-125`, `desktop.go:36`, `import_apply.go:62,96`,
  `import_parse.go:60-466`, `matugen.go:145`, `rice.go:1017` (not
  Debian-specific).
- Root-written files (all identical paths on Debian; overridable with
  `RYOKU_ETC_ROOT`, `gpuapply.go:297`): `/etc/modules-load.d/ryoku-kvmfr.conf`,
  `/etc/modprobe.d/ryoku-kvmfr.conf`, `/etc/udev/rules.d/99-ryoku-kvmfr.rules`,
  `/etc/polkit-1/rules.d/50-ryoku-libvirt.rules` (`isInGroup("libvirt")`,
  `gpuapply.go:185-188`), `/etc/libvirt/hooks/qemu` (`gpuapply.go:157-176`),
  `/usr/share/sddm/themes/ryoku` + `/etc/sddm.conf.d/99-ryoku.conf`
  (`lock.go:373-384,458-468`). User-written system file:
  `/var/lib/ryoku/greeter-primary`, mode 0666 (`outputs.go:187,194`), which
  needs the tmpfiles entry `ryoku/cli/systemd/ryoku.tmpfiles.conf:10`.
- GPU passthrough is runtime-only: no kernel cmdline, initramfs or boot-time
  VFIO. The libvirt hook calls `ryoku-hub gpu hook prepare|release` for
  `ryoku-*` domains only (`gpuhook.go:98`): `modprobe vfio-pci`,
  `driver_override`, `driver/unbind`, `drivers_probe` (`gpuhook.go:44-68`). The
  header comment claiming a kernel cmdline token (`gpuapply.go:6-7`) is stale
  (`ryoku/hub/CHANGELOG.md:1884-1895`). No mkinitcpio, limine, grub, sbctl, scx
  or os-release reads anywhere in the backend.
- Group names `libvirt`, `kvm` (`gpuapply.go:247-248,270-271`; `hwcaps.go:402`)
  match Debian/Ubuntu.

**Dependencies:**

| Arch pkg                    | Used for (cite)                                                                                                                       | Debian/Ubuntu pkg                                            | trixie                 | trixie-bpo            | forky             | sid               | resolute                      | Min version Ryoku needs (why, cite)                                                    |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------- | --------------------- | ----------------- | ----------------- | ----------------------------- | -------------------------------------------------------------------------------------- |
| go (build)                  | `go build -mod=vendor` (`PKGBUILD:25`)                                                                                                | golang-1.26-go (or golang-go 2:1.27 in trixie-bpo/forky/sid) | -                      | 1.26.9-1~bpo13+1      | 1.26.9-1          | 1.26.9-1          | 1.26.8-1~ubuntu0.26.04.2      | 1.26.4 + toolchain 1.26.5 (`go.mod:3,5`); trixie golang-go is 1.24                     |
| polkit                      | `pkexec env PKEXEC_UID=... <self>` (`gpuapply.go:59-66`, `lock.go:404`, `gputune.go:339-352`, `gpupreset.go:158`, `shellpref.go:218`) | pkexec, polkitd                                              | 126-2                  | -                     | 127-3             | 128-1             | 127-2ubuntu1.1                | none                                                                                   |
| shadow                      | `gpasswd -a/-d` (`gpuapply.go:247-248,270-271`), `usermod -s` (`shellpref.go:241`)                                                    | passwd                                                       | 1:4.17.4-2             | -                     | 1:4.20.3-1        | 1:4.20.3-1        | 1:4.17.4-2ubuntu3             | none                                                                                   |
| systemd                     | `systemctl`, `systemd-run --user`, `busctl --user` (`gpuapply.go:249`, `lighting.go:1198`, `sharestatus.go:34`)                       | systemd, udev                                                | 257.13-1~deb13u1       | -                     | 262-1             | 262.1-1           | 259.9-0ubuntu0.1              | none                                                                                   |
| dbus                        | `dbus-update-activation-environment` (`shellpref.go:256`)                                                                             | dbus-bin                                                     | 1.16.2-2               | -                     | 1.16.2-8          | 1.16.2-8          | 1.16.2-2ubuntu4               | none                                                                                   |
| kmod                        | `modprobe vfio-pci` (`gpuhook.go:45,132`), `modinfo kvmfr` (`gpuapply.go:182`, `hwcaps.go:592`)                                       | kmod                                                         | 34.2-2                 | -                     | 34.2-2+b2         | 34.2-2+b2         | 34.2-2ubuntu2                 | none                                                                                   |
| libvirt                     | `virsh --connect qemu:///system ...` (`gpuvm.go:174-347`, `gpuapply.go:251`)                                                          | libvirt-clients, libvirt-daemon-system                       | 11.3.0-3+deb13u3       | -                     | 12.8.0-1          | 12.8.0-1          | 12.0.0-1ubuntu5.6             | none                                                                                   |
| qemu-desktop                | `qemu-img create` (`gpuvm.go:226`), `/usr/bin/qemu-system-x86_64` (`gpudomain.go:180`), SPICE (`gpudomain.go:199`)                    | qemu-system-x86, qemu-system-modules-spice, qemu-utils       | 1:10.0.13+ds-0+deb13u1 | 1:11.0.2+ds-2~bpo13+1 | 1:11.1.2+ds-3     | 1:11.1.2+ds-3     | 1:10.2.1+ds-1ubuntu3.3        | none                                                                                   |
| edk2-ovmf                   | UEFI firmware (`gpudomain.go:141-143`, probe `hwcaps.go:574-584`)                                                                     | ovmf                                                         | 2025.02-8+deb13u1      | -                     | 2026.08+ds-2      | 2026.08+ds-2      | 2025.11-3ubuntu7.3            | none                                                                                   |
| swtpm                       | TPM 2.0 (`gpudomain.go:203`)                                                                                                          | swtpm, swtpm-tools                                           | 0.7.1-1.5              | -                     | 0.10.2-2          | 0.10.2-2          | 0.10.1+ds-1ubuntu3            | none                                                                                   |
| dnsmasq                     | libvirt default network (`gpuapply.go:203`)                                                                                           | dnsmasq-base (not `dnsmasq`, whose service binds :53)        | 2.91-1+deb13u2         | -                     | 2.93-3            | 2.93-3            | 2.92-1ubuntu0.5               | none                                                                                   |
| looking-glass ([ryoku]/AUR) | `looking-glass-client -f /dev/kvmfr0` (`gpuvm.go:326-334`)                                                                            | looking-glass-client                                         | -                      | -                     | -                 | 0+b7+ds1-1        | -                             | build from source elsewhere                                                            |
| looking-glass-module-dkms   | kvmfr (`gpudomain.go:211-214`)                                                                                                        | none                                                         | -                      | -                     | -                 | -                 | -                             | Ryoku-built DKMS .deb                                                                  |
| nvidia-utils                | `nvidia-smi --query-gpu/-pl/-pm/-lgc/-rgc/-rmc` (`gputune.go:285-287,380-407`)                                                        | nvidia-smi (non-free); Ubuntu nvidia-utils-580               | 550.163.01-2           | 550.163.01-4~bpo13+1  | 550.163.01-5.1    | 550.163.01-5.1    | 580.178.04 (nvidia-utils-580) | matches the installed driver                                                           |
| snapper                     | pre-change snapshot (`gpuapply.go:312-321`, `import_apply.go:342-350`)                                                                | snapper                                                      | 0.10.6-1.2             | -                     | 0.10.6-1.3+b1     | 0.10.6-1.3+b1     | 0.10.6-1.3                    | optional                                                                               |
| lua                         | `luac -p` validation (`import_apply.go:491-498`)                                                                                      | lua5.4 (`/usr/bin/luac` via `lua-compiler` alternative)      | 5.4.7-1+b2             | -                     | 5.4.9-1           | 5.4.9-1           | 5.4.8-1build1                 | none                                                                                   |
| git                         | `git clone --depth 1` (`import.go:170`)                                                                                               | git                                                          | 1:2.47.3-0+deb13u1     | -                     | 1:2.53.0-1        | 1:2.55.0-1        | 1:2.53.0-1ubuntu1             | none                                                                                   |
| fastfetch                   | preview (`fastfetch.go:515`)                                                                                                          | fastfetch                                                    | 2.40.4+dfsg-1          | -                     | 2.69.0+dfsg-1     | 2.69.0+dfsg-1     | 2.57.1+dfsg-1ubuntu1          | not determined here (config schema; see apps subsystem)                                |
| librsvg / imagemagick       | logo conversion `rsvg-convert` -> `magick` -> `convert` (`fastfetch.go:723-730`)                                                      | librsvg2-bin, imagemagick                                    | 2.60.0 / 7.1.1.43      | -                     | 2.63.2 / 7.1.2.31 | 2.63.2 / 7.1.2.33 | 2.61.3 / 7.1.2.18             | none                                                                                   |
| ffmpeg                      | rice previews (`rice.go:322,326`)                                                                                                     | ffmpeg                                                       | 7:7.1.5-0+deb13u1      | -                     | 7:9.0.2-3         | 7:9.0.2-3         | 7:8.0.1-3ubuntu2              | none                                                                                   |
| glib2                       | `gsettings set ... font-name` (`schemes.go:336`)                                                                                      | libglib2.0-bin                                               | 2.84.4-3~deb13u5       | -                     | 2.90.1-2          | 2.90.1-2          | 2.88.0-1ubuntu0.1             | none                                                                                   |
| matugen                     | `matugen -c <cfg> json` (`schemes.go:49`, `matugen.go:278,326`)                                                                       | not packaged                                                 | -                      | -                     | -                 | -                 | -                             | Arch extra 4.2.0; build `https://github.com/InioX/matugen` v4.2.0 (Rust 2021, cargo)   |
| voxtype-bin (AUR)           | `voxtype setup ...` (`voxtype.go:201,315`)                                                                                            | not packaged                                                 | -                      | -                     | -                 | -                 | -                             | upstream v1.1.1 publishes `voxtype_1.1.1-1_amd64.deb` (github.com/peteonrails/voxtype) |
| asusctl ([ryoku])           | asusd D-Bus `xyz.ljones.Asusd` (`aura.go:14-18,66,71`)                                                                                | not packaged                                                 | -                      | -                     | -                 | -                 | -                             | Ryoku builds 6.4.0 (`release/packages/asusctl/PKGBUILD:3,7`); Arch extra 6.5.0         |
| qmk_hid                     | `qmk_hid --list`, `qmk_hid via --rgb-effect` (`qmk.go:35-40,118-122`)                                                                 | not packaged                                                 | -                      | -                     | -                 | -                 | -                             | upstream FrameworkComputer/qmk_hid v0.1.13                                             |

**As-is on Debian:** PARTIAL: builds with backported Go and runs; passthrough
enable, the compositor switch list and Reclaim depend on pacman; OVMF detection
fails.

**Port steps:**

1. Build: `apt install -t trixie-backports golang-1.26-go` (trixie) and
   `GOTOOLCHAIN=local CGO_ENABLED=0 /usr/lib/go-1.26/bin/go build -trimpath -mod=vendor -o ryoku-hub .`
   in `ryoku/hub/backend`. Debian's `golang-1.26` `go.env` sets
   `GOTOOLCHAIN=auto`, so without `local` an offline build tries to fetch
   go1.26.5.
2. Package-manager seam (shared with `ryoku-wm` and the CLI, see Cross-cutting):
   replace `pacmanInstall` (`gpuapply.go:303-307`) with
   `apt-get install -y --no-install-recommends qemu-system-x86 qemu-system-modules-spice qemu-utils libvirt-daemon-system libvirt-clients ovmf swtpm swtpm-tools dnsmasq-base`,
   `pkgInstalled` (`:310`) with `dpkg-query -W -f='${db:Status-Status}' <p>` =
   `installed`, `aurInstall` (`:86-96`) with the Ryoku apt repo's
   `looking-glass-client` + kvmfr DKMS debs, `pkgAvailable` (`wm.go:174`) with
   `apt-cache policy <p>` (Candidate not `(none)`), and the vendored `ryoku-wm`
   Reclaim calls (`reclaim.go:204-276`) with `apt-get -s remove`/`dpkg-query`;
   then re-vendor `ryoku/wm`. Rename the packages in
   `corePassthroughPkgs`/`extraPassthroughPkgs` (`gpuapply.go:203-204`).
3. `hwcaps.go:574-584`: add `usr/share/OVMF/OVMF_CODE_4M.fd` (and
   `usr/share/ovmf/OVMF.fd`).
4. `hwcaps.go:592`: call `/usr/sbin/modinfo` (or `exec.LookPath` with
   `/usr/sbin:/sbin` appended).
5. `hwcaps.go:567`: also require `swtpm_setup`.
6. AppArmor (enabled by default on Debian and Ubuntu): the libvirt-qemu profile
   denies `/dev/kvmfr0`; add `/dev/kvmfr0 rw,` to
   `/etc/apparmor.d/local/abstractions/libvirt-qemu` in the passthrough enable
   step, and add `/dev/kvmfr0` to `cgroup_device_acl` in
   `/etc/libvirt/qemu.conf` (not handled anywhere in the repo on Arch either).
7. IOMMU hint (`hwcaps.go:233-238`): on Debian Intel, IOMMU groups can be absent
   with VT-d enabled; add the `intel_iommu=on` cmdline remedy (GRUB:
   `/etc/default/grub` `GRUB_CMDLINE_LINUX_DEFAULT`, then `update-grub`;
   bootloader subsystem owns the mechanism).
8. `apps.go:36-40`: add `firefox-esr` and `brave-browser` alternatives
   (`"firefox|firefox-esr"`, `"brave|brave-browser"`).
9. Package matugen, voxtype (repackage upstream deb into the Ryoku apt repo),
   asusctl, qmk_hid, kvmfr DKMS as .debs.

**Complexity:** Medium: one package-manager seam plus four one-line path fixes;
the passthrough lane also needs AppArmor handling Arch never had.

**Issues / risks:**

- AppArmor is a new failure mode for the VM lane on Debian/Ubuntu; nothing in
  the repo knows about it.
- `snapper` has no `root` config on a Debian install unless the installer
  creates one; snapshots then silently do nothing (`gpuapply.go:312-321`).
- `apps.go` default-app detection, the Hub's Default Apps chips and
  `mimeapps.list` assume Arch binary names.

### Lighting: OpenRGB, ASUS Aura, QMK (`ryoku/hub/backend/{openrgb,lighting,lightingfx,aura,qmk}.go`)

**What it does:** `openrgb.go` is a pure-Go OpenRGB SDK client over TCP
`127.0.0.1:6742`, client name `ryoku-hub`, protocol 5 offered
(`openrgb.go:22-26`), accepting a server at 3 or higher (`openrgb.go:184`) but
requesting and parsing controller data as v5 (`openrgb.go:285,403,409`). When no
server answers it starts `openrgb --server --server-host 127.0.0.1` with
`QT_QPA_PLATFORM=offscreen` as transient user unit `ryoku-openrgb`
(`systemd-run --user --collect --unit=...`), or via setsid without systemd
(`lighting.go:30,1189-1213`); it only ever stops its own unit. Animated effects
re-exec the hub as `lighting animate` under transient unit `ryoku-lighting-fx`
(`lightingfx.go:22,350-369`). ASUS keyboards go through asusd over the system
bus (`aura.go:14-18,83,164,184`); QMK/VIA boards through the `qmk_hid` CLI
(`qmk.go:35-40,118-122`). State: `~/.config/ryoku/lighting.json`
(`lighting.go:86`). The backend writes no udev rules and loads no `i2c-dev`;
`ryoku-desktop` loads `i2c-dev` for ddcutil
(`release/packages/ryoku-desktop/PKGBUILD:577`). The Hub's lighting page
`pages/LightingTab.qml` is not referenced by the page map
(`ryoku/hub/quickshell/Hub.qml:490-495`); `openrgb` is an optdepend only
(`release/packages/ryoku-desktop/PKGBUILD:228`).

**Arch couplings:** none in code. Packaging differences:

- Arch `openrgb` 1.1 ships `/usr/lib/udev/rules.d/60-openrgb.rules` and a system
  `openrgb.service` that is not enabled (Arch file list).
- Debian forky/sid `openrgb` 1.0+ds-0.1 (Qt5 build:
  `Depends: libqt5core5t64 ...`) ships no udev rules (file list: binary, user
  unit, tmpfiles, desktop file, icon, man page, metainfo, lintian override)
  while its postinst still runs `udevadm trigger`; it auto-enables a global user
  unit (`deb-systemd-helper --user enable 'openrgb.service'`, postinst
  `:22-24,38-42`) whose
  `ExecStart=/usr/bin/openrgb --server --config /etc/openrgb` listens on
  OpenRGB's default host (all interfaces) at every login, with
  `ProtectHome=true` and `ReadWritePaths=/etc/openrgb` on a root-owned 0755 dir
  (`/usr/lib/tmpfiles.d/openrgb.conf`).
- Ubuntu resolute `openrgb` 0.9+git20251009+ds-1 ships `60-openrgb.rules`; it is
  a git snapshot dated after 1.0rc1 and 1.0rc2, so protocol 5 is expected (the
  Ubuntu source was not inspected).
- trixie has no openrgb.

**Dependencies:**

| Arch pkg            | Used for (cite)                                                | Debian/Ubuntu pkg | trixie | trixie-bpo | forky      | sid        | resolute             | Min version Ryoku needs (why, cite)                                                                                                                                                   |
| ------------------- | -------------------------------------------------------------- | ----------------- | ------ | ---------- | ---------- | ---------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| openrgb (optdepend) | SDK server (`lighting.go:1193-1202`)                           | openrgb           | -      | -          | 1.0+ds-0.1 | 1.0+ds-0.1 | 0.9+git20251009+ds-1 | SDK protocol 5 in practice (`openrgb.go:285,403,409`): upstream `NetworkProtocol.h` is 4 in `release_0.9`, 5 from `release_candidate_1.0rc1` (2025-02-22), 6 on master; Arch runs 1.1 |
| systemd             | `systemd-run --user` (`lighting.go:1198`, `lightingfx.go:362`) | systemd           | 257.13 | -          | 262        | 262.1      | 259.9                | none                                                                                                                                                                                  |
| asusctl             | asusd (`aura.go`)                                              | not packaged      | -      | -          | -          | -          | -                    | Ryoku builds 6.4.0                                                                                                                                                                    |
| qmk_hid             | `qmk.go`                                                       | not packaged      | -      | -          | -          | -          | -                    | v0.1.13 upstream                                                                                                                                                                      |

**As-is on Debian:** PARTIAL on forky/sid/resolute (openrgb present; no udev
rules on Debian; the auto-enabled user unit wins the port); NO on trixie (no
openrgb).

**Port steps:**

1. trixie: build OpenRGB 1.1 (Arch's version, tag `release_1.1`, 2026-10-16)
   from `https://gitlab.com/CalcProgrammer1/OpenRGB` (qmake/Qt) as a .deb, or
   backport Debian's `openrgb` 1.0+ds-0.1 source package to trixie.
2. Ship `60-openrgb.rules` in a Ryoku package at
   `/usr/lib/udev/rules.d/60-openrgb.rules` (generated upstream by
   `scripts/build-udev-rules.sh`; upstream doc `UdevRules.md` is in the Debian
   package docs) and `udevadm control --reload-rules && udevadm trigger` in
   postinst.
3. Disable Debian's global user unit so the hub's 127.0.0.1-only transient
   server is the one used: `systemctl --global disable openrgb.service` in the
   Ryoku package postinst (or a user preset `disable openrgb.service` in
   `/usr/lib/systemd/user-preset/`).
4. Load `i2c-dev` at boot (`/usr/lib/modules-load.d/`) as `ryoku-desktop` does
   today for ddcutil (`PKGBUILD:577`).

**Complexity:** Low (forky/sid) to Medium (trixie: source build).

**Issues / risks:** Debian's openrgb user unit exposes the SDK on all interfaces
on every login unless disabled; Ryoku's client connects to whatever answers on
6742 (`openrgb.go:22-26`), so it silently uses that server instead of its own
loopback one.

### Ryoku Settings (Hub) front end (`ryoku/hub/quickshell/`)

**What it does:** Quickshell config `hub`, installed to
`/usr/share/ryoku/config/quickshell/hub` and materialised to
`~/.config/quickshell/hub` (`release/packages/ryoku-desktop/PKGBUILD:274-275`).
Launched by `ryoku-shell hub open` (desktop entry
`ryoku/hub/ryoku-hub.desktop:6`; Super+comma
`ryoku/hyprland/modules/binds.lua:72`; neutral catalogue id `shell.settings`,
`ryoku/wm/binds.go:169`), which raises a live Hub over
`qs ... ipc call nav section` or starts
`flock -n -o /tmp/ryoku-hub.lock qs -c hub`
(`ryoku/shell/ipc/control.go:138-200`). 33 pages (`pages/`), singletons
(`Singletons/Updates.qml`, `SysInfo.qml`, `LiveStats.qml`, `Settings.qml`, ...),
schema-driven pages (`schema/*.js`). 197 external call sites; all state changes
go through `ryoku-hub`, the `ryoku` CLI, `ryostore`, `ryoku-shell` and Ryoku
helpers (full list: `findings/hub-qml-pages.md` §2).

**Arch couplings:**

- Imports need Ryoku.Ui and Ryoku.FrameBars on the default QML path
  (`Hub.qml:32`, `pages/BarStudioPage.qml:10`, `TimezoneMap.qml:5`); see the
  Ryoku.Ui section.
- pacman / AUR / GlazePKG / multilib / CachyOS / mkinitcpio / snapper+Limine
  reach the UI through the pages below.
- polkit rules that make the Hub's pkexec calls password-free key on
  `subject.isInGroup("wheel")`
  (`system/hardware/network/55-ryoku-network-kill.rules:8`,
  `system/policy/52-ryoku-timedate.rules:8`,
  `system/hardware/gpu/45-ryoku-gpu-mux.rules:6`, and the other
  `system/**/4x-5x-*.rules`). Debian/Ubuntu's admin group is `sudo`.
  `ConnectionsPage.qml:66-69` runs `pkexec /usr/bin/ryoku-network-kill status`
  with `running: true` on page load, so on Debian every visit to Connections
  asks for a password.
- `ryoku-wifi-backend get` treats "no drop-in" as iwd
  (`system/hardware/network/ryoku-wifi-backend:26-28`); Debian's NetworkManager
  defaults to wpa_supplicant.
- `pacman` name collision: Debian has the `pacman` game in `/usr/games` (on
  users' PATH) and `pacman-package-manager`; any `command -v pacman` /
  `LookPath("pacman")` presence check (e.g.
  `ryoku/shell/scripts/ryoku-sysinfo:71` `pacman -Qq`) can misfire.
- Install date read from `/var/log/pacman.log` (`pages/ProfilePage.qml:47`).

**Hub pages that surface Arch concepts (UI text or logic) and what they must
become:**

| Page                               | file:line                                                                                                                                                                                                                                                                     | Concept                                                                                                                         | What it does now                                                                    | Must become on Debian/Ubuntu                                                                                                                                                                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Updates                            | `pages/UpdatesPage.qml:591-595`                                                                                                                                                                                                                                               | pacman, "Arch or CachyOS"                                                                                                       | UI text "From your distribution, kernel included. Take them with: sudo pacman -Syu" | "sudo apt update && sudo apt full-upgrade" (i18n key changes)                                                                                                                                                                                 |
| Updates (singleton)                | `Singletons/Updates.qml:26,49-66`; daemon `ryoku/shell/ipc/updates.go:23-100` -> `ryoku status --json` -> `checkupdates`, `yay -Qua`, `pacman -Q ryoku-desktop`, `pacman -Sl ryoku` (`ryoku/cli/internal/updater/update.go:1675-1744`, `ryoku/cli/internal/sys/sys.go:58-67`) | update availability + SYSTEM PACKAGES list                                                                                      | "available" from the Ryoku lane; distro lane informational                          | `dpkg-query -W ryoku-desktop` vs `apt-cache policy ryoku-desktop`; distro lane from `LC_ALL=C apt-get -s -o Debug::NoLocking=1 full-upgrade` (design owned by `docs/05-update-delivery.md`); AUR lane dropped or mapped to non-Debian origins |
| Updates                            | `pages/UpdatesPage.qml:212-229,874-891`                                                                                                                                                                                                                                       | snapper + Limine ROLL BACK; `kitty -e sh -c "exec ryoku update"`                                                                | rollback/update in a terminal                                                       | snapper exists (0.10.6); limine/limine-snapper-sync absent in every suite, so rollback-to-boot needs the bootloader subsystem's answer or the button hides                                                                                    |
| Profile                            | `pages/ProfilePage.qml:47`                                                                                                                                                                                                                                                    | `/var/log/pacman.log`                                                                                                           | install-date fallback                                                               | `/var/log/installer/` or oldest `/var/log/dpkg.log*` / `/var/lib/dpkg/info` mtime, after `stat %W /`                                                                                                                                          |
| Profile                            | `pages/ProfilePage.qml:752-763`; `Singletons/SysInfo.qml:52-53,107-108`; `ryoku/shell/scripts/ryoku-profile-stats:51-52` (`pacman -Qen`, `-Qm`)                                                                                                                               | "N EXPLICIT · N AUR · N TOTAL"                                                                                                  | package counts                                                                      | `apt-mark showmanual \| wc -l`, `dpkg-query -W \| wc -l`; "AUR" -> packages not from a Debian archive origin (e.g. `apt list '?narrow(?installed,?not(?origin(Debian)))'`); new i18n key                                                      |
| Dictation                          | `pages/DictationPage.qml:110-122,270,287,667,679`                                                                                                                                                                                                                             | GlazePKG `gpk install voxtype-bin --manager aur`                                                                                | install/remove Voxtype in kitty                                                     | `sudo apt install voxtype` from the Ryoku apt repo (repackaged upstream `voxtype_1.1.1-1_amd64.deb`)                                                                                                                                          |
| Plugins                            | `pages/PluginsPage.qml:13-15,357`; `ryoku/wm/hyprland/config_plugins_tier.go:648-659`                                                                                                                                                                                         | "Install base-devel", `pkg-config --exists hyprland`                                                                            | hyprpm toolchain gate                                                               | `build-essential cmake git pkg-config` + Hyprland headers from the Ryoku Hyprland deb stack (`hyprland-dev`: - / 0.55.2 / 0.56.2 / 0.56.2 / 0.53.3 in the archive; `hyprland.pc` presence not verified)                                       |
| Add-ons (Bundles)                  | `AddonsPage.qml:86-93,185-199`; `schema/AddonsPage.js:58`; `system/extras/ryostore-install:85-100,250,258,283-353`                                                                                                                                                            | pacman, AUR, `ryoku-pkg-multilib`, `ryoku-pkg-cachyos` via `ryostore-install`                                                   | remove component/bundle, installed counts                                           | apt-based `ryostore-install`; AUR -> Ryoku apt repo / upstream .deb; multilib -> `dpkg --add-architecture i386 && apt update`; CachyOS route dropped (no CachyOS kernel/repo on Debian)                                                       |
| Window Manager / compositor switch | `CompositorSwitchSheet.qml:14,46,94,110-129,338,369-370`; `CompositorControl.qml:145`; backend `wm.go:16,150-174`                                                                                                                                                             | "reversible pacman transaction", `pacman -Si`, pacman size wording                                                              | switch compositor, keep or remove the old one                                       | `apt-get install` / `apt-get remove` + `autoremove`; `apt-cache policy` availability; sizes from `dpkg-query -W -f='${Installed-Size}'` (KiB)                                                                                                 |
| Graphics & Power                   | `pages/GpuPage.qml:212-222,1062,1135`; backend `gpuapply.go:68-95,203-226,303-310`, `hwcaps.go:280`                                                                                                                                                                           | pacman `qemu-desktop libvirt edk2-ovmf swtpm dnsmasq`; AUR `looking-glass(-module-dkms)`; "pacman -S qemu-desktop" hint         | passthrough plan/enable                                                             | Debian names (backend section); kvmfr as Ryoku DKMS deb                                                                                                                                                                                       |
| Input                              | `pages/InputPage.qml:295-312,961-982`; `ryoku/cli/internal/keyboard/keyboard.go:14-17,195,268-272`                                                                                                                                                                            | mkinitcpio, `/etc/vconsole.conf`, `/boot/initramfs-*.img`, `/boot/EFI/Linux/*.efi`                                              | "Login screen, TTY, and boot" layout apply                                          | `/etc/default/keyboard` (+ `setupcon`), `update-initramfs -u -k all`, initrd glob `/boot/initrd.img-*`                                                                                                                                        |
| Lockscreen                         | `pages/LockscreenPage.qml:124-160,929-967,1313-1381`                                                                                                                                                                                                                          | AUR `pam_fprintd_grosshack.so` at `/usr/lib/security`; edits `/etc/pam.d/{sudo,sddm,polkit-1}`                                  | fingerprint for sudo/SDDM/polkit                                                    | multiarch module dir; build grosshack or use stock pam_fprintd through `pam-auth-update` (`/usr/share/pam-configs/fprintd` from libpam-fprintd); polkit PAM is `/usr/lib/pam.d/polkit-1`                                                      |
| Lockscreen                         | `pages/LockscreenPage.qml:1823`                                                                                                                                                                                                                                               | package name `pam-u2f`                                                                                                          | "Install pam-u2f"                                                                   | `libpam-u2f pamu2fcfg`                                                                                                                                                                                                                        |
| Credits                            | `pages/CreditsPage.qml:37-38`                                                                                                                                                                                                                                                 | "opinionated Arch", "performance Arch"                                                                                          | credits text                                                                        | reword (cosmetic)                                                                                                                                                                                                                             |
| Recording                          | `pages/RecordingPage.qml:402`                                                                                                                                                                                                                                                 | `ryoku doctor` (runs `pacman -Sy`, multilib reconciler: `ryoku/cli/internal/doctor/doctor.go:1091`, `reconcile_multilib.go:56`) | "repair screen sharing"                                                             | Debian doctor reconcilers                                                                                                                                                                                                                     |
| General / Connections              | `pages/GlobalPage.qml:85-91`; `pages/ConnectionsPage.qml:67-104,512-518,819`                                                                                                                                                                                                  | polkit `wheel`                                                                                                                  | password-free pkexec                                                                | rules keyed on `sudo` (or both)                                                                                                                                                                                                               |
| Rashin                             | `pages/RashinPage.qml:584`                                                                                                                                                                                                                                                    | package name                                                                                                                    | "install ryoku-rashin"                                                              | unchanged if the .deb keeps the name                                                                                                                                                                                                          |

Not present in the Hub: reflector/rate-mirrors/mirrorlist, archlinux-keyring,
pacman.conf, os-release checks, chaotic-aur, scx schedulers, kernel pickers
(CachyOS kernels are reachable only through RyoStore bundles,
`docs/kernels.md:3`); `ryoku-sysinfo` reads only `PRETTY_NAME`
(`ryoku/shell/scripts/ryoku-sysinfo:58`). SessionPage edits only
`desktop.autostart`/`desktop.env` (`pages/SessionPage.qml:8-16,33-85`); no
autologin/greeter handling in the Hub. Every Arch-specific English string above
is an i18n key present in 35 catalogs; rewording requires `sync.py extract` +
`sync`.

**Dependencies:**

| Arch pkg                               | Used for (cite)                                                                                                                                   | Debian/Ubuntu pkg                                                                                                     | trixie          | trixie-bpo           | forky          | sid            | resolute               | Min version Ryoku needs (why, cite)                              |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------------- | -------------------- | -------------- | -------------- | ---------------------- | ---------------------------------------------------------------- |
| quickshell                             | `qs -c hub`; `Quickshell`, `.Io`, `.Wayland`, `.Networking` (`pages/ConnectionsPage.qml:7`), `.Bluetooth` (`:8`), `.WindowManager` (via Ryoku.Ui) | quickshell (ships `/usr/bin/qs` and those modules under `/usr/lib/x86_64-linux-gnu/qt6/qml/Quickshell/`)              | -               | 0.3.0-1~bpo13+1      | 0.3.2-1        | 0.3.2-1        | -                      | 0.3.0 (WindowManager, Networking)                                |
| qt6-declarative                        | QtQuick, .Controls, .Shapes, .Window, .Layouts, Qt.labs.folderlistmodel, QtQuick.Effects (`findings/hub-qml-pages.md` §1)                         | qml6-module-qtquick, -controls, -templates, -shapes, -window, -layouts, -effects, qml6-module-qt-labs-folderlistmodel | 6.8.2+dfsg-7    | -                    | 6.11.2+dfsg-3  | 6.11.2+dfsg-3  | 6.10.2+dfsg-3          | none found by grep (no qmllint against 6.8 run)                  |
| qt6-wayland, qt6-svg, qt6-imageformats | Wayland QPA, SVG icons, WebP previews (`pages/LockscreenPage.qml:2123`, `PKGBUILD:44-49`)                                                         | qt6-wayland, qt6-svg-plugins, qt6-image-formats-plugins                                                               | 6.8.2           | -                    | 6.11.2         | 6.11.2         | 6.10.2                 | none                                                             |
| networkmanager                         | `nmcli` (`ConnectionsPage.qml:507-1943`)                                                                                                          | network-manager                                                                                                       | 1.52.1          | -                    | 1.58.1         | 1.58.1         | 1.54.3                 | none                                                             |
| bluez-utils                            | `bluetoothctl` (`ConnectionsPage.qml:1430-1431`)                                                                                                  | bluez                                                                                                                 | 5.82            | -                    | 5.87           | 5.87           | 5.85                   | none                                                             |
| util-linux                             | `rfkill` (`ConnectionsPage.qml:1496`), `flock` (`control.go:179`)                                                                                 | rfkill, util-linux                                                                                                    | 2.41.5          | -                    | 2.42.4         | 2.42.4         | 2.41.3                 | none                                                             |
| systemd                                | `systemctl`, `timedatectl`, `busctl` (`GlobalPage.qml:61,78,83`)                                                                                  | systemd                                                                                                               | 257.13          | -                    | 262            | 262.1          | 259.9                  | none                                                             |
| polkit                                 | `pkexec` (`ConnectionsPage.qml:69,95,517,1504`; `LockscreenPage.qml:159`)                                                                         | pkexec, polkitd                                                                                                       | 126-2           | -                    | 127-3          | 128-1          | 127-2ubuntu1.1         | none                                                             |
| fprintd                                | `fprintd-list/-enroll/-verify/-delete` (`LockscreenPage.qml:451-467,775`)                                                                         | fprintd                                                                                                               | 1.94.5-2        | -                    | 1.94.5-4+b2    | 1.94.5-4+b2    | 1.94.5-4               | none                                                             |
| xdg-utils                              | `xdg-open` (`Hub.qml:595`)                                                                                                                        | xdg-utils                                                                                                             | 1.2.1           | -                    | 1.2.1          | 1.2.1          | 1.2.1                  | none                                                             |
| kitty                                  | terminal for 11 of 12 terminal launches (e.g. `UpdatesPage.qml:228`; only `LockscreenPage.qml:326` honours `$TERMINAL`)                           | kitty                                                                                                                 | 0.41.1          | -                    | 0.48.2         | 0.48.2         | 0.45.0                 | see apps subsystem                                               |
| neovim                                 | `nvim` (`FastfetchPage.qml:484,487`)                                                                                                              | neovim                                                                                                                | 0.10.4          | -                    | 0.12.4         | 0.12.4         | 0.11.6                 | see apps subsystem                                               |
| fontconfig                             | `fc-list` (`GlobalPage.qml:48`)                                                                                                                   | fontconfig                                                                                                            | 2.15.0          | -                    | 2.17.1         | 2.17.1         | 2.17.1                 | none                                                             |
| curl                                   | open-meteo geocoding (`SettingsSheet.qml:998`)                                                                                                    | curl                                                                                                                  | 8.14.1          | 8.21.0               | 8.22.0         | 8.23.0         | 8.18.0                 | none                                                             |
| wl-clipboard                           | `wl-copy` (`RashinPage.qml:218`)                                                                                                                  | wl-clipboard                                                                                                          | 2.2.1           | 2.3.0                | 2.3.0          | 2.3.0          | 2.2.1                  | none                                                             |
| lm_sensors                             | `sensors` (`Singletons/LiveStats.qml:59`)                                                                                                         | lm-sensors                                                                                                            | 3.6.2           | -                    | 3.6.2          | 3.6.2          | 3.6.2                  | none                                                             |
| nvidia-utils                           | `nvidia-smi` (`LiveStats.qml:69`, `GpuPage.qml:403`)                                                                                              | nvidia-smi (non-free) / nvidia-utils-580                                                                              | 550.163.01-2    | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | 580.178.04             | none                                                             |
| tzdata                                 | `/usr/share/zoneinfo/zone1970.tab` (`TimezoneMap.qml:79`)                                                                                         | tzdata                                                                                                                | 2026c-0+deb13u1 | -                    | 2026e-1        | 2026e-1        | 2026e-0ubuntu0.26.04.1 | none                                                             |
| nodejs (CI)                            | 7 `*.test.mjs` run as `node <file>` (`tests/shell-unit-tests.sh`), Node 20 in CI                                                                  | nodejs                                                                                                                | 20.19.2         | -                    | 24.21.0        | 24.22.0        | 22.22.1                | 20 (`node:test`, `node:assert/strict`, `node:vm`, `node:module`) |

Fonts: bundled `fonts/archivo-black.ttf` (`RashinPage.qml:50`); the rest via
Ryoku.Ui Tokens (Ryoku.Ui section).

**As-is on Debian:** PARTIAL: renders once Ryoku.Ui/FrameBars are on the Debian
QML path and Quickshell >= 0.3.0 is present; every page in the table above shows
Arch text or calls Arch-only backends.

**Port steps:**

1. Install path fixes (Ryoku.Ui section). Hub files themselves stay at
   `/usr/share/ryoku/config/quickshell/hub`.
2. Rewrite the UI strings in the table, regenerate `catalog/en.json`
   (`python3 ryoku/i18n/tools/sync.py extract`) and the 35 translations
   (`sync`).
3. Backend replacements: Updates via `ryoku status` (update-delivery subsystem),
   Profile counts in `ryoku-sysinfo`/`ryoku-profile-stats` (`dpkg-query`,
   `apt-mark showmanual`), install date fallback, Dictation install (`apt`),
   Plugins gate (`build-essential`), Add-ons (`ryostore-install` on apt),
   compositor switch (`apt`), Input (`/etc/default/keyboard`,
   `update-initramfs`), Lockscreen PAM paths (greeter section).
4. polkit rules: change `subject.isInGroup("wheel")` to
   `subject.isInGroup("sudo")` (Debian/Ubuntu admin group) in every
   `system/**/*.rules` the Hub depends on; Debian's polkitd 126 reads JavaScript
   rules from `/etc/polkit-1/rules.d` and `/usr/share/polkit-1/rules.d`.
5. Depend on `pkexec` explicitly (separate binary package on Debian).
6. Drop `pages/LightingTab.qml` from the port or wire it into `Hub.qml:490-495`;
   it is dead at this commit.

**Complexity:** Medium: no QML engine issue, but about 15 Arch-specific UI
paths, each needing a Debian backend and a re-translated string.

**Issues / risks:**

- Quickshell is built against Debian's Qt (6.8.2 on trixie-bpo); the Hub was
  only ever run on Arch's newer Qt. No Qt > 6.8 API was found by grep, but no
  qmllint pass against Qt 6.8 was run.
- Unpackaged tools the Hub reaches: voxtype, gpk (GlazePKG,
  `release/packages/gpk`), limine, grub-btrfs, pam-fprint-grosshack, kvmfr DKMS,
  matugen; looking-glass-client is sid-only; gpu-screen-recorder (via
  `ryoku-cmd-screenrecord`, `RecordingPage.qml:409`) is forky/sid-only (5.13.8).

### Rashin daemon, dashboard and Hermes bridge (`ryoku/rashin/backend/`, `ryoku/rashin/systemd/`, `ryoku/rashin/skills/`)

**What it does:** Go daemon `ryoku-rashin` (also `rashin` via an argv0 symlink,
`release/packages/ryoku-rashin/PKGBUILD:48`): keeps a markdown knowledge vault
at `$XDG_DATA_HOME/ryoku/rashin` (override `RYOKU_RASHIN_VAULT`,
`ryoku/rashin/backend/paths.go:17-26`), serves an embedded web dashboard
(`//go:embed web`, `server.go:25-26,89-93`; no JS build step, no third-party JS,
one OFL font `web/fonts/archivo-black.woff2`) on `127.0.0.1:3600`
(`server.go:204-206`; `config.go:41-45`), and bridges ACP agents (Hermes by
default) over newline-delimited JSON-RPC 2.0 on the child's stdio
(`acp.go:18-20,279-301,539-540,676-701`). Agent argv choices: `<hermes> acp`,
`omp acp`, `opencode acp`, `claude-code-acp`, `gemini --experimental-acp`
(`chatbackend.go:26-41`). The prowl MCP server is passed as
`sh -c "cd <repo> && exec <prowl> serve --mcp-surface core"`
(`prowl.go:89-102`). Routes: GET/POST `/api/*` and WebSockets `/ws/vitals`,
`/ws/chat` (`server.go:93-201`); WebSocket upgrades check Origin
(`server.go:255-272`), plain POSTs have no Origin/Host/CSRF check
(`termserve.go:480-503`). Config `~/.config/ryoku/rashin.json`
(`paths.go:29-35`); runtime `$XDG_RUNTIME_DIR/ryoku-rashin/` (`paths.go:38-44`);
state `~/.local/state/ryoku/rashin-*` (`hermes.go:130-140`,
`recipes.go:25-38,135,178`, `askhistory.go:30`, `repo.go:27`); shipped
`/usr/share/ryoku/rashin/ryoku-repo.md` (`repo.go:26`, generated at build by
`ryoku-rashin repo-index`, `PKGBUILD:41`) and skills
`/usr/share/ryoku/skills/ryoku/` (`PKGBUILD:53-56`, `agents.go:273`).

- systemd user unit (`ryoku/rashin/systemd/ryoku-rashin.service`):
  `StartLimitIntervalSec=0` (`:6`),
  `ExecStart=/usr/bin/ryoku-rashin serve --if-enabled` (`:9`),
  `Restart=on-failure` (`:10`), `RestartSec=2` (`:11`), `NoNewPrivileges=yes`
  (`:12`), `WantedBy=default.target` (`:15`); installed to
  `/usr/lib/systemd/user` (`PKGBUILD:60-61`). `ryoku-rashin enable [--at-boot]`
  runs `systemctl --user enable --now` (+ `loginctl enable-linger $USER`)
  (`server.go:313-339`), without systemd a setsid `serve`
  (`server.go:306-311,343-357`); `disable` = `systemctl --user disable --now`
  (`server.go:362-375`); `ensure` is default-on and is called by the doctor
  (`server.go:379-389`;
  `ryoku/cli/internal/doctor/reconcile_rashin_daemon.go:109,162`).
- Hermes one-click setup (`setup.go`): preflight `curl`, `uv` or `python3`, TCP
  reachability of
  `hermes-agent.nousresearch.com:443`/`github.com:443`/`pypi.org:443`, >= 2 GiB
  free (`setup.go:82-97,221-231`); download
  `https://hermes-agent.nousresearch.com/install.sh` to a temp file
  (`setup.go:23,178-185`) and run
  `bash <file> --non-interactive [--skip-browser] [--skip-computer-use]`
  (`setup.go:192,202-209`); then interactive `hermes setup`
  (`setup.go:114-123`), vault/wiring (`setup.go:127-140`), enable,
  `hermes acp --check` (`setup.go:150-163`). Hermes is found on PATH,
  `~/.hermes/bin/hermes` or `~/.local/bin/hermes` (`hermes.go:36-49`). Upstream:
  `https://github.com/NousResearch/hermes-agent`, latest release v0.22.2
  (2026-10-15). The upstream installer (read, not run) installs into `~/.hermes`
  (checkout `~/.hermes/hermes-agent`), always downloads its own pinned uv 0.12.3
  ("never a uv already on PATH"), uses or downloads Python 3.14 (`pyproject`
  `>=3.11,<3.15`), installs Node 26.7.0, ripgrep, ffmpeg, gh into the
  `~/.hermes` store first on PATH, and appends a `~/.local/bin` PATH line to
  shell rc files; its only distro-package helper (`pm/libatomic.py`) runs
  `sudo -n apt-get install -y libatomic1` on Debian/Ubuntu
  (dnf/zypper/`pacman -S gcc-libs`/apk elsewhere), chosen from
  `/etc/os-release`.

**Arch couplings:**

- Package data: `pacman -Qi/-Qq/-Qqe/-Q` and `checkupdates`
  (`quicktools.go:106-112`; `index.go:237,259-268,438-455,534-544`); index table
  row "pacman + yay database" (`index.go:158`). On Debian these degrade to
  "(pacman unavailable)" (`index.go:441`).
- Preflight error text "sudo pacman -S curl" / "sudo pacman -S uv"
  (`setup.go:83,86`).
- Risk tiers know `pacman/yay/paru/mkinitcpio/grub-mkconfig`
  (`danger.go:96-101,211-220`); `apt`, `apt-get`, `dpkg`, `update-initramfs`,
  `update-grub` fall into the default "write" tier (`danger.go:254-256`; with
  `sudo` floored at system, `danger.go:93`).
- Agent prompts and the skill say "Arch Linux" and pacman/yay: `agents.go:24`,
  `vault.go:45`, `quick.go:30`, `manifest.go:139`, `quicktools.go:45`,
  `ws.go:92`, `termserve.go:24`, `skills/ryoku/SKILL.md:4,16,159`; terminal
  prompt prefers `fd`/`bat` (`termserve.go:30`), which are `fdfind`/`batcat` on
  Debian; `habits.go:140-151,166-168` probe `fd`, `bat` and treat `pacman`/`yay`
  as subcommand tools.
- prowl repo candidates `~/Work/ryoku-arch`, `~/ryoku-arch` (`prowl.go:70-71`).
- `sqlite3` comment "base install on Arch" (`introspect.go:512`); Debian ships
  the CLI as the separate `sqlite3` package.
- No os-release, libalpm, `/var/lib/pacman` or `/var/cache/pacman` reads.

**Dependencies:**

| Arch pkg                                          | Used for (cite)                                                                                            | Debian/Ubuntu pkg                                 | trixie                         | trixie-bpo           | forky                         | sid            | resolute                       | Min version Ryoku needs (why, cite)                                                                                 |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------ | -------------------- | ----------------------------- | -------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| go (build)                                        | `PKGBUILD:38`                                                                                              | golang-1.26-go                                    | -                              | 1.26.9-1~bpo13+1     | 1.26.9-1                      | 1.26.9-1       | 1.26.8                         | `go 1.26` (`ryoku/rashin/backend/go.mod:3`); deps `github.com/coder/websocket v1.8.12` + local `ryoku-wm`, vendored |
| uv                                                | declared for Hermes (`PKGBUILD:29`)                                                                        | uv                                                | -                              | -                    | 0.9.17+ds1-6                  | 0.9.17+ds1-6   | -                              | not used: the Hermes installer always fetches its own uv 0.12.3; preflight passes with python3 (`setup.go:85`)      |
| nodejs                                            | declared for Hermes (`PKGBUILD:29`)                                                                        | nodejs                                            | 20.19.2                        | -                    | 24.21.0                       | 24.22.0        | 22.22.1                        | not used by Hermes (own Node 26.7.0)                                                                                |
| gcc                                               | sdist builds (`PKGBUILD:18-25`)                                                                            | gcc, libc6-dev (or build-essential); libatomic1   | 14.2.0                         | -                    | 16.1.0                        | 16.1.0         | 15.2.0                         | libatomic1 is what Hermes' Node needs (upstream `pm/libatomic.py`)                                                  |
| prowl-agent ([ryoku])                             | code index / MCP (`prowl.go:49-57,115,146`; `agents.go:508,518`; `sourcemirror.go:177-178`)                | not packaged                                      | -                              | -                    | -                             | -              | -                              | see prowl-agent below                                                                                               |
| sqlite (optdepend)                                | `sqlite3 -readonly -json ~/.hermes/state.db` (`introspect.go:519-526`)                                     | sqlite3                                           | 3.46.1                         | -                    | 3.53.4                        | 3.53.4         | 3.46.1                         | none                                                                                                                |
| curl, bash                                        | installer fetch/run (`setup.go:185,192`)                                                                   | curl, bash                                        | 8.14.1 / 5.2.37                | 8.21.0               | 8.22.0 / 5.3                  | 8.23.0 / 5.3   | 8.18.0 / 5.3                   | none                                                                                                                |
| git                                               | repo facts (`repo.go:108`); required by the Hermes installer (not preflighted)                             | git                                               | 1:2.47.3                       | -                    | 1:2.53.0                      | 1:2.55.0       | 1:2.53.0                       | none                                                                                                                |
| python                                            | Hermes bootstrap                                                                                           | python3, python3-venv                             | 3.13.5                         | -                    | 3.14.7                        | 3.14.7         | 3.14.3                         | Hermes wants 3.14 (downloads it on trixie)                                                                          |
| rsync                                             | vault config mirror (`sourcemirror.go:100-111`, Go fallback)                                               | rsync                                             | 3.4.1                          | -                    | 3.5.1                         | 3.5.1          | 3.4.1                          | none                                                                                                                |
| pciutils, iproute2, util-linux, procps, coreutils | `lspci`, `ip`, `lsblk`, `ps`, `uname`, `df` (`quicktools.go:119-130`, `index.go:468,507`, `vitals.go:203`) | pciutils, iproute2, util-linux, procps, coreutils | 3.13.0 / 6.15 / 2.41.5 / 4.0.4 | -                    | 3.15.0 / 7.2 / 2.42.4 / 4.0.7 | same           | 3.14.0 / 6.19 / 2.41.3 / 4.0.4 | none                                                                                                                |
| imagemagick                                       | `magick` downscale (`chatcli.go:66-67`)                                                                    | imagemagick                                       | 7.1.1.43                       | -                    | 7.1.2.31                      | 7.1.2.33       | 7.1.2.18                       | 7 (`magick` binary)                                                                                                 |
| wl-clipboard                                      | `wl-copy` (`termcli.go:546-547`)                                                                           | wl-clipboard                                      | 2.2.1                          | 2.3.0                | 2.3.0                         | 2.3.0          | 2.2.1                          | none                                                                                                                |
| nvidia-utils                                      | `nvidia-smi` vitals (`vitals.go:309`)                                                                      | nvidia-smi (non-free) / nvidia-utils-580          | 550.163.01-2                   | 550.163.01-4~bpo13+1 | 550.163.01-5.1                | 550.163.01-5.1 | 580.178.04                     | optional                                                                                                            |
| systemd, polkit                                   | `systemctl --user`, `loginctl enable-linger` (`server.go:292-331`)                                         | systemd, polkitd                                  | 257.13 / 126                   | -                    | 262 / 127                     | 262.1 / 128    | 259.9 / 127                    | none                                                                                                                |

**As-is on Debian:** PARTIAL: builds with backported Go and serves; the
packages/updates views are pacman-only and every agent is told it runs on Arch.

**Port steps:**

1. Build:
   `GOTOOLCHAIN=local CGO_ENABLED=0 /usr/lib/go-1.26/bin/go build -trimpath -mod=vendor -o ryoku-rashin .`,
   then `./ryoku-rashin repo-index <repo-root> ryoku-repo.md` (needs the full
   tree; git optional, `repo.go:105-117`). Install exactly as `PKGBUILD:46-61`.
2. debhelper: install the user unit with `dh_installsystemduser --no-enable` (dh
   would otherwise create a global `default.target.wants` link that
   `ryoku-rashin disable` cannot remove; `--if-enabled` still gates it).
3. Depends: `libatomic1, git, curl, python3, python3-venv, ca-certificates`;
   Recommends:
   `gcc, libc6-dev, sqlite3, rsync, wl-clipboard, imagemagick, pciutils`; drop
   `uv` and `nodejs` (unused by the current Hermes installer).
4. Package backend: replace `pacman -Qq`/`-Qqe`/`-Qi`/`-Q` with
   `dpkg-query -W -f='${Package}\n'`, `apt-mark showmanual`,
   `apt-cache show`/`dpkg-query -s`, and `checkupdates` with
   `apt list --upgradable` or `apt-get -s full-upgrade` parsing
   (`quicktools.go:106-112`, `index.go:237-268,438-455,534-544`).
5. Prompts: derive the distro name and package tool from `/etc/os-release`
   (`NAME`, `ID`, `ID_LIKE`) instead of the literals listed above; rewrite
   `skills/ryoku/SKILL.md:4,16,159`; teach `termserve.go:30` and
   `habits.go:140-151` `fdfind`/`batcat`.
6. `danger.go:96-101,211-220`: add `apt`, `apt-get`, `aptitude`, `dpkg`,
   `update-initramfs`, `update-grub`, `dpkg-reconfigure` to the system tier,
   `apt list`/`apt-cache`/`dpkg -l`/`dpkg-query` to read-only.
7. `setup.go:83,86`: name `sudo apt install curl` / `python3`; also preflight
   `git` and `libatomic1`.

**Complexity:** Medium: a package-query backend and prompt parameterisation;
Hermes itself stays an upstream per-user install.

**Issues / risks:**

- Docs vs code: docs say Rashin is off by default (`docs/rashin.md:7,14-18,130`;
  `PKGBUILD:5-6` "inert until the user enables it"); code is default-on
  (`config.go:41-45` `Enabled: true`; `ensure`, `server.go:377-389`). Docs claim
  shipping uv/nodejs means no network toolchain bootstrap and "Setup never runs
  with sudo" (`docs/rashin.md:360-366`); upstream Hermes downloads uv, Python
  and Node, and may run `sudo -n apt-get install libatomic1`. Hermes memory is
  in `~/.hermes/memories` (`hermes.go:26-28`), not the vault
  (`docs/rashin.md:42`).
- With `--non-interactive` the Hermes installer never primes sudo, so a Debian
  box without `libatomic1` and without passwordless sudo fails Node
  verification; `libatomic1` must be a Depends.
- The upstream installer changes on its own release cadence; Ryoku only sniffs
  flags (`setup.go:202-209`); the 2 GiB check (`setup.go:94`) predates the
  current Python + Node + browser store size.
- No CSRF/Host protection on POST routes (`server.go:121-185`,
  `termserve.go:480-503`): a web page can POST to `127.0.0.1:3600/api/perm`,
  `/api/ask`, `/api/agents/wire` (all platforms).
- The unit has no `Environment=PATH`; non-Hermes ACP agents in `~/.local/bin` or
  npm global dirs are found only if the user manager's PATH has them
  (`chatbackend.go:52`). `NoNewPrivileges=yes` blocks sudo inside agent tools
  (same on Arch).
- Habit mining reads fish history only (`habits.go:171-174`); Debian users
  default to bash.

**Questions for the human:**

- Hermes delivery: (a) keep the upstream per-user installer (network at setup
  time, `~/.hermes` store outside apt, its own uv/Python/Node; works on every
  suite); (b) package Hermes as a .deb (Python 3.11-3.14 dependency tree from
  `uv.lock`, most not in Debian; large and tracks upstream releases every few
  days).

### `rashin` terminal command and shell weave (`ryoku/apps/{fish/conf.d/rashin.fish,bash/rashin.bash,zsh/rashin.zsh}`)

**What it does:** argv0 `rashin` turns a bare argument into a terminal ask while
keeping `status/enable/disable/ensure/backend/paths/agent/setup/index` as verbs
(`ryoku/rashin/backend/main.go:36-41,94-117`). fish: a `rashin` function runs
`ryoku-rashin term --buffer` and puts the result on the command line
(`rashin.fish:17-25`), Alt+R as `alt-r` (fish 4) and `\er` (fish 3) (`:30-51`),
a `fish_postexec` report hook (`:57-68`), rr-* recipe abbreviations (`:72-75`).
bash: ble.sh `ble-edit/content/reset` or `READLINE_LINE` (`rashin.bash:4-13`),
`bind -x '"\er"'` (`:30`), `PROMPT_COMMAND` postexec (`:32-52`); sourced from
`ryoku.bash:51`. zsh: line-init widget, `bindkey '\er'`, preexec/precmd
(`rashin.zsh:21-56`). No command_not_found handler in any of them. Installed
under `/usr/share/ryoku/config/{fish/conf.d,bash,zsh}`
(`release/packages/ryoku-desktop/PKGBUILD:369-376`).

**Arch couplings:** none in the weaves. Bash recipes are written as
`ble-sabbrev` lines (`ryoku/rashin/backend/recipes.go:109`) and need ble.sh,
which Ryoku packages itself (`release/packages/blesh/PKGBUILD`; sourced from
`/usr/share/blesh/ble.sh`, `ryoku/apps/bash/ryoku.bash:18-19`); `blesh` is
absent from every Debian/Ubuntu suite.

**Dependencies:** fish 4.0.2 (trixie) / 4.2.1 (resolute) handle both bind forms;
bash; zsh; blesh (Ryoku-built .deb).

**As-is on Debian:** YES for fish and zsh; bash recipes need the Ryoku ble.sh
.deb.

**Port steps:** 1. Build `release/packages/blesh` as a .deb installing
`/usr/share/blesh/ble.sh`. 2. Ship the three weave files at the same config
paths.

**Complexity:** Low.

**Issues / risks:** without ble.sh the bash `rashin` function's `READLINE_LINE`
assignment outside a `bind -x` context does not reach the next prompt (inference
from bash semantics, untested).

### prowl-agent (`release/packages/prowl-agent/`, dependency of Rashin)

**What it does:** Go code index + MCP server Rashin's `index`/`wire` drive
(`release/packages/ryoku-rashin/PKGBUILD:26-28`). Packaged from
`https://github.com/neur0map/prowl-agent` at commit
`506e54fb7b049ceea556255205f8acd3ee20ac9e`, pkgver 0.15.6
(`release/packages/prowl-agent/PKGBUILD:19,23,30-31`), built with
`CGO_ENABLED=1`, `GOFLAGS=-mod=mod` (network at build time),
`-tags sqlite_fts5`, `-X main.managedBy=pacman` (`PKGBUILD:36-45`). Upstream
go.mod at that commit: `go 1.26.4`, cgo deps mattn/go-sqlite3, sqlite-vec
bindings, ~30 tree-sitter grammars. Upstream now: tags up to v0.17.2, MIT,
module renamed `github.com/neur0map/prowl`, binary `prowl` only; Rashin already
prefers `prowl` and falls back to `prowl-agent`
(`ryoku/rashin/backend/prowl.go:49-57`).

**Arch couplings:** `-X main.managedBy=pacman` (`PKGBUILD:45`);
`ryoku/cli/internal/updater/update.go:1050-1064` (`prowlPacmanOwned`) assumes
pacman ownership; `docs/rashin.md:312` gives `sudo pacman -S prowl-agent`.

**Dependencies:** build: golang-1.26-go (- / 1.26.9-1~bpo13+1 / 1.26.9-1 /
1.26.9-1 / 1.26.8), gcc, libc6-dev; runtime libc only (SQLite amalgamation
compiled in).

**As-is on Debian:** NO (not packaged).

**Port steps:** 1. `go mod vendor` into the orig tarball (Debian builds
offline). 2.
`CGO_ENABLED=1 GOTOOLCHAIN=local go build -mod=vendor -trimpath -tags sqlite_fts5 -ldflags "-s -w -X main.version=v<ver> -X main.managedBy=dpkg" ./cmd/prowl-agent`
(or `./cmd/prowl` for upstream >= the rename). 3. Install `/usr/bin/prowl-agent`
(+ `prowl` link). 4. Change `prowlPacmanOwned` to a `dpkg -S` check.

**Complexity:** Low.

**Issues / risks:** the pinned commit has no LICENSE file (`PKGBUILD:24`
`license=('custom')`; `prowl.go:15-17` "no license for redistribution yet");
upstream's default branch is MIT now, so moving to a tagged MIT release resolves
redistribution.

### Ryoku.Ui shared QML module (`ryoku/ui/`)

**What it does:** The design system every surface imports (shell, Hub, apps, the
in-session lock): 43 QML components, 4 JS libraries registered as QML singletons
(`ryoku/ui/qmldir:1-48`), and the `Ryoku.Ui.Singletons` module (I18n, Tokens,
Paths, ProfileStore, Spawn, Version, Wm, ...; `ryoku/ui/Singletons/`). Pure
QML + JS + two precompiled shaders
(`ryoku/ui/shaders/{dither,spectrum}.frag.qsb`); no compiled plugin. Packaged by
`release/packages/ryoku-desktop/PKGBUILD:328-337` as a plain copy into
`/usr/lib/qt6/qml/Ryoku/Ui`; the dev deploy copies it to
`~/.local/lib/qt6/qml/Ryoku/Ui` (`ryoku/ui/install.sh:10-15`).

**Arch couplings:**

- Install path `/usr/lib/qt6/qml/Ryoku/Ui`
  (`release/packages/ryoku-desktop/PKGBUILD:331-337`). The PKGBUILD comment
  (`:329-330`) states the reason: "In /usr/lib/qt6/qml so Qt resolves it without
  an import path". Debian's Qt6 `QLibraryInfo::QmlImportsPath` is
  `/usr/lib/x86_64-linux-gnu/qt6/qml` (verified:
  `qml6-module-qt5compat-graphicaleffects_6.8.2` and `sddm_0.21.0` trixie debs
  install their QML modules there; this trixie host has no `/usr/lib/qt6/` at
  all). Installed at the Arch path, `import Ryoku.Ui` fails on Debian and every
  surface that imports it (shell, Hub, lock) fails to load.
- Sibling pure-QML modules with the same hardcode: `Ryoku.PluginKit`
  (`release/packages/ryoku-desktop/PKGBUILD:324-326`), `Ryoku.FrameBars`
  (`:347-349`, comment `:344-345`: "Omitting it loads no shell at all"),
  `Ryoku.Blobs` (`release/packages/ryoku-blobs/PKGBUILD:33-34`),
  `Ryoku.Wm.Hyprland`
  (`release/packages/ryoku-desktop-hyprland/PKGBUILD:87-88`).
- No runtime code hardcodes `/usr/lib/qt6/qml`: the only other hits are the dev
  lint tool (`bin/ryoku-dev-lint-qml:28`, `-I /usr/lib/qt6/qml`), the docs
  (`docs/structure.md:91`, `docs/ui-ux.md:151`, `release/packages/README.md:18`)
  and the qylock symlinks (see the lockscreen section). The dev path
  `~/.local/lib/qt6/qml` reaches Qt through `QML_IMPORT_PATH` set by
  `ryoku/hyprland/modules/env.lua` (`docs/ui-ux.md:151-154`) and
  `ryoku/wm/niri/config_binds.go:49`; that mechanism is distro-neutral.
- Only external command: `ryoku version` (`ryoku/ui/Singletons/Version.qml:53`).
  User data paths are XDG/home-relative (`Singletons/Tokens.qml:332,341,350`,
  `Singletons/ProfileStore.qml:20`, `Singletons/Paths.qml:22-54`,
  `Singletons/Ryodecors.qml:11`). No `/etc`, `/usr` (other than the i18n
  catalog, below) or os-release reads.

**Dependencies:**

| Arch pkg                      | Used for (cite)                                                                                                                         | Debian/Ubuntu pkg                                                                                                                                     | trixie               | trixie-bpo      | forky         | sid           | resolute       | Min version Ryoku needs (why, cite)                                                                                                                                                              |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- | --------------- | ------------- | ------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| quickshell                    | `import Quickshell`, `Quickshell.Io` (13/7 files), `Quickshell.Wayland` + `Quickshell.WindowManager` (`ryoku/ui/Singletons/Wm.qml:6-7`) | quickshell                                                                                                                                            | -                    | 0.3.0-1~bpo13+1 | 0.3.2-1       | 0.3.2-1       | -              | 0.3.0: `Quickshell.WindowManager` (`WindowManager.windowsets`, `Wm.qml:59`) exists from v0.3.0 (`src/windowmanager` absent in v0.2.1, present in v0.3.0, upstream tree). Arch extra ships 0.3.2. |
| qt6-declarative               | `QtQuick` (54 files), `QtQuick.Controls` (4), `Qt.labs.folderlistmodel` (`PickFile.qml:5`)                                              | qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-templates, qml6-module-qt-labs-folderlistmodel, qml6-module-qtqml-workerscript | 6.8.2+dfsg-7         | -               | 6.11.2+dfsg-3 | 6.11.2+dfsg-3 | 6.10.2+dfsg-3  | none stated                                                                                                                                                                                      |
| qt6-declarative               | `QtQuick.Effects` (`DitherImage.qml:2`, `Watermark.qml:2`, `Keycap.qml:4`)                                                              | qml6-module-qtquick-effects                                                                                                                           | 6.8.2+dfsg-7         | -               | 6.11.2+dfsg-3 | 6.11.2+dfsg-3 | 6.10.2+dfsg-3  | none stated                                                                                                                                                                                      |
| qt6-declarative               | `QtQuick.Shapes` (`FingerprintScan.qml:2`)                                                                                              | qml6-module-qtquick-shapes                                                                                                                            | 6.8.2+dfsg-7         | -               | 6.11.2+dfsg-3 | 6.11.2+dfsg-3 | 6.10.2+dfsg-3  | none stated                                                                                                                                                                                      |
| qt6-base (runtime QShader)    | loading committed `.qsb` (`ryoku/ui/shaders/*.qsb`)                                                                                     | libqt6gui6                                                                                                                                            | 6.8.2                | -               | 6.11.2        | 6.11.2        | 6.10.2         | QSB serialization v9: all 44 committed `.qsb` in the repo decode to version 9; trixie qtbase 6.8.2 `QSB_VERSION = 9` (`src/gui/rhi/qshader_p.h:28`), so they load on every suite.                |
| qt6-shadertools (dev only)    | `qsb --qt6 -o <name>.frag.qsb <name>.frag` (`docs/development.md:17-19`)                                                                | qt6-shader-baker (`/usr/lib/qt6/bin/qsb`)                                                                                                             | 6.8.2-3              | -               | 6.11.2-2      | 6.11.2-2      | 6.10.2-1       | dev-time only                                                                                                                                                                                    |
| nodejs (dev/CI only)          | `node <file>.test.mjs` (`tests/shell-unit-tests.sh`, CI `node-version: '20'`, `.github/workflows/shell-unit-tests.yml`)                 | nodejs                                                                                                                                                | 20.19.2              | -               | 24.21.0       | 24.22.0       | 22.22.1        | 20: tests import `node:test`, `node:assert/strict`, `node:module` (`ryoku/ui/lib/*.test.mjs:1-3`)                                                                                                |
| inter-font                    | `Inter`, `Inter Display` families (41 uses across Ui+Hub)                                                                               | fonts-inter (static otf, includes 18 InterDisplay faces)                                                                                              | 4.1+ds-1             | -               | 4.1+ds1-4     | 4.1+ds1-4     | 4.1+ds-1       | none stated                                                                                                                                                                                      |
| otf-space-grotesk ([ryoku])   | `Space Grotesk` default UI face (`Singletons/Tokens.qml:280`)                                                                           | fonts-space-grotesk (Ubuntu only)                                                                                                                     | -                    | -               | -             | -             | 2.0.0-0ubuntu2 | Debian: build `release/packages/otf-space-grotesk` as a .deb                                                                                                                                     |
| (none ships it)               | `SpaceMono Nerd Font` default mono (`Singletons/Tokens.qml:107,279`)                                                                    | -                                                                                                                                                     | -                    | -               | -             | -             | -              | not shipped on Arch either (no PKGBUILD or package-list entry); falls back via fontconfig on both                                                                                                |
| ttf-fraunces-variable (AUR)   | `Fraunces` (5 uses)                                                                                                                     | -                                                                                                                                                     | -                    | -               | -             | -             | -              | build from upstream as .deb (AUR on Arch, `system/packages/aur.packages:52`)                                                                                                                     |
| ttf-jetbrains-mono-nerd       | `JetBrainsMono Nerd Font` (11 uses)                                                                                                     | (Nerd variant absent; fonts-jetbrains-mono is the plain face)                                                                                         | -                    | -               | -             | -             | -              | build Nerd Fonts JetBrainsMono release as .deb                                                                                                                                                   |
| ttf-material-symbols-variable | `Material Symbols Rounded` (4 uses)                                                                                                     | -                                                                                                                                                     | -                    | -               | -             | -             | -              | build from google/material-design-icons variablefont as .deb                                                                                                                                     |
| noto-fonts-cjk                | `Noto Sans CJK JP` (3 uses)                                                                                                             | fonts-noto-cjk                                                                                                                                        | 1:20240730+repack1-1 | -               | same          | same          | ...build1      | none                                                                                                                                                                                             |

**As-is on Debian:** NO: the module itself is distro-neutral, but its packaged
install path is wrong for Debian Qt6.

**Port steps:**

1. In the Debian packaging of the desktop, install the module to the Debian Qt6
   QML dir: `/usr/lib/qt6/qml/Ryoku/Ui` ->
   `/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku/Ui` (derive it at build time:
   `qmldir=$(qtpaths6 --query QT_INSTALL_QML)` from qt6-base-dev-tools, or
   `dpkg-architecture -qDEB_HOST_MULTIARCH`). Same edit for `Ryoku/PluginKit`,
   `Ryoku/FrameBars`, `Ryoku/Blobs`, `Ryoku/Wm/Hyprland` (and any
   `Ryoku/Wm/Niri`).
2. Keep the `rm -f .../install.sh` and `rm -rf .../__pycache__` steps
   (`PKGBUILD:336-337`).
3. `bin/ryoku-dev-lint-qml:28`: `imports=(-I /usr/lib/qt6/qml)` ->
   `imports=(-I "$(qtpaths6 --query QT_INSTALL_QML)")`. `qmllint` path
   `/usr/lib/qt6/bin/qmllint` (`bin/ryoku-dev-lint-qml:20`) already matches
   Debian's `qt6-declarative-dev-tools` (filelist: `/usr/lib/qt6/bin/qmllint`).
4. Depend on the qml6-module-* packages in the table plus quickshell >= 0.3.0
   (trixie needs trixie-backports; resolute needs a source build, see Issues).
5. Fonts: fonts-inter, fonts-noto-cjk from the archive; build .debs for Space
   Grotesk (reuse `release/packages/otf-space-grotesk`), JetBrainsMono Nerd
   Font, Material Symbols Rounded, Fraunces.

**Complexity:** Low: one path variable per module in packaging.

**Issues / risks:**

- Quickshell is absent from trixie main and from Ubuntu resolute;
  trixie-backports has exactly 0.3.0 (minimum for `Quickshell.WindowManager`),
  Arch runs 0.3.2. Any shell code that needs 0.3.1/0.3.2 behaviour breaks on
  trixie-bpo 0.3.0 (the shell subsystem report must confirm the true minimum).
- Without Material Symbols Rounded every icon renders as its ligature text
  (`release/packages/ryoku-desktop/PKGBUILD:164-167`); no Debian package exists.

### i18n (`ryoku/i18n/`, `ryoku/ui/Singletons/I18n.qml`)

**What it does:** One catalog (35 languages in `ryoku/i18n/langs.json`, 6937
English keys in `catalog/en.json`, human `catalog/overrides/*.json`) read by
four runtimes: the QML singleton `Ryoku.Ui.Singletons.I18n`
(`ryoku/ui/Singletons/I18n.qml`), the Go module `ryoku-i18n`
(`ryoku/i18n/i18n.go`, `langs.go`, embedded `catalog/catalog.go`), the installer
shell (`installation/backend/lib/i18n.sh:28`) and the SDDM greeter's own reader
(`ryoku/lockscreen/qylock/themes/clockwork/orbital/i18n/I18n.qml:17`). Authoring
tools: `tools/sync.py` (extract / Google or LLM sync / length check / cost /
per-user `llm` generation / `ensure`), `tools/wrap.py` (QML AST wrapper),
`tools/install.sh` (dev drop to `~/.local/share/ryoku/i18n`,
`tools/install.sh:12-18`).

**Arch couplings:** none in the runtime.

- Catalog path is FHS-neutral: `/usr/share/ryoku/i18n`
  (`release/packages/ryoku-desktop/PKGBUILD:546-548`; Go `SystemDir`,
  `ryoku/i18n/i18n.go:30`; QML search order `RYOKU_I18N_DIR` ->
  `$XDG_DATA_HOME/ryoku/i18n` -> `/usr/share/ryoku/i18n`,
  `ryoku/ui/Singletons/I18n.qml:103-107`; user/AI layer
  `~/.config/ryoku/i18n/<lang>.json`, `I18n.qml:115-117`).
- Language resolution reads `RYOKU_LANG`, `~/.config/ryoku/shell.json`, then
  `LC_ALL`/`LC_MESSAGES`/`LANG` (`ryoku/i18n/i18n.go:94-106`); the greeter
  reader takes `Qt.locale().name` (`orbital/i18n/I18n.qml:51-57`). On Debian the
  greeter's locale comes from `/etc/default/locale` (sddm.service
  `EnvironmentFile=-/etc/default/locale`, verified in the trixie sddm deb), on
  Arch from `/etc/locale.conf`; both feed `LANG`.
- Glyph coverage claim: `docs/i18n.md:144-148` relies on Arch `noto-fonts` +
  `noto-fonts-cjk` as hard depends; Debian equivalents are fonts-noto-core (+
  fonts-noto-extra for some Indic scripts) and fonts-noto-cjk.

**Dependencies:**

| Arch pkg                   | Used for (cite)                                                                                                                                                                                                                       | Debian/Ubuntu pkg                                                                   | trixie                            | trixie-bpo | forky      | sid        | resolute        | Min version Ryoku needs (why, cite)                                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------- | ---------- | ---------- | ---------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| python                     | `/usr/bin/ryoku-i18n` = `tools/sync.py` (`PKGBUILD:554`), shebang `#!/usr/bin/env python3` (`sync.py:1`); stdlib only: concurrent.futures, json, os, random, re, sys, threading, time, urllib.parse, urllib.request (`sync.py:50-59`) | python3                                                                             | 3.13.5-1                          | -          | 3.14.7-3   | 3.14.7-3   | 3.14.3-0ubuntu2 | 3.9 (both tools parse with `ast.parse(..., feature_version=(3,9))`)                                                                      |
| (pip, dev only)            | `wrap.py` imports `tree_sitter` and `tree_sitter_qmljs` (`wrap.py:24-25`); docs run it from `/tmp/venv` (`docs/i18n.md:183-187`)                                                                                                      | python3-py-tree-sitter (experimental only, 0.25.1); tree-sitter-qmljs: not packaged | -                                 | -          | -          | -          | -               | dev-time only; not run by hooks or CI (only `sync.py` runs in `.github/workflows/i18n.yml:69-81` and `bin/ryoku-dev-verify-delivery:71`) |
| go (build)                 | Go runtime module, `go 1.23`, no requires (`ryoku/i18n/go.mod`)                                                                                                                                                                       | golang-go                                                                           | 1.24                              | -          | -          | -          | -               | 1.23                                                                                                                                     |
| noto-fonts, noto-fonts-cjk | glyph coverage (`docs/i18n.md:144-148`)                                                                                                                                                                                               | fonts-noto-core, fonts-noto-cjk                                                     | 20201225-2 / 1:20240730+repack1-1 | -          | 20201225-6 | 20201225-6 | ...-2build1     | none                                                                                                                                     |

Network endpoints of `sync.py` (runtime `ryoku-i18n llm`, Hub "Generate with AI"
via `ryoku/hub/quickshell/SettingsSheet.qml:480-481`):
`https://translate.googleapis.com/translate_a/single` (`sync.py:336,374`),
OpenRouter `https://openrouter.ai/api/v1/chat/completions` default
(`sync.py:556`), `https://api.anthropic.com/v1/messages` (`sync.py:597`),
`https://api.openai.com/v1/chat/completions` (`sync.py:603`); config
`~/.config/ryoku/i18n-llm.json` or `RYOKU_I18N_PROVIDER/_KEY/_MODEL/_URL`
(`sync.py:35-37,541-566`).

**As-is on Debian:** YES for the catalog and the QML/Go/shell runtimes; the
installed `ryoku-i18n` is broken on both distros (Issues).

**Port steps:**

1. Ship `catalog/*.json` + `langs.json` to `/usr/share/ryoku/i18n` unchanged.
2. Ship `tools/sync.py` as `/usr/bin/ryoku-i18n` with the path fix below;
   Depends: python3 (stdlib only).
3. Fix the packaged path resolution: `sync.py:64-69` derives
   `I18N = <dir of script>/..`, so installed at `/usr/bin/ryoku-i18n` it opens
   `/usr/langs.json` at import (`sync.py:69,74-77`). Change
   `I18N = os.environ.get("RYOKU_I18N_DIR") or (<repo dir> if it holds langs.json else "/usr/share/ryoku/i18n")`,
   and `TRANS` to the same dir when not in a checkout.
4. Dev only:
   `python3 -m venv /tmp/venv && /tmp/venv/bin/pip install tree-sitter tree-sitter-qmljs`
   to run `wrap.py` (no Debian packages for tree-sitter-qmljs;
   python3-py-tree-sitter is experimental-only).

**Complexity:** Low.

**Issues / risks:**

- Pre-existing bug, not Debian-specific: `/usr/bin/ryoku-i18n` cannot start on a
  packaged system. `HERE=/usr/bin` -> `I18N=/usr` ->
  `LANGS_FILE=/usr/langs.json` (`sync.py:64-69`), read at module import
  (`sync.py:74-77`), so every subcommand dies with FileNotFoundError. The
  autostart call hides it
  (`command -v ryoku-i18n >/dev/null 2>&1 && ryoku-i18n ensure >/dev/null 2>&1`,
  `ryoku/hyprland/modules/autostart.lua:79`, `ryoku/niri/autostart.kdl:68`); the
  Hub button runs it in kitty (`SettingsSheet.qml:480-481`). Reproduced by
  evaluating the same `os.path` expressions with `HERE=/usr/bin`.
- `sync.py` sends an `HTTP-Referer: https://github.com/noctalia-dev` header to
  OpenRouter (`sync.py:607`), unrelated to Ryoku.

### qylock in-session lock (`ryoku/lockscreen/qylock/quickshell-lockscreen/`, `ryoku/lockscreen/ryoku-qylock-*`, `ryoku/lockscreen/install-qylock`)

**What it does:** Vendored, trimmed qylock (upstream
`https://github.com/Darkkal44/qylock` at
`cde4d11e9e3d385620becdc877a0521e40a55e47`,
`ryoku/lockscreen/qylock/README.ryoku.md:3-4`; upstream HEAD is now `f6561e2`,
2026-09-14). Run path: Super+L or the idle daemon run `ryoku-shell lock`
(`ryoku/hyprland/modules/binds.lua:60`;
`system/hardware/power/ryoku-idle:197,207-208`) ->
`exec.LookPath("ryoku-qylock-lock")` (`ryoku/shell/ipc/actions.go:380`) ->
`/usr/bin/ryoku-qylock-lock` (flock admission,
`ryoku/lockscreen/ryoku-qylock-lock:15-19`; execs
`~/.local/share/quickshell-lockscreen/lock.sh`, `:5,38`) -> `lock.sh` prepends
the vendored import shims to `QML2_IMPORT_PATH` (`lock.sh:46`), refuses
non-Wayland sessions and sessions without `XDG_SESSION_ID`
(`lock.sh:13-17,63-72`), kills `hyprlock swaylock wlogout` (`lock.sh:123`) and
runs `quickshell -p lock_shell.qml` in a retry loop (`lock.sh:131-160`).
`lock_shell.qml` covers every output with Quickshell
`WlSessionLock`/`WlSessionLockSurface` (ext-session-lock-v1;
`lock_shell.qml:315,340`) and loads the chosen qylock skin
(`~/.config/qylock/theme`, default `clockwork/orbital`, `lock.sh:77-110`).
Authentication is two parallel Quickshell `PamContext`s with
`configDirectory: Quickshell.shellDir + "/assets/pam"`
(`shim/SddmShim.qml:424-464`), so no `/etc/pam.d` file is read or written for
the lock:

- `assets/pam/ryoku-lock` (fingerprint):
  `auth sufficient pam_fprintd.so timeout=-1`, `auth required pam_deny.so`,
  `account required pam_unix.so`, `password required pam_deny.so`,
  `session required pam_unix.so` (`assets/pam/ryoku-lock:27-31`).
- `assets/pam/ryoku-lock-pw` (password): `auth required pam_unix.so nullok`,
  `account required pam_unix.so`, `password required pam_deny.so`,
  `session required pam_unix.so` (`assets/pam/ryoku-lock-pw:17-20`). Unlock:
  `unlock.sh` -> `ryoku-qylock-unlock-prepare` (sleep-inhibitor handover via
  `systemctl --user`, `systemd-run`, `systemd-inhibit`, `busctl`, `jq`;
  `ryoku-qylock-unlock-prepare:13-69`) -> `loginctl unlock-session`
  (`unlock.sh:11-14`). `install-qylock` lays the bundle per user:
  `~/.local/share/quickshell-lockscreen` (live) or
  `~/.local/share/ryoku/qylock-next` (staged for `ryoku-qylock-activate`, the
  `ExecStartPre` of `ryoku-shell.service`,
  `ryoku/shell/systemd/user/ryoku-shell.service:30`), themes in
  `~/.local/share/qylock/themes`, preference `~/.config/qylock/theme`
  (`install-qylock:156-158,372-419`). Callers: the ISO installer via
  `arch-chroot` (`installation/backend/lib/deploy.sh:313-326`),
  `ryoku-qylock-activate` (`ryoku-qylock-activate:30-31`), `ryoku-power-cutover`
  (`system/hardware/power/ryoku-power-cutover:19-23`), and the doctor
  (`ryoku/cli/internal/doctor/reconcile_lockscreen.go`).

**Arch couplings:**

- `imports/QtGraphicalEffects/` (the Qt5-name shim for skins that
  `import QtGraphicalEffects`) is 18 absolute symlinks into
  `/usr/lib/qt6/qml/Qt5Compat/GraphicalEffects/` (e.g. `Glow.qml`, `Blend.qml`,
  `private`, `qtgraphicaleffectsplugin.qmltypes`;
  `find -type l -lname '/usr/lib/qt6/*'` = 18 of 18). Debian installs that
  module at `/usr/lib/x86_64-linux-gnu/qt6/qml/Qt5Compat/GraphicalEffects/`
  (trixie `qml6-module-qt5compat-graphicaleffects` file list) and names the type
  file `plugins.qmltypes`, so all 18 links dangle; the other 9 shim files are
  wrappers (`import Qt5Compat.GraphicalEffects as T` / `T.FastBlur {}`,
  `imports/QtGraphicalEffects/FastBlur.qml:1-2`) and work. The core
  `clockwork/orbital` skin imports `Qt5Compat.GraphicalEffects` directly
  (`themes/clockwork/orbital/Main.qml:3`), so it is unaffected; skins using the
  Qt5 name lose Glow, Blend, Displace, InnerShadow, RadialBlur, Desaturate,
  ZoomBlur, ThresholdMask, ColorOverlay, GammaAdjust, RecursiveBlur,
  DirectionalBlur, MaskedBlur, HueSaturation, RectangularGlow, LevelAdjust.
- `installation/tests/iso-stage-check.sh:85` and `installation/CHANGELOG.md:199`
  show the ISO payload deliberately bakes these symlinks.
- The lock requires Ryoku.Ui on the default QML path
  (`import Ryoku.Ui.Singletons`, `lock_shell.qml:21`; see the Ryoku.Ui section).
- No package manager, os-release, AUR or network calls anywhere in
  `install-qylock` (offline by design, `install-qylock:11`); privilege via
  `sudo -n` or pkexec-provided `PKEXEC_UID` (`install-qylock:88-106`).
- Commands used (all present on Debian): `loginctl`, `dbus-monitor --system`
  (`shim/SddmShim.qml:90-100`), `fprintd-list` (`SddmShim.qml:381`),
  `pkill -x fprintd-verify` (`SddmShim.qml:125`), `cat /etc/hostname`
  (`SddmShim.qml:343`), session list from `/usr/share/wayland-sessions` and
  `/usr/share/xsessions` (`SddmShim.qml:226-232`), `flock`, `sha256sum`,
  `getent`, `pgrep`, `killall` (`lock.sh:123`, guarded by `|| true`).

**Dependencies:**

| Arch pkg                                     | Used for (cite)                                                                                                                                           | Debian/Ubuntu pkg                                                             | trixie                  | trixie-bpo      | forky                 | sid           | resolute                         | Min version Ryoku needs (why, cite)                                                                                                                            |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------- | --------------- | --------------------- | ------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| quickshell                                   | `quickshell -p` (`lock.sh:139`), `Quickshell.Wayland` WlSessionLock, `Quickshell.Services.Pam` PamContext + `configDirectory` (`SddmShim.qml:25,424-464`) | quickshell                                                                    | -                       | 0.3.0-1~bpo13+1 | 0.3.2-1               | 0.3.2-1       | -                                | 0.3.0 (via Ryoku.Ui, see above); Quickshell must be built with PAM and Wayland session-lock support (Debian's build: verify `Quickshell.Services.Pam` present) |
| qt6-multimedia, qt6-multimedia-ffmpeg        | `import QtMultimedia` (`lock_shell.qml:18`), video skins (`install-qylock:20-23`)                                                                         | qml6-module-qtmultimedia, libqt6multimedia6 (ships `libffmpegmediaplugin.so`) | 6.8.2-8                 | -               | 6.11.2-3              | 6.11.2-3      | 6.10.2-2                         | none stated                                                                                                                                                    |
| qt6-5compat                                  | `Qt5Compat.GraphicalEffects` (orbital `Main.qml:3`)                                                                                                       | qml6-module-qt5compat-graphicaleffects                                        | 6.8.2-3+b1              | -               | 6.11.2-2              | 6.11.2-2      | 6.10.2-1                         | none                                                                                                                                                           |
| qt6-declarative                              | `Qt.labs.folderlistmodel`, `QtQuick.Window` (orbital `Main.qml:2,4`)                                                                                      | qml6-module-qt-labs-folderlistmodel, qml6-module-qtquick-window               | 6.8.2+dfsg-7            | -               | 6.11.2+dfsg-3         | 6.11.2+dfsg-3 | 6.10.2+dfsg-3                    | none                                                                                                                                                           |
| pam (pam_unix, pam_deny)                     | lock PAM services (`assets/pam/*`)                                                                                                                        | libpam-modules                                                                | 1.7.0-5                 | -               | 1.7.0-8               | 1.7.0-8       | 1.7.0-5ubuntu3.2                 | none                                                                                                                                                           |
| fprintd (pulled by AUR pam-fprint-grosshack) | `pam_fprintd.so timeout=-1`, `fprintd-list`                                                                                                               | fprintd, libpam-fprintd                                                       | 1.94.5-2                | -               | 1.94.5-4+b2           | 1.94.5-4+b2   | 1.94.5-4                         | Arch ships the same 1.94.5                                                                                                                                     |
| dbus                                         | `dbus-monitor` (`SddmShim.qml:99`)                                                                                                                        | dbus-bin                                                                      | 1.16.2-2                | -               | 1.16.2-8              | 1.16.2-8      | 1.16.2-2ubuntu4                  | none                                                                                                                                                           |
| procps / psmisc                              | `pgrep`, `pkill` / `killall`                                                                                                                              | procps / psmisc                                                               | 2:4.0.4-9 / 23.7-2      | -               | 2:4.0.7-1 / 23.7-2+b1 | same          | 2:4.0.4-9ubuntu1 / 23.7-2ubuntu2 | none                                                                                                                                                           |
| jq, systemd, util-linux                      | unlock-prepare (`ryoku-qylock-unlock-prepare:13`), flock                                                                                                  | jq, systemd, util-linux                                                       | 1.7.1 / 257.13 / 2.41.5 | -               | 1.8.2 / 262           | 1.8.2 / 262.1 | 1.8.1 / 259.9                    | none                                                                                                                                                           |

**As-is on Debian:** PARTIAL: the core skin locks and unlocks once Ryoku.Ui is
on the Debian QML path; the Qt5-name shim dangles.

**Port steps:**

1. Replace the 18 symlinks in
   `ryoku/lockscreen/qylock/quickshell-lockscreen/imports/QtGraphicalEffects/`
   with wrapper files, distro-neutral: for each `<Name>.qml`, write
   `import Qt5Compat.GraphicalEffects as T` + `T.<Name> {}` (the pattern of
   `FastBlur.qml:1-2`); delete the `private` and
   `qtgraphicaleffectsplugin.qmltypes` links (the wrappers resolve privates
   through Qt5Compat itself). Alternative that keeps links: generate them at
   package build time against
   `$(qtpaths6 --query QT_INSTALL_QML)/Qt5Compat/GraphicalEffects`.
2. Install the bundle to `/usr/share/ryoku/lockscreen/qylock` and the helpers to
   `/usr/bin` exactly as `release/packages/ryoku-desktop/PKGBUILD:446-456`.
3. Depends: quickshell (>= 0.3.0), qml6-module-qtmultimedia, libqt6multimedia6,
   qml6-module-qt5compat-graphicaleffects, qml6-module-qt-labs-folderlistmodel,
   qml6-module-qtquick-window, libpam-modules, fprintd, libpam-fprintd,
   dbus-bin, procps, psmisc, jq.
4. Replace `arch-chroot /mnt env $env /root/ryoku-install-qylock`
   (`installation/backend/lib/deploy.sh:323-325`) with `chroot` /
   `systemd-nspawn` (installer subsystem).

**Complexity:** Low.

**Issues / risks:**

- Code and comments disagree on the fingerprint module:
  `ryoku/cli/internal/doctor/reconcile_fingerprint.go:14-20` and
  `system/packages/aur.packages:62-70` say the lock's PAM stack loads
  `pam_fprintd_grosshack.so`; the shipped stack uses stock
  `pam_fprintd.so timeout=-1` (`assets/pam/ryoku-lock:27`,
  `README.ryoku.md:27-31`). Grosshack is used only by the Hub's
  `/etc/pam.d/{sudo,sddm,polkit-1}` toggles (greeter section).
- `lock.sh:69-72` hard-refuses non-Wayland; `XDG_SESSION_ID` must be set, i.e.
  the session must be a logind session started through PAM (`pam_systemd`, part
  of Debian's `common-session` via libpam-systemd). A compositor started from a
  TTY without libpam-systemd has no session id and the lock never starts.

### SDDM greeter (`ryoku/lockscreen/sddm/`, greeter half of `install-qylock`, `ryoku/lockscreen/qylock/themes/clockwork/orbital/`)

**What it does:** SDDM is the login manager
(`system/packages/base.packages:120-121`; enabled by
`installation/backend/lib/bootloader.sh:41` and `sddm/setup:76`). The greeter
runs on Wayland under weston's kiosk shell, wrapped by `ryoku-greeter`, and
shows the qylock `clockwork/orbital` skin installed as SDDM theme `ryoku`.

- `sddm/setup` (run at install, `installation/backend/lib/deploy.sh:318-323`;
  mirrored for existing boxes by the doctor,
  `ryoku/cli/internal/doctor/doctor.go:2442-2545`):
  1. `systemctl enable sddm.service`; `systemctl set-default graphical.target`
     (`sddm/setup:76,83`).
  2. pam_gnome_keyring wiring of `/etc/pam.d/sddm`, anchored on
     `include system-login` (`sddm/setup:107-114`), or stripping it under
     autologin (`:116-125`).
  3. Fallback `/usr/share/wayland-sessions/<id>.desktop` from `ryoku wm session`
     (`:134-158`).
  4. Writes `/etc/sddm.conf.d/10-ryoku-wayland.conf` (`:173-208`):

     ```ini
     [General]
     DisplayServer=wayland
     GreeterEnvironment=QT_QPA_PLATFORM=wayland,XCURSOR_THEME=Bibata-Modern-Ice,XCURSOR_SIZE=24,QML_XHR_ALLOW_FILE_READ=1
     [Wayland]
     CompositorCommand=/usr/share/ryoku/lockscreen/ryoku-greeter   (else weston --shell=kiosk [--renderer=pixman] on NVIDIA)
     SessionCommand=/usr/share/ryoku/lockscreen/ryoku-wayland-session   (else /usr/share/sddm/scripts/wayland-session)
     ```

  5. `/usr/share/icons/default/index.theme` with `Inherits=Bibata-Modern-Ice`
     when absent (`:220-232`).
- `install-qylock` greeter half: copies `themes/clockwork/orbital` to
  `/usr/share/sddm/themes/ryoku` and writes `/etc/sddm.conf.d/99-ryoku.conf` =
  `[Theme]` `Current=ryoku` (`install-qylock:338-353`). The Hub's lock picker
  replaces that theme dir via `pkexec ryoku-hub lock apply-greeter <slug>`
  (`ryoku/hub/backend/lock.go:373-384,404,458-468`).
- `ryoku-greeter`: probes connector modes with `modetest -c`
  (`ryoku-greeter:194-211`), waits for the connected set to settle (`:245-258`),
  writes a weston ini (`[core] idle-time=0`, `[shell] cursor-theme/size`,
  `[libinput] enable-tap=true`, `[keyboard] numlock-on=true`, one
  `[output] mode=WxH@R` per panel, `app-ids=sddm-greeter-qt6` on the chosen
  primary; `:161-228`), uses `--renderer=pixman` only when NVIDIA drives the
  internal panel (`:43-49`), takes the keyboard layout from
  `/etc/X11/xorg.conf.d/00-keyboard.conf` then `KEYMAP=` in `/etc/vconsole.conf`
  (`:97-118`), and the primary from env, `/etc/ryoku/greeter.conf`,
  `/var/lib/ryoku/greeter-primary` (written by the Hub's Displays apply) or the
  first eDP/LVDS/DSI (`:124-156`). It
  `exec weston --shell=kiosk ... --config=<ini>` (`:269`).
- `ryoku-wayland-session`: waits up to 8 s for `weston` to exit (hybrid-GPU DRM
  handover, issue #174) then `exec /usr/share/sddm/scripts/wayland-session "$@"`
  (`ryoku-wayland-session:18-39`).
- Theme `clockwork/orbital`: `metadata.desktop` `QtVersion=6`
  (`metadata.desktop:8`); imports `QtQuick`, `QtQuick.Window`,
  `Qt5Compat.GraphicalEffects`, `Qt.labs.folderlistmodel`, `SddmComponents 2.0`
  (`Main.qml:1-5`); its own I18n reads `/usr/share/ryoku/i18n/*.json` via
  synchronous `file://` XHR (`i18n/I18n.qml:17-27`), which is why
  `QML_XHR_ALLOW_FILE_READ=1` is in `GreeterEnvironment`.

**SDDM facts per suite** (verified by downloading and unpacking the debs,
inspection only):

|                                       | Arch (extra)                                                       | trixie                                                                                                                                                                                               | forky / sid                  | resolute                            |
| ------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ----------------------------------- |
| sddm version                          | 0.21.0-7                                                           | 0.21.0+git20250502.4fe234b-2                                                                                                                                                                         | 0.21.0+git20260819.da0b64d-1 | 0.21.0+git20250502.4fe234b-2ubuntu3 |
| greeter binaries                      | `sddm-greeter` (Qt5) + `sddm-greeter-qt6`                          | `sddm-greeter-qt6` only                                                                                                                                                                              | `sddm-greeter-qt6` only      | `sddm-greeter-qt6` only             |
| Qt6 SddmComponents                    | `/usr/lib/qt6/qml/SddmComponents`                                  | `/usr/lib/x86_64-linux-gnu/qt6/qml/SddmComponents`                                                                                                                                                   | same                         | same                                |
| Wayland helper                        | yes                                                                | `/usr/lib/x86_64-linux-gnu/sddm/sddm-helper-start-wayland`                                                                                                                                           | yes                          | yes                                 |
| default `[Wayland] CompositorCommand` | `weston --shell=kiosk`                                             | `weston --shell=kiosk` (man sddm.conf(5))                                                                                                                                                            | same                         | same                                |
| default `[Wayland] SessionCommand`    | `/usr/share/sddm/scripts/wayland-session`                          | `/etc/sddm/wayland-session` (Debian script); upstream `/usr/share/sddm/scripts/wayland-session` also shipped                                                                                         | same                         | same                                |
| X server dependency                   | none                                                               | `Depends: xserver-xorg \| xserver, x11-common, xauth`                                                                                                                                                | same                         | none                                |
| `/etc/pam.d/sddm`                     | `auth include system-login` ... (sddm v0.21.0 `services/sddm.pam`) | `@include common-auth`, `-auth optional pam_gnome_keyring.so`, `@include common-account`, `@include common-session`, `-session optional pam_gnome_keyring.so auto_start`, `@include common-password` | same layout                  | same layout                         |
| `/etc/pam.d/sddm` is a conffile       | `backup=` (`.pacnew`)                                              | yes (`DEBIAN/conffiles`)                                                                                                                                                                             | yes                          | yes                                 |
| greeter user                          | `sddm`, home `/var/lib/sddm`                                       | same (`usr/lib/sysusers.d/sddm.conf`, postinst `adduser --system ... --home /var/lib/sddm sddm`)                                                                                                     | same                         | same                                |
| weston (kiosk-shell.so)               | 15.0.1                                                             | 14.0.2-1 (yes)                                                                                                                                                                                       | 16.0.0-1 (yes)               | 14.0.2-5 (yes)                      |

**Arch couplings:**

- PAM anchor `include system-login` (`sddm/setup:109,112`; the same anchor in
  `ryoku/cli/internal/keyring/pam.go:51-57,93,99`). Debian's `/etc/pam.d/sddm`
  has no such line, so `sed -i '/... include ... system-login/a ...'` matches
  nothing and adds nothing; unlock-on-login still works on Debian because the
  stock file already carries `-auth optional pam_gnome_keyring.so` /
  `-session optional pam_gnome_keyring.so auto_start` (needs
  libpam-gnome-keyring). The never-ask strip (`sddm/setup:119-121`) deletes
  those Debian lines too and works. `ryoku keyring` status reports the anchor
  missing on Debian (`keyring/pam.go:93,99`).
- `qt5-wayland` is a hard depend only because Arch/CachyOS may run the Qt5
  greeter (`release/packages/ryoku-desktop/PKGBUILD:38-41`,
  `system/packages/base.packages:93-99`); Debian has no Qt5 greeter, so
  qtwayland5 is not needed for the greeter. `tests/sddm-wayland.sh:11-14` fails
  unless `qt5-wayland` is in the Arch package lists.
- `modetest` ships in Arch `libdrm` (always installed); on Debian it is in
  `libdrm-tests`. Without it `ryoku-greeter:188` falls back to plain weston:
  preferred (often 60 Hz) mode and no output pinning.
- Keyboard layout sources (`ryoku-greeter:100-113`): Debian keeps the system
  layout in `/etc/default/keyboard` (`XKBLAYOUT=`, `XKBVARIANT=`,
  `XKBOPTIONS=`); on this trixie host `/etc/vconsole.conf` is a symlink to it
  and has no `KEYMAP=` line, and no `00-keyboard.conf` exists. Result on Debian:
  the greeter always comes up on weston's built-in `us` map.
- Fingerprint toggles: `LockscreenPage.qml:133-160` inserts
  `auth sufficient pam_fprintd_grosshack.so` at line 1 of
  `/etc/pam.d/{sudo,sddm,polkit-1}` via `pkexec bash -c sed`; module presence
  probed at `/usr/lib/security/pam_fprintd_grosshack.so`
  (`LockscreenPage.qml:933`, `reconcile_fingerprint.go:37`). Debian's PAM module
  dir is `/usr/lib/x86_64-linux-gnu/security/`, so the probe is false and the
  toggles never show; the doctor installs the module with
  `ryoku-pkg-aur-add pam-fprint-grosshack` (`reconcile_fingerprint.go:80`).
- `polkit-1` PAM lives at `/usr/lib/pam.d/polkit-1` on both Arch (`polkit` file
  list) and Debian (`polkitd` 126 file list); `/etc/pam.d/polkit-1` does not
  exist by default on either, so the Hub's polkit toggle `sed -i` fails on a
  missing file (pre-existing, both distros).

**Dependencies:**

| Arch pkg                     | Used for (cite)                                                                                                                            | Debian/Ubuntu pkg                                                                                       | trixie                       | trixie-bpo | forky                        | sid        | resolute                            | Min version Ryoku needs (why, cite)                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- | ---------------------------- | ---------- | ---------------------------- | ---------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| sddm                         | login manager, Qt6 greeter, `SddmComponents 2.0` (`Main.qml:5`)                                                                            | sddm                                                                                                    | 0.21.0+git20250502.4fe234b-2 | -          | 0.21.0+git20260819.da0b64d-1 | same       | 0.21.0+git20250502.4fe234b-2ubuntu3 | 0.21 (Wayland greeter `DisplayServer=wayland` + `[Wayland] CompositorCommand`; Qt6 greeter for `QtVersion=6`)  |
| weston                       | kiosk compositor (`ryoku-greeter:269`)                                                                                                     | weston                                                                                                  | 14.0.2-1                     | -          | 16.0.0-1                     | 16.0.0-1   | 14.0.2-5                            | kiosk-shell with `[output] app-ids=` and `--renderer=pixman` (present in 14: kiosk-shell.so in the trixie deb) |
| libdrm                       | `modetest -c` (`ryoku-greeter:195`)                                                                                                        | libdrm-tests                                                                                            | 2.4.124-2                    | -          | 2.4.134-3                    | 2.4.134-3  | 2.4.131-1                           | none                                                                                                           |
| qt6-wayland                  | `QT_QPA_PLATFORM=wayland` in the greeter (`sddm/setup:203`)                                                                                | qt6-wayland                                                                                             | 6.8.2-4                      | -          | 6.11.2-2                     | 6.11.2-2   | 6.10.2-4                            | none                                                                                                           |
| qt5-wayland                  | Qt5 greeter only (`PKGBUILD:38-41`)                                                                                                        | (not needed: no Qt5 greeter on Debian)                                                                  | 5.15.15-3                    | -          | 5.15.19-2                    | 5.15.19-2  | 5.15.18-1                           | n/a                                                                                                            |
| qt6-5compat, qt6-declarative | theme imports (`Main.qml:2-4`)                                                                                                             | qml6-module-qt5compat-graphicaleffects, qml6-module-qtquick-window, qml6-module-qt-labs-folderlistmodel | 6.8.2                        | -          | 6.11.2                       | 6.11.2     | 6.10.2                              | none                                                                                                           |
| (optional RyoStore skins)    | upstream skins at `cde4d11` also import `QtMultimedia`, `QtQuick.Controls`, `QtQuick.Layouts` (sampled `themes/{Genshin,forest}/Main.qml`) | qml6-module-qtmultimedia, qml6-module-qtquick-controls, qml6-module-qtquick-layouts                     | 6.8.2                        | -          | 6.11.2                       | 6.11.2     | 6.10.2                              | none                                                                                                           |
| gnome-keyring                | unlock-on-login (`sddm/setup:85-125`)                                                                                                      | gnome-keyring, libpam-gnome-keyring                                                                     | 48.0-1                       | -          | 51.1-3                       | 51.1-3     | 50.0-1                              | none                                                                                                           |
| pam-u2f                      | Hub security-key wiring of `/etc/pam.d/{sudo,polkit-1,sddm}` (`ryoku/cli/internal/securitykey/pam.go:21-30,43-71`)                         | libpam-u2f, pamu2fcfg                                                                                   | 1.4.0-1                      | -          | 1.4.0-3+b2                   | 1.4.0-3+b2 | 1.4.0-3build1                       | Arch ships 1.4.0                                                                                               |
| pam-fprint-grosshack (AUR)   | Hub fingerprint toggles (`LockscreenPage.qml:133`)                                                                                         | not packaged                                                                                            | -                            | -          | -                            | -          | -                                   | build `https://gitlab.com/mishakmak/pam-fprint-grosshack` tag `v0.3.0` (AUR pkgver 0.3.0-1)                    |
| ryoku-cursors                | `Bibata-Modern-Ice` in greeter env and default cursor (`sddm/setup:203,226-231`)                                                           | (Ryoku package; build as .deb)                                                                          | -                            | -          | -                            | -          | -                                   | n/a                                                                                                            |

**As-is on Debian:** PARTIAL: Debian's sddm runs the Qt6 Wayland greeter and the
theme, but the layout detection, `modetest`, the grosshack paths and the Xorg
pull-in differ.

**Port steps:**

1. Packages:
   `sddm weston libdrm-tests qt6-wayland qml6-module-qt5compat-graphicaleffects qml6-module-qtquick-window qml6-module-qt-labs-folderlistmodel qml6-module-qtmultimedia qml6-module-qtquick-controls qml6-module-qtquick-layouts gnome-keyring libpam-gnome-keyring libpam-u2f pamu2fcfg fprintd libpam-fprintd`.
   Drop qt5-wayland for the greeter and change `tests/sddm-wayland.sh:11-14`
   accordingly.
2. Xorg pull-in (trixie, forky, sid): sddm `Depends: xserver-xorg | xserver`.
   Either install it (`xserver-xorg` + drivers), or satisfy the virtual with a
   small provider (`xserver-xephyr`, `xvfb` or `xnest` all `Provides: xserver`,
   checked with `apt-cache showpkg xserver` on this trixie host), or rebuild
   sddm with the dependency dropped (Ubuntu resolute's sddm already has none).
3. `sddm/setup` on Debian: keep steps 1, 3-5 as they are (paths
   `/etc/sddm.conf.d`, `/usr/share/wayland-sessions`, `/usr/share/sddm/themes`,
   `/usr/share/sddm/scripts/wayland-session` all exist in the Debian package).
   Step 2 (PAM): replace the `system-login` anchor with Debian's: append
   `auth optional pam_gnome_keyring.so` after `@include common-auth` and
   `session optional pam_gnome_keyring.so auto_start` after
   `@include common-session`, or rely on Debian's stock `-auth`/`-session`
   gnome-keyring lines and only implement the never-ask strip. Make the same
   anchor change in `ryoku/cli/internal/keyring/pam.go:51-99`.
4. `ryoku-greeter` keyboard: after the `00-keyboard.conf` block
   (`ryoku-greeter:100-108`), read `/etc/default/keyboard`: `XKBLAYOUT`,
   `XKBVARIANT`, `XKBOPTIONS` (first comma field for layout/variant, as the
   script already does) before falling back to `KEYMAP=`. Mirror it in
   `consoleToXkb` (`ryoku/cli/internal/keyboard/keyboard.go`, named at
   `ryoku-greeter:62`).
5. SessionCommand: `ryoku-wayland-session` execs the upstream
   `/usr/share/sddm/scripts/wayland-session` (exists on Debian, runs
   `$SHELL --login -c`); Debian's own default is `/etc/sddm/wayland-session`
   (sources `/etc/profile` and `~/.bash_profile`/`~/.profile`, or the zsh
   profile files, itself). To keep Debian's login-env behaviour set
   `RYOKU_WAYLAND_SESSION_DEFAULT` semantics to `/etc/sddm/wayland-session`
   (`ryoku-wayland-session:35`) and the same constant in `doctor.go:2482` and
   `sddm/setup:196`.
6. Grosshack: build `pam-fprint-grosshack` v0.3.0 as a .deb (meson;
   Build-Depends meson, cmake, pkg-config, libpam0g-dev, libglib2.0-dev,
   libfprint-2-dev, libpolkit-gobject-1-dev, libdbus-1-dev, libdbus-glib-1-dev,
   libsystemd-dev; tests need libpam-wrapper, python3-dbusmock, python3-dbus,
   python3-cairo), installing to
   `/usr/lib/x86_64-linux-gnu/security/pam_fprintd_grosshack.so`. Change the
   probe path in `LockscreenPage.qml:933` and `reconcile_fingerprint.go:37` to
   the multiarch dir (or probe both), and replace
   `ryoku-pkg-aur-add pam-fprint-grosshack` (`reconcile_fingerprint.go:80`) with
   the .deb.
7. Conffile handling: `/etc/pam.d/sddm` and `/etc/pam.d/sudo` are dpkg
   conffiles; every Ryoku edit (keyring, grosshack, security key) makes them
   locally modified. Unattended upgrades of sddm/sudo must run with
   `-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold` or
   dpkg stops at a conffile prompt.
8. Display-manager selection: Debian's sddm postinst links
   `display-manager.service` from `/etc/X11/default-display-manager` (sddm
   `postinst:64-75`); write `/usr/bin/sddm` there (or preseed
   `shared/default-x-display-manager select sddm`) so another installed DM
   cannot win.

**Complexity:** Medium: five small script edits plus one source-built PAM
module; the Xorg dependency is a packaging decision.

**Issues / risks:**

- Debian trixie sddm is a 2025-05 git snapshot of 0.21 and forky/sid a 2026-08
  snapshot; Arch runs the 0.21.0 release plus one cherry-pick. Greeter behaviour
  that Ryoku worked around (orphaned greeter, numlock inert under Wayland,
  `ryoku-greeter:163-168`) may differ between snapshots.
- NVIDIA greeter cursor workaround (`--renderer=pixman`, `ryoku-greeter:35-49`)
  was tuned on weston 15 (Arch); trixie/resolute run weston 14, forky/sid 16.

**Questions for the human:**

- Fingerprint at sudo/SDDM/polkit: (a) build `pam-fprint-grosshack` v0.3.0 as a
  .deb (keeps Arch behaviour: sensor and password field live together; the AUR
  package was last modified 2022-07-27, upstream tag v0.3.0); (b) use Debian's
  stock `pam_fprintd` through its `pam-auth-update` profile
  `/usr/share/pam-configs/fprintd` (no custom build, `sed -i` edits disappear;
  but the stack is serialised, so the password prompt waits for the scan
  timeout, the starvation `README.ryoku.md:33-37` describes) and rewrite the Hub
  toggles to call `pam-auth-update --enable/--disable fprintd`.
- Xorg on the login path: (a) let sddm pull `xserver-xorg` (about 20+ packages,
  an X server installed but unused); (b) satisfy `xserver` with
  `xvfb`/`xserver-xephyr` (small, a hack that any later `apt` may question); (c)
  rebuild sddm without the X dependency as a Ryoku .deb (tracks Debian's sddm on
  every update).

### Browser theme extension (`ryoku/browser/`)

**What it does:** Plain-JS WebExtension (no bundler, no npm:
`ryoku/browser/README.md:3-4`) that recolors Firefox chrome live and exposes the
palette as CSS variables in every engine, fed by the native-messaging host
`ryoku_theme` = `ryoku-shell browser-host` (`README.md:9-11`;
`release/packages/ryoku-desktop/PKGBUILD:355-357`). `build.sh` only copies
`src/` + `manifest.<engine>.json` into `dist/{chromium,firefox}`
(`ryoku/browser/build.sh`); the PKGBUILD reproduces that inline into
`/usr/share/ryoku/browser/dist/{chromium,firefox}` (`PKGBUILD:358-366`).
`sign.sh` signs the Firefox build on AMO via `web-ext` or `npx --yes web-ext`
(`sign.sh`), producing `ryoku-theme.xpi`, which is not committed
(`git ls-files ryoku/browser`).

**Arch couplings:**

- Native-host manifests are per-user and distro-neutral:
  `~/.mozilla/native-messaging-hosts`, `~/.librewolf/...`,
  `~/.config/{chromium,google-chrome,BraveSoftware/Brave-Browser,microsoft-edge,vivaldi}/NativeMessagingHosts`
  (`ryoku/cli/internal/doctor/reconcile_browser.go:58-65`). Debian chromium and
  firefox-esr use the same per-user dirs.
- Zen policy roots include the AUR layout `/usr/lib/zen-browser`,
  `/opt/zen-browser-bin` (`ryoku/cli/internal/doctor/reconcile_zen.go:72-78`);
  `zen-browser-bin` comes from the AUR (`system/packages/aur.packages:60`). Zen
  is not in Debian/Ubuntu; a tarball/Flatpak install lands elsewhere (the code
  also follows a `zen` binary on PATH, `reconcile_zen.go:83-86`).
- Firefox extension id `ryoku-theme@ryoku.arch` (`manifest.firefox.json:6`,
  `reconcile_browser.go:19`): a name only, no functional coupling.

**Dependencies:** none at runtime beyond the browser. `sign.sh` (maintainer
only): web-ext (not in Debian; `npx --yes web-ext` via nodejs/npm).

**As-is on Debian:** YES.

**Port steps:** 1. Install `src/` and both manifests to
`/usr/share/ryoku/browser/dist/{chromium,firefox}` exactly as
`PKGBUILD:358-366`. 2. Zen: if the port ships Zen, add its install root to
`zenInstallRoots()` (`reconcile_zen.go:72-78`).

**Complexity:** Low.

**Issues / risks:** `zenThemeXPI=/usr/share/ryoku/browser/ryoku-theme.xpi`
(`reconcile_zen.go:32`) is never shipped (no committed xpi), so the Zen theme
branch is dead on Arch and Debian alike.

## Cross-cutting findings

1. **Qt6 QML module path.** Every Ryoku QML module is installed to the Arch path
   `/usr/lib/qt6/qml/Ryoku/*`
   (`release/packages/ryoku-desktop/PKGBUILD:324-349`,
   `release/packages/ryoku-blobs/PKGBUILD:33-34`,
   `release/packages/ryoku-desktop-hyprland/PKGBUILD:87-88`). Debian's Qt6
   import dir is `/usr/lib/x86_64-linux-gnu/qt6/qml` (verified in the trixie
   sddm, qt5compat and quickshell debs). Missing Ryoku.Ui or Ryoku.FrameBars
   means no shell, no Hub and no lock (`PKGBUILD:344-345`). Use
   `qtpaths6 --query QT_INSTALL_QML` (qt6-base-dev-tools, `/usr/bin/qtpaths6`)
   in every Debian package that installs QML. The qylock shim symlinks
   (`ryoku/lockscreen/qylock/quickshell-lockscreen/imports/QtGraphicalEffects/*`)
   and `bin/ryoku-dev-lint-qml:28` carry the same hardcode.
2. **Quickshell >= 0.3.0** is needed by Ryoku.Ui (`Quickshell.WindowManager`,
   `ryoku/ui/Singletons/Wm.qml:6`) and the Hub (`Quickshell.Networking`).
   Availability: trixie main none, trixie-backports 0.3.0-1~bpo13+1, forky/sid
   0.3.2-1, resolute none; Arch runs 0.3.2. The shell subsystem report must give
   the true minimum; if it is above 0.3.0, trixie needs a Ryoku-built
   quickshell.
3. **Go >= 1.26.4** for `ryoku-hub` (`go.mod:3,5`), 1.26 for `ryoku-rashin`
   (`go.mod:3`) and prowl-agent: trixie needs `golang-1.26-go` from
   trixie-backports; set `GOTOOLCHAIN=local` (Debian's `go.env` defaults to
   `auto` and would try a download).
4. **Package-manager seam.** pacman/AUR/checkupdates calls live in the hub
   backend (`gpuapply.go`, `wm.go`), in `ryoku-wm` (vendored into the hub and
   Rashin: `vendor/ryoku-wm/reclaim.go:204-276`), in Rashin
   (`quicktools.go:106-112`, `index.go:438-455`), in Hub helper scripts
   (`ryoku/shell/scripts/ryoku-sysinfo:71`, `ryoku-profile-stats:51-52`,
   `system/extras/ryostore-install`) and in the CLI that the Hub calls
   (`ryoku status`, `ryoku update`, `ryoku doctor`, `ryoku keyboard apply`). One
   apt/dpkg backend behind a shared Go package keeps them consistent. Debian has
   a `pacman` game in `/usr/games` and a `pacman-package-manager` package, so
   "is pacman on PATH" checks are not a distro test; read `/etc/os-release`.
5. **polkit group.** All Ryoku polkit rules grant password-free actions to
   `wheel` (`system/**/4x-5x-*.rules`); Debian/Ubuntu use `sudo`. The Hub's
   Connections page triggers a pkexec on load (`ConnectionsPage.qml:66-69`).
6. **PAM differences** (used by greeter, Hub Lockscreen page, `ryoku keyring`,
   `ryoku security-key`): module dir `/usr/lib/x86_64-linux-gnu/security` (Ryoku
   probes `/usr/lib/security/pam_fprintd_grosshack.so`,
   `LockscreenPage.qml:933`, `reconcile_fingerprint.go:37`); `@include common-*`
   instead of `include system-login` (`sddm/setup:109,112`,
   `ryoku/cli/internal/keyring/pam.go:51-99`); polkit PAM is
   `/usr/lib/pam.d/polkit-1` on both Debian and Arch, so `/etc/pam.d/polkit-1`
   edits fail everywhere; `/etc/pam.d/{sddm,sudo}` are dpkg conffiles, so
   Ryoku's edits make unattended upgrades stop at conffile prompts unless
   `--force-confdef --force-confold` is passed.
7. **`/usr/sbin` is not on a Debian user's PATH** (`/etc/profile`:
   `/usr/local/bin:/usr/bin:/bin:/usr/games`); user-context calls to `modinfo`,
   `modprobe`, `usermod` etc. need absolute paths
   (`ryoku/hub/backend/hwcaps.go:592`). Debian sddm's compiled `DefaultPath` is
   `/bin:/usr/bin` (man sddm.conf(5) in the trixie deb); Arch's PKGBUILD
   rewrites it to `/usr/local/sbin:/usr/local/bin:/usr/bin`.
8. **Keyboard layout source.** Debian keeps the system layout in
   `/etc/default/keyboard` (`XKBLAYOUT`/`XKBVARIANT`/`XKBOPTIONS`);
   `/etc/vconsole.conf`, when present, is a symlink to it with no `KEYMAP=`
   (this trixie host). Affects `ryoku-greeter:97-118`,
   `ryoku/cli/internal/keyboard/keyboard.go` (`mkinitcpio -P`, vconsole) and the
   Hub Input page.
9. **`/var/lib/ryoku/greeter-primary`** is written by the user (mode 0666,
   `ryoku/hub/backend/outputs.go:187,194`) and read by the greeter
   (`ryoku-greeter:130`); the tmpfiles entry
   `ryoku/cli/systemd/ryoku.tmpfiles.conf:10` must ship in the Debian package.
10. **Unpackaged on every Debian/Ubuntu suite** (build as .deb): matugen (Arch
    4.2.0), voxtype (upstream ships `voxtype_1.1.1-1_amd64.deb`), asusctl (Ryoku
    builds 6.4.0), qmk_hid (v0.1.13), kvmfr DKMS, gpk, blesh, prowl-agent,
    pam-fprint-grosshack (v0.3.0), ryoku-cursors (Bibata), fonts Space Grotesk
    (Ubuntu only), Fraunces, JetBrainsMono Nerd Font, Material Symbols Rounded;
    partially packaged: looking-glass-client (sid only), openrgb
    (forky/sid/resolute only, no udev rules on Debian), quickshell (not trixie
    main, not resolute), uv (forky/sid only, not needed).
11. **AppArmor** (default on Debian/Ubuntu) confines libvirt's QEMU; the
    passthrough lane's `/dev/kvmfr0` needs a local abstraction entry. Nothing in
    the repo handles AppArmor.
12. **Binary-name differences** that reach this scope: `firefox-esr` (trixie),
    `brave-browser`, `fdfind`, `batcat`, `/usr/bin/luac` via alternatives,
    `modetest` in `libdrm-tests`, `dbus-monitor` in `dbus-bin`, `pkexec` as its
    own package, `swtpm_setup` in `swtpm-tools`, `sqlite3` CLI as its own
    package.
13. **Opt-in user units.** debhelper's `dh_installsystemduser` enables user
    units globally by default; `ryoku-rashin.service` must be installed with
    `--no-enable`, and Debian's own `openrgb.service` (globally enabled by its
    postinst) must be disabled for the Hub's loopback-only OpenRGB server to be
    used.
14. **i18n.** Every reworded Arch string (pacman, AUR, GlazePKG, base-devel,
    "performance Arch", ...) is a catalog key present in 35 languages; rewording
    means `sync.py extract` + `sync` (Google engine needs no key; LLM engine
    needs `RYOKU_I18N_KEY`). `/usr/bin/ryoku-i18n` currently cannot start on any
    packaged system (`ryoku/i18n/tools/sync.py:64-77`).
15. **Weston/SDDM versions differ from Arch** (Arch weston 15.0.1 vs
    trixie/resolute 14.0.2, forky/sid 16.0.0; Debian sddm is a git snapshot of
    0.21). Greeter workarounds tuned on Arch (`ryoku-greeter` NVIDIA pixman,
    numlock, settle loop) need a re-test on each Debian suite.
16. **Docs vs code** disagreements found in scope: Rashin default-on vs "off by
    default" (`config.go:41-45` vs `docs/rashin.md:7,14-18`); fingerprint module
    grosshack vs stock pam_fprintd (`reconcile_fingerprint.go:14-20` vs
    `assets/pam/ryoku-lock:27`); passthrough "kernel cmdline token" comment
    (`gpuapply.go:6-7`) with no code behind it; prowl "optional, user-installed"
    (`prowl.go:15-17`, `docs/rashin.md:330`) vs a hard depend
    (`release/packages/ryoku-rashin/PKGBUILD:29`).

## Debian package names needed by this scope

Archive (main unless noted): `bash`, `bluez`, `build-essential`,
`ca-certificates`, `coreutils`, `curl`, `dbus-bin`, `dnsmasq-base`, `fastfetch`,
`ffmpeg`, `fish`, `fontconfig`, `fonts-inter`, `fonts-noto-cjk`,
`fonts-noto-color-emoji`, `fonts-noto-core`, `fprintd`, `gcc`, `git`,
`gnome-keyring`, `golang-1.26-go` (trixie: trixie-backports; build),
`imagemagick`, `iproute2`, `jq`, `kitty`, `kmod`, `libatomic1`, `libc6-dev`,
`libdrm-tests`, `libglib2.0-bin`, `libpam-fprintd`, `libpam-gnome-keyring`,
`libpam-modules`, `libpam-u2f`, `libqt6multimedia6`, `librsvg2-bin`,
`libvirt-clients`, `libvirt-daemon-system`, `lm-sensors`, `lua5.4`, `neovim`,
`network-manager`, `nodejs` (CI tests only), `nvidia-smi` (non-free; Ubuntu
`nvidia-utils-580`), `openrgb` (forky/sid/resolute), `ovmf`, `pamu2fcfg`,
`passwd`, `pciutils`, `pkexec`, `polkitd`, `procps`, `psmisc`, `python3`,
`python3-venv`, `qemu-system-modules-spice`, `qemu-system-x86`, `qemu-utils`,
`qml6-module-qt-labs-folderlistmodel`, `qml6-module-qt5compat-graphicaleffects`,
`qml6-module-qtmultimedia`, `qml6-module-qtqml-workerscript`,
`qml6-module-qtquick`, `qml6-module-qtquick-controls`,
`qml6-module-qtquick-effects`, `qml6-module-qtquick-layouts`,
`qml6-module-qtquick-shapes`, `qml6-module-qtquick-templates`,
`qml6-module-qtquick-window`, `qt6-base-dev-tools` (build: `qtpaths6`),
`qt6-declarative-dev-tools` (dev: `qmllint`), `qt6-image-formats-plugins`,
`qt6-shader-baker` (dev: `qsb`), `qt6-svg-plugins`, `qt6-wayland`, `quickshell`
(trixie-backports / forky / sid), `rfkill`, `rsync`, `sddm`, `snapper`,
`sqlite3`, `swtpm`, `swtpm-tools`, `systemd`, `tzdata`, `udev`, `util-linux`,
`weston`, `wl-clipboard`, `xdg-utils`, `zsh`; one `xserver` provider for sddm on
Debian (`xserver-xorg`, or `xvfb`/`xserver-xephyr`, per the greeter question).
Optional/dev: `looking-glass-client` (sid), `python3-py-tree-sitter`
(experimental only; `wrap.py` uses a pip venv instead).

Ryoku-built .debs required by this scope: `ryoku-hub`, `ryoku-rashin` (+
`rashin` link, skills, user unit), `ryoku-desktop` parts
(Ryoku.Ui/PluginKit/FrameBars QML, Hub config, qylock bundle, greeter scripts,
i18n catalog, browser extension), `prowl-agent`, `blesh`, `matugen`, `voxtype`
(repackaged upstream deb), `asusctl`, `qmk-hid`, `kvmfr-dkms` (looking-glass
module), `pam-fprint-grosshack` (if chosen), `openrgb` (trixie only) +
`60-openrgb.rules`, `ryoku-cursors`, fonts `fonts-space-grotesk` (Debian),
`fonts-fraunces`, `fonts-jetbrainsmono-nerd`, `fonts-material-symbols-rounded`.

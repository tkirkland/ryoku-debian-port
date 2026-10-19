# 07 - Machine policy layer: hardware, drivers, store, containers, policy

Scope: everything under `system/hardware/` (gpu, drivers, display, audio, bluetooth,
network, input, ddc, power), `system/containers/`, `system/extras/` (the RyoStore
bundle actuator and the `ryoku-pkg-*` wrappers), `system/policy/`, the bundle
catalogue in the external `ryostore` repo, and the release packages `gpk`,
`asusctl`, `xpadneo-dkms`, `game-devices-udev`, `broadcom-bt-firmware`,
`dualsensectl`, `prowl-agent`, `blesh`, `ryoku-oh-my-zsh`. Source pinned at ryoku
`98a03682` (2026-09-26). The ryostore catalogue is read at its main-line commit
`f928795` (2026-09-24, last `main` merge before the ryoku pin); one bundle
(`ryoku-zed-theme`) was added on `main` after that and is listed separately.
Package versions come from `tools/pkgver` (madison, all components) unless stated.
Arch versions quoted as "Arch" were read from archlinux.org / AUR RPC on 2026-10-17.

## Summary

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| GPU detection + render pin | `system/hardware/gpu/ryoku-gpu`, `ryoku-gpu-detect`, `90-ryoku-gpu.rules` | YES | Low | none (sysfs, udev, lspci only) |
| GPU MUX switch | `system/hardware/gpu/ryoku-gpu-mux`, `45-ryoku-gpu-mux.rules` | PARTIAL | Low | polkit rule keys on `wheel`; `asus-armoury` interface absent from trixie's 6.12 kernel |
| 32-bit GPU driver installer | `system/hardware/gpu/ryoku-gpu-lib32` | NO | Medium | pacman, `[multilib]`, lib32-* names |
| NVIDIA driver installer | `system/hardware/drivers/nvidia.sh` | NO | High | pacman, AUR branches, mkinitcpio, pacman hook; Debian archive tops out at 550 (no Blackwell, no explicit sync); Debian renames the kernel module so Ryoku's `modinfo nvidia` probe fails |
| NVIDIA login-loop guard | `system/hardware/drivers/ryoku-nvidia-guard` | NO | Medium | pacman hook + `NeedsTargets`, pacman package names, mkinitcpio/limine |
| AMD / Intel / Vulkan installers | `system/hardware/drivers/{amd,intel,vulkan}.sh` | NO | Low | pacman + Arch package names |
| NVIDIA Wayland env | `ryoku/hyprland/modules/env.lua:25-41` | YES | Low | needs `nvidia-vaapi-driver` (name differs) |
| Laptop classifier | `system/hardware/power/ryoku-hw-laptop` | YES | Low | none |
| Idle timers | `system/hardware/power/ryoku-idle` | PARTIAL | Low | `hypridle` not in trixie main (trixie-backports 0.1.8) |
| Power knobs | `system/hardware/power/ryoku-power`, `47-ryoku-power.rules` | PARTIAL | Low | `wheel` group in polkit rule |
| Power-policy package cutover | `system/hardware/power/ryoku-power-cutover`, `94/95-ryoku-power-cutover*.hook` | NO | High | libalpm hooks, `/var/lib/pacman/db.lck` existence test |
| Clamshell + logind drop-in | `system/hardware/power/ryoku-clamshell`, `logind-ryoku-lid.conf` | YES | Low | none |
| Game Mode system tune | `system/hardware/power/ryoku-game-tune`, `53-ryoku-game-tune.rules` | PARTIAL | Low | `wheel` group |
| Backlight helpers | `system/hardware/display/*` | PARTIAL | Medium | `ryoku-hw-backlight-fix` is Limine-entry-tool only |
| Audio helpers | `system/hardware/audio/*` | PARTIAL | Low | `ryoku-restart-audio` needs passwordless `sudo usbreset` |
| Bluetooth helpers | `system/hardware/bluetooth/*` | PARTIAL | Low | `wheel` group; editing a dpkg conffile |
| Network helpers | `system/hardware/network/*` | PARTIAL | Medium | `/etc/conf.d/wireless-regdom` does not exist on Debian; `wheel`; iwd vs wpa_supplicant default |
| Input rules/modules | `system/hardware/input/*` | YES | Low | none |
| DDC/CI | `system/hardware/ddc/*` | PARTIAL | Low | ddcutil 2.2.x vs Arch 3.0.2 |
| Timezone polkit rule | `system/policy/52-ryoku-timedate.rules` | PARTIAL | Low | `wheel` group |
| Bundle actuator | `system/extras/ryostore-install` | NO | High | pacman query/routing, AUR fallback |
| Package wrappers | `system/extras/ryoku-pkg-*` | NO | Medium | pacman, yay/paru, pacman.conf edits, pacman-key |
| Bundle catalogue | `ryostore/bundles/*/bundle.json` | PARTIAL | High | 37 AUR-routed items + CachyOS layer have no apt route |
| GlazePKG | `release/packages/gpk/PKGBUILD` | PARTIAL | Low | binary has an apt backend; launcher hardcodes `--manager pacman,aur` |
| Container helper | `system/containers/ryoku-docker`, `46-ryoku-docker.rules` | PARTIAL | Low | `wheel` group; Debian `docker.io` enables+starts the daemon on install |
| xpadneo-dkms | `release/packages/xpadneo-dkms` | PARTIAL | Low | in forky/sid only |
| game-devices-udev | `release/packages/game-devices-udev` | NO | Low | not in Debian (only `steam-devices` subset) |
| broadcom-bt-firmware | `release/packages/broadcom-bt-firmware` | NO | Low | not in Debian |
| dualsensectl | `release/packages/dualsensectl` | PARTIAL | Low | forky/sid/resolute only |
| asusctl | `release/packages/asusctl` | NO | Medium | not in Debian/Ubuntu; Rust build |
| prowl-agent | `release/packages/prowl-agent` | NO | Medium | Go 1.26.4 required; trixie has 1.24 |
| blesh | `release/packages/blesh` | PARTIAL | Low | Debian `ble.sh` (forky/sid/resolute) is a git snapshot, not 0.4.0-devel3 |
| ryoku-oh-my-zsh | `release/packages/ryoku-oh-my-zsh` | NO | Low | not in Debian |

---

## Cross-cutting fact 1: every polkit rule keys on the `wheel` group

All eleven Ryoku polkit rules authorize `subject.isInGroup("wheel")`:
`system/policy/52-ryoku-timedate.rules:8`, `system/hardware/network/48-ryoku-wifi-regdom.rules:9`,
`49-ryoku-wifi-powersave.rules:9`, `50-ryoku-dns.rules:11`, `51-ryoku-wifi-backend.rules:9`,
`55-ryoku-network-kill.rules:8`, `system/hardware/power/47-ryoku-power.rules:13`,
`53-ryoku-game-tune.rules:16`, `system/hardware/gpu/45-ryoku-gpu-mux.rules:13`,
`system/hardware/bluetooth/54-ryoku-bluetooth-a2dp.rules:11`, `system/containers/46-ryoku-docker.rules:22`.
The installer creates the user with `useradd -m -G wheel,video,input` (`installation/backend/lib/chroot.sh:117`)
and writes `%wheel ALL=(ALL:ALL) ALL` (`chroot.sh:131-134`).

Debian facts:
- Debian has no `wheel` group by default; the admin group is `sudo` (`%sudo ALL=(ALL:ALL) ALL` in the stock `/etc/sudoers`).
- Debian's polkit is built with `-Dprivileged_group=sudo` (policykit-1 126-2 `debian/rules:44`), so polkit's admin identity (the password asked for `auth_admin` actions) is `unix-group:sudo`. Ubuntu additionally ships `49-ubuntu-admin.rules` returning `["unix-group:sudo", "unix-group:admin"]` (`debian/49-ubuntu-admin.rules`).
- polkitd versions: trixie 126-2, forky 127-3, sid 128-1, resolute 127-2ubuntu1.1. All run JavaScript `.rules` files from `/etc/polkit-1/rules.d` and `/usr/share/polkit-1/rules.d`; `org.freedesktop.policykit.exec`, `action.lookup("program")`, `subject.local`, `subject.active` behave as on Arch (polkit 127).
- `pkexec` is a separate binary package on Debian/Ubuntu (`/usr/bin/pkexec` in package `pkexec`, 126-2 trixie); `polkitd` does not pull it. Every helper that re-execs through pkexec (`ryoku-gpu-mux:132`, `ryoku-game-tune:62`, `ryoku-dns:15`, `ryoku-docker:80`, `ryoku-power`, the network helpers) needs `Depends: pkexec`.

Consequence: a user only in `wheel` on Debian would be denied every Ryoku passwordless grant **and** could not authenticate any other polkit admin prompt (Debian's admin group is `sudo`; root is usually locked). A user only in `sudo` gets prompted (or denied) on every Ryoku helper. See the decision at the end.

## Cross-cutting fact 2: `tools/pkgver` before the fix

Before the coordinator's fix, `tools/pkgver` matched only rows whose suite field was exactly `stable`/`testing`/..., so every `contrib`, `non-free` and `non-free-firmware` package (all NVIDIA, all firmware, steam, winetricks, xpadneo-dkms) read `-`. All versions below were re-queried with the fixed tool; they agree with a component-stripping variant used during the investigation. A second fix (names containing `+`, resolute rows dropped in large batches) followed; every cell that reads `-` in this document was re-queried in batches of five or fewer after that fix and is unchanged (no name in this section contains `+`).

---

### GPU detection and render pin (`system/hardware/gpu/ryoku-gpu`, `ryoku-gpu-detect`, `90-ryoku-gpu.rules`)

**What it does:** `ryoku-gpu-detect` enumerates `/sys/class/drm/card*`, reads `DRIVER`/`PCI_SLOT_NAME` from `device/uevent` (`ryoku-gpu-detect:41-44`), VRAM from amdgpu's `mem_info_vram_total`/`mem_info_vis_vram_total` (`:186-187`), NVIDIA VRAM from `nvidia-smi --query-gpu=pci.bus_id,memory.total` (`:89-90`), model names from `lspci -D` (`:92-93`), both under `timeout -k 1 8` (`:57-69`); classifies egpu/discrete/integrated (`:140-170`) and ranks them (`:172-207`). `ryoku-gpu` writes `~/.config/hypr/gpu.lua` with `hl.env("AQ_DRM_DEVICES", ...)` and `cursor.no_hardware_cursors` (`ryoku-gpu:95-119`), a niri `gpu.kdl` with `debug { disable-cursor-plane }` (`:146-191`), modes hybrid/performance/passthrough (`:404-450`), and `install-udev` copies the rule to `/etc/udev/rules.d/90-ryoku-gpu.rules` (`:41`, `:276-316`, `sudo install`/`udevadm control --reload-rules`/`ln -sfn` at `:289-314`). The udev rule creates `/dev/dri/ryoku-gpu-<slot>` via `PROGRAM="/bin/sh -c 'echo %p | sed ... | tr :. -'"` (`90-ryoku-gpu.rules:18`). Laptop test delegates to `ryoku-hw-laptop` (`ryoku-gpu-detect:255-293`).
**Call sites:** `ryoku/hyprland/modules/autostart.lua:52` and `ryoku/niri/autostart.kdl:43` (`ryoku-gpu persist` each login); `ryoku/hub/backend/gpumode.go:49,144`, `gpuapply.go:153-154`, `hwcaps.go:431`, `ryoku/hub/quickshell/pages/GpuPage.qml:217`; `ryoku/cli/internal/doctor/reconcile_gpu_pin.go:33-74`; `installation/backend/lib/drivers.sh:73-101` (installer `ryoku-gpu mode`).
**Arch couplings:**
- none in the scripts. Packaging installs the rule to `/usr/lib/udev/rules.d/90-ryoku-gpu.rules` (`release/packages/ryoku-desktop/PKGBUILD:566-567`), which is also the correct vendor path on trixie (merged-/usr; systemd 257 ships its rules there).
- `lspci` is assumed present (`system/hardware/README.md:219-221`).
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs |
|---|---|---|---|---|---|---|---|---|
| pciutils | `lspci -D` (`ryoku-gpu-detect:93`) | pciutils | 1:3.13.0-2 | - | 1:3.15.0-2 | 1:3.15.0-2 | 1:3.14.0-1build2 | any |
| systemd (udev) | rule, `udevadm` (`ryoku-gpu:295-299`) | udev | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | any |
| coreutils | `timeout` (`ryoku-gpu-detect:65`) | coreutils | 9.7-3 | - | 9.10-1 | 9.10-1 | 9.7-3ubuntu2.1 | any |
| nvidia-utils (optional) | `nvidia-smi` VRAM (`ryoku-gpu-detect:90`) | nvidia-smi | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | nvidia-utils-580 580.178.04 | any |

**As-is on Debian:** YES; pure sysfs/udev/shell.
**Port steps:**
1. Ship the three files unchanged; `/usr/lib/udev/rules.d/90-ryoku-gpu.rules` via the `ryoku-desktop` deb (`dh_installudev` or plain install).
2. `Depends: pciutils, udev`; `Suggests:` the NVIDIA `nvidia-smi` package.
**Complexity:** Low; no code changes.
**Issues / risks:** On Ubuntu 26.04 `coreutils` may be the Rust uutils implementation; `timeout -k` is supported by uutils `timeout` (not verified on resolute).

### GPU MUX switch (`system/hardware/gpu/ryoku-gpu-mux`, `45-ryoku-gpu-mux.rules`)

**What it does:** Reads/writes the ASUS `gpu_mux_mode` knob: modern `/sys/class/firmware-attributes/*/attributes/gpu_mux_mode/current_value` (asus-armoury) first, legacy `/sys/devices/platform/*/gpu_mux_mode` (asus-nb-wmi) as fallback (`ryoku-gpu-mux:36-37`, `:47-74`), reports `pending_reboot` (`:104-112`), dGPU idle watts via `nvidia-smi --query-gpu=pci.bus_id,power.draw` only in `status` (`:184-198`). `set hybrid|discrete` (`:262-290`) writes through `pkexec "$(readlink -f "$0")"` (`:131-132`), else `sudo tee` (`:134`). Polkit grants `/usr/bin/ryoku-gpu-mux` to active local wheel users (`45-ryoku-gpu-mux.rules:13`).
**Call sites:** `ryoku/hub/backend/gpumux.go:53-79`, `ryoku/cli/internal/doctor/reconcile_dgpu_panel.go:357`, `ryoku/hyprland/gpu.lua:10`, `ryoku/shell/deploy.sh:417`, `ryoku-gpu:426-427`.
**Arch couplings:**
- `wheel` in the polkit rule (`45-ryoku-gpu-mux.rules:13`).
- Kernel: `docs/power.md:9` measures on kernel 7.1. Debian kernel config: `CONFIG_ASUS_ARMOURY=m` is set in linux 7.2.11-1 (`debian/config/amd64/config`) and absent from 6.12.107-1 (trixie); `CONFIG_ASUS_NB_WMI=m` in both. On trixie's 6.12 only the legacy fallback path exists.
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs |
|---|---|---|---|---|---|---|---|---|
| linux (asus-armoury) | firmware-attributes path (`:36`) | linux-image-amd64 / linux-image-generic | 6.12.107-1 (no armoury) | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | 7.0.0-39.39 | armoury driver kernel (legacy fallback works on 6.12) |
| polkit | grant (`45-ryoku-gpu-mux.rules`) | polkitd, pkexec | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | JS rules (>=0.106) |

**As-is on Debian:** PARTIAL; script works, the polkit grant does not match a Debian user.
**Port steps:**
1. Ship unchanged to `/usr/bin/ryoku-gpu-mux`; rule to `/usr/share/polkit-1/rules.d/45-ryoku-gpu-mux.rules`.
2. Apply the group decision (cross-cutting fact 1): `isInGroup("wheel")` -> `isInGroup("sudo")`, or create `wheel`.
3. `Depends: pkexec`.
**Complexity:** Low.
**Issues / risks:** On trixie (6.12) the armoury path is absent; the legacy `asus-nb-wmi` node is the only source and the script's own comment says it "reports stale values on some firmware" (`ryoku-gpu-mux:17-19`). trixie-backports kernel 7.2.6 restores parity.

### 32-bit GPU drivers (`system/hardware/gpu/ryoku-gpu-lib32`)

**What it does:** Ensures `[multilib]` in `/etc/pacman.conf` (`:54-75`, calls `ryoku-pkg-multilib`), reads each GPU's DRM driver (`:80-89`), installs `lib32-mesa lib32-vulkan-icd-loader` plus `lib32-vulkan-radeon`/`lib32-vulkan-intel`/`lib32-nvidia-utils`/`lib32-vulkan-nouveau` (`:96-106`) with `sudo pacman -Syu --needed --noconfirm` (`:121-123`). Run by the Gaming bundle `requires: gpu-lib32` (`system/extras/ryostore-install:261-271`).
**Arch couplings:**
- `/etc/pacman.conf` `[multilib]` test (`:54-56`), `ryoku-pkg-multilib` (`:67-69`), `pacman -Syu` (`:123`), lib32-* names (`:96-105`).
- Comment says "The base install is 64-bit only" (`:6-7`), but `system/packages/hardware.packages:24,29,45` installs `lib32-vulkan-radeon`, `lib32-vulkan-intel`, `lib32-nvidia-utils` in the base install. Code and comment disagree.
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| lib32-mesa | GL baseline (`:96`) | libgl1-mesa-dri:i386, libglx-mesa0:i386, libegl-mesa0:i386 | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | must equal the amd64 mesa version (Multi-Arch: same) |
| lib32-vulkan-icd-loader | Vulkan loader (`:96`) | libvulkan1:i386 | 1.4.309.0-1 | - | 1.4.363.0-1 | 1.4.363.0-1 | 1.4.341.0-1 | any |
| lib32-vulkan-radeon / -intel / -nouveau | ICDs (`:101-104`) | mesa-vulkan-drivers:i386 (one package carries radv, anv and the other Mesa ICDs) | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | same as amd64 mesa |
| lib32-nvidia-utils | NVIDIA 32-bit (`:103`) | nvidia-driver-libs:i386 (+ nvidia-vulkan-icd:i386) | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | libnvidia-gl-580:i386 580.178.04 | must equal amd64 driver version |

**As-is on Debian:** NO.
**Port steps:**
1. Replace `ensure_multilib` with: `dpkg --print-foreign-architectures | grep -qx i386 || { sudo dpkg --add-architecture i386 && sudo apt-get update; }`.
2. Map packages: baseline `libgl1-mesa-dri:i386 libglx-mesa0:i386 libvulkan1:i386 mesa-vulkan-drivers:i386`; `amdgpu|radeon|i915|xe|nouveau` add nothing more (Mesa ICDs are all in `mesa-vulkan-drivers`); `nvidia` -> `nvidia-driver-libs:i386` (archive or NVIDIA CUDA repo, whichever supplied the amd64 driver; NVIDIA's flat debian13 repo publishes i386 debs version-locked to amd64).
3. Install with `sudo apt-get install -y <pkgs>` (no `-Syu`: apt resolves library upgrades itself, so the partial-upgrade reason at `:119-120` does not apply).
**Complexity:** Medium; trivial code, but i386 Mesa must track the amd64 Mesa source version (if amd64 Mesa comes from backports or a Ryoku build, the i386 build must come from the same place).
**Issues / risks:**
- glibc skew: an i386 closure resolved against a newer suite pulls `libc6:i386` that `libc6:amd64` Breaks. Any mixing of suites (sid NVIDIA, backports Mesa) must resolve i386 and amd64 from the same suite.

### NVIDIA driver installer (`system/hardware/drivers/nvidia.sh`)

**What it does:**
- Detects an NVIDIA display controller via `lspci` or sysfs vendor `0x10de` class `0x03*` (`:73-89`).
- Generation split (`:91-105`, `:164-201`):
  - **GSP cards (Turing and newer: GTX 16xx, RTX 20-50xx, RTX PRO, Quadro RTX, A/H/T/L datacenter)**, matched by an lspci name regex (`:96`): open kernel modules. Prefers the kernel-matched prebuilt `nvidia-open` (stock `linux`) or `<pkgbase>-nvidia-open` when `pacman -Si` finds it (`:116-122`, `:182-188`), else `nvidia-open-dkms` + `<kernel>-headers` (`:189-192`). Userspace `nvidia-utils libva-nvidia-driver` (+`lib32-nvidia-utils` when multilib is on, `:177-181`).
  - **Kepler (GK chip in the lspci name)** (`:102-105`): AUR `nvidia-470xx-dkms` + `libva-nvidia-driver` + headers (+`lib32-nvidia-470xx-utils`) (`:193-196`).
  - **Everything else (Maxwell, Pascal, Volta)**: AUR `nvidia-580xx-dkms` + `libva-nvidia-driver` + headers (+`lib32-nvidia-580xx-utils`) (`:197-201`).
  - An already-installed module package is kept (`:132-134`, `:150-152`).
- Kernel list from `/usr/lib/modules/*/pkgbase` (`:155-162`), headers `${pkgbase}-headers` (`:175-176`), multilib from `pacman-conf --repo-list` (`:178`).
- Only when `modinfo -k <kver> nvidia` succeeds for some installed kernel (`:139-148`): writes `/etc/modprobe.d/nvidia.conf` = `options nvidia_drm modeset=1 fbdev=1`, `options nvidia NVreg_PreserveVideoMemoryAllocations=1`, `blacklist nouveau`, `options nouveau modeset=0` (`:214-221`) and `/etc/mkinitcpio.conf.d/nvidia.conf` = `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` (`:223-225`); otherwise removes both (`:226-229`).
- `systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service` (`:235-238`).
- Writes `/etc/pacman.d/hooks/ryoku-nvidia.hook` (Path `usr/lib/modules/*/vmlinuz`, Package `nvidia*`, `lib32-nvidia*`, `libva-nvidia-driver`, `linux-*-nvidia*`; `NeedsTargets`; `Exec=/usr/bin/ryoku-nvidia-guard`) (`:251-276`).
- Run by the installer in the target chroot via `arch-chroot ... bash /root/ryoku-driver-nvidia.sh` (`installation/backend/lib/drivers.sh:18-29`); the installer also adds `nvidia_drm.modeset=1` to the kernel cmdline for the `amd-nvidia` profile (`installation/backend/lib/bootloader.sh:265`). The `ryoku doctor` mirrors all of this in Go: `ryoku/cli/internal/doctor/reconcile_hardware.go:200-206` (verbatim modprobe/mkinitcpio content), `:216-222` (Kepler 580xx removal via `pacman -R`), `:270-275` (pacman package list), `:300-370` (modeset reconcile, `limine-mkinitcpio`/`mkinitcpio -P`), `:370-430` (pacman hook), `:435-470` (sleep units under `/usr/lib/systemd/system`).
- Wayland env (`ryoku/hyprland/modules/env.lua:25-41`): when `/proc/driver/nvidia/version` exists and the panel is not on an Intel/AMD iGPU, sets `LIBVA_DRIVER_NAME=nvidia`, `NVD_BACKEND=direct`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__GL_GSYNC_ALLOWED=0`, `__GL_VRR_ALLOWED=0`; otherwise `AQ_NO_MODIFIERS=1`. No `GBM_BACKEND` is set.
- No GPU switcher daemon: no `optimus-manager`, `envycontrol`, `supergfxctl`, `switcheroo-control` or `prime-run` anywhere in the repo (grep, 2026-10-17). GPU selection is `AQ_DRM_DEVICES` + the hardware MUX only.

**Arch couplings:**
- `pacman -Qq/-Si/-S`, `pacman-conf` (`:58`, `:68`, `:119-121`, `:133`, `:178`).
- AUR-only legacy branches `nvidia-470xx-dkms`, `nvidia-580xx-dkms` (`:195`, `:199`); the ISO pre-bakes them (`installation/iso/offline-repo.sh:196-208`).
- `/usr/lib/modules/*/pkgbase` (Arch kernel packaging writes this file; Debian kernels do not) (`:156`), so on Debian the list falls back to `kernels=(linux)` and headers `linux-headers` (`:161`, `:176`), both wrong names.
- `/etc/mkinitcpio.conf.d/nvidia.conf` (`:223`), `/etc/pacman.d/hooks/` (`:252-276`).
- Prebuilt-module naming convention `nvidia-open` / `<pkgbase>-nvidia-open` (`:118`).
- `modinfo -k "$kv" nvidia` (`:145`): see risk below.

**Dependencies (Arch -> Debian archive / NVIDIA CUDA repo / Ubuntu):**

| Arch pkg (Arch version) | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs |
|---|---|---|---|---|---|---|---|---|
| nvidia-open 615.78.08 (prebuilt) | Turing+ module (`:118`, `:187`) | Debian: none prebuilt. Ubuntu: `linux-modules-nvidia-580-open-generic` (Canonical-signed) | - | - | - | - | 7.0.0-39.39+2 | Blackwell (RTX 50xx) needs >= 570; Wayland explicit sync needs >= 555 |
| nvidia-open-dkms 615.78.08 | Turing+ DKMS (`:191`) | Debian archive `nvidia-open-kernel-dkms` (contrib) / NVIDIA repo `nvidia-kernel-open-dkms` / Ubuntu `nvidia-dkms-<br>-open` | 550.163.01-2 | 550.163.01-4~bpo13+1 | - (not in testing) | 550.163.01-4 | nvidia-dkms-580-open 580.178.04 | same |
| (meta) | userspace + module | Debian `nvidia-driver` (550) / NVIDIA repo `nvidia-open` (590.44.01 .. 615.71.09) / Ubuntu `nvidia-driver-<br>-open` | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | -580-open 580.178.04; -595-open 595.99.02; -610-open 610.57.04 | |
| nvidia-utils | GL/EGL/Vulkan userspace (`:180`) | nvidia-driver-libs + nvidia-vulkan-icd + nvidia-smi (Ubuntu: nvidia-utils-<br>, libnvidia-gl-<br>) | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | 580.178.04 | match module |
| lib32-nvidia-utils | 32-bit (`:181`) | nvidia-driver-libs:i386 | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | libnvidia-gl-580:i386 | match amd64 |
| libva-nvidia-driver 0.0.18 | VA-API (`:152`, `:180`; `NVD_BACKEND` env.lua:33) | nvidia-vaapi-driver | 0.0.13-1 | 0.0.18-1~bpo13+1 | 0.0.18-1 | 0.0.18-1 | 0.0.14-1 | NVD_BACKEND=direct (all) |
| (GSP firmware inside nvidia-utils) | open modules | firmware-nvidia-gsp (non-free-firmware); Ubuntu nvidia-firmware-<br>-<ver> | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | nvidia-firmware-580-580.178.04 | match module |
| nvidia-580xx-dkms 580.178.04 (AUR) | Maxwell/Pascal/Volta (`:199`) | Debian `nvidia-kernel-dkms` (550 proprietary, supports Maxwell+) / Ubuntu `nvidia-driver-580` | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | 580.178.04 | 580 is NVIDIA's last branch for these (the CUDA debian13 repo starts at 590) |
| nvidia-470xx-dkms 470.256.02 (AUR) | Kepler (`:195`) | nvidia-tesla-470-driver | - | - | - | 470.256.02-10 | - | none on trixie/forky/resolute |
| (suspend units in nvidia-utils) | `systemctl enable` (`:237`) | nvidia-suspend-common (Debian archive); Ubuntu ships them in nvidia-kernel-common-<br> | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | nvidia-kernel-common-580 580.178.04 | |
| egl-wayland / egl-gbm | Wayland EGL | libnvidia-egl-wayland1, libnvidia-egl-gbm1 | 1:1.1.18-1 / 1.1.2.1-1 | - | 1:1.1.21-1 / 1.1.2.1-1 | same | 1:1.1.21-1 / 1.1.2.1-1 | |
| linux-headers | DKMS (`:176`) | linux-headers-amd64 (meta) or linux-headers-<kver>; Ubuntu linux-headers-generic | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | 7.0.0-39.39 | per installed kernel |
| dkms 3.4.4 | module builds | dkms (NVIDIA repo ships dkms 3.4.3-1) | 3.2.2-1~deb13u1 | - | 3.2.2-1 | 3.2.2-1 | 3.2.2-1ubuntu1 | |
| mkinitcpio | early KMS (`:223`) | initramfs-tools (`update-initramfs`) | 0.148.4 | - | 0.151 | 0.151 | 0.151ubuntu1 | |
| pciutils, kmod | `lspci`, `modinfo` | pciutils, kmod | 1:3.13.0-2 / 34.2-2 | - | 1:3.15.0-2 / 34.2-2+b2 | same | 1:3.14.0-1build2 / 34.2-2ubuntu2 | |
| (none) | generation detection helper | nvidia-detect | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | ubuntu-drivers-common 1:0.10.9 | |

NVIDIA's own repo (`https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/`, also `debian12`, `ubuntu2604`, `ubuntu2404`; all return 200 on 2026-10-17) carries for debian13: `nvidia-open`, `nvidia-driver`, `nvidia-kernel-open-dkms`, `nvidia-kernel-dkms`, `cuda-drivers`, `nvidia-driver-libs`, `nvidia-suspend-common`, `firmware-nvidia-gsp`, `nvidia-settings`, `nvidia-modprobe`, each 590.44.01-1 .. 615.71.09-2 (10 versions), `nvidia-driver-pinning-{590,595,610,615}` branch pins, `libnvidia-egl-gbm1` 1.1.4-2, `libnvidia-egl-wayland1` 1:1.1.21-1, `libnvidia-egl-wayland21` 1.0.2-1, `dkms` 3.4.3-1, keyring `cuda-keyring_1.1-1_all.deb`. Package sets: open = `nvidia-open` (+ `nvidia-kernel-open-dkms`), proprietary = `nvidia-driver nvidia-kernel-dkms`, i386 = `nvidia-driver-libs:i386` (do not list `nvidia-suspend-common`/`nvidia-kernel-common` explicitly: NVIDIA's `nvidia-driver` Conflicts `nvidia-suspend-common`, `nvidia-kernel-support` Conflicts `nvidia-kernel-common`; NVIDIA repo's dkms 3.4.x outranks Debian's 3.2.2).

**Debian archive packaging facts that change Ryoku's logic:**
- Module rename: Debian's DKMS packages install the modules under renamed files. `nvidia-open-gpu-kernel-modules` 550.163.01-2: `module = nvidia-$(current)$(LINUX_KMOD_VARIANT)` = `nvidia-current-open` (`debian/rules:30-32`, `rules.defs:1`) and `DEST_MODULE_NAME[0]="$PACKAGE_NAME"`, `[1]="$PACKAGE_NAME-modeset"`, `[2]="$PACKAGE_NAME-drm"` (`debian/nvidia-kernel-dkms.dkms.in`); the proprietary flavor is `nvidia-current`. Loading goes through `install nvidia modprobe -i nvidia-current $CMDLINE_OPTS` lines in `/etc/nvidia/nvidia-modprobe.conf` (`nvidia-modprobe.conf.in`), selected by `update-alternatives` (`nvidia-alternative.postinst.in:86-94`). `modinfo -k <kver> nvidia` resolves a module file or a config `alias`, not an `install` command, so Ryoku's probe (`nvidia.sh:145`, `ryoku-nvidia-guard:100`, `reconcile_hardware.go` `nvidiaModuleOnDisk`) does not find the Debian archive module. (Not verified on hardware; inferred from kmod lookup rules.) NVIDIA-repo and Ubuntu modules are named `nvidia.ko`.
- modeset: Debian 550 ships only commented options (`nvidia-options.conf.in`: `#options #MODULE# NVreg_PreserveVideoMemoryAllocations=1`, `#... NVreg_EnableS0ixPowerManagement=1`) linked to `/etc/modprobe.d/nvidia-options.conf`, a `blacklist nouveau` file (`nvidia-blacklists-nouveau.conf`, with "run update-initramfs -u after editing"), and `nvidia-drm` in modules-load (`nvidia-load.conf.in`). Nothing sets `modeset=1`/`fbdev=1`, so Ryoku's drop-in is still required. Options written for `nvidia_drm`/`nvidia` reach the renamed modules only through `$CMDLINE_OPTS` of the `install` lines (kmod passes config options of the requested name). Writing `options nvidia-drm modeset=1 fbdev=1` to `/etc/modprobe.d/nvidia-options.conf` and running `update-initramfs -u` works with NVIDIA's repo debs.
- Suspend: `nvidia-suspend-common` installs `nvidia-suspend/hibernate/resume.service` to `/usr/lib/systemd/system/`, `/usr/lib/systemd/system-sleep/nvidia`, `/usr/bin/nvidia-sleep.sh` (`nvidia-suspend-common.install`), plus a drop-in `Environment=SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false` (`systemd-suspend.service.d/nvidia.conf`; changelog 535.161.08-3); the services are not started on install (changelog 525.147.05). Ryoku's `systemctl enable` line works unchanged.
- `nvidia-driver` (Debian archive) Depends `xserver-xorg-video-nvidia` (debian/control), pulling Xorg; a Wayland-only set is `nvidia-kernel-dkms|nvidia-open-kernel-dkms nvidia-driver-libs nvidia-vulkan-icd nvidia-smi nvidia-suspend-common firmware-nvidia-gsp libnvidia-egl-wayland1 libnvidia-egl-gbm1` (exact closure not resolved here).
- Version ceiling: every Debian suite carries 550.163.01 (experimental 555.58.02). 550 has no Blackwell (RTX 50xx needs >= 570) and no `linux-drm-syncobj-v1` explicit sync (>= 555), which Hyprland and niri use on NVIDIA. Arch ships 615.78.08. `nvidia-open-kernel-dkms` is currently missing from forky (testing) while present in sid.
- Kepler: no 470 driver on trixie, forky or resolute; sid has `nvidia-tesla-470-driver` 470.256.02-10. On those bases Kepler is nouveau-only.

**As-is on Debian:** NO.
**Port steps:**
1. Package manager layer: replace `pkg_installed` with `dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'`; `install_pkgs` with `apt-get install -y --no-install-recommends "${missing[@]}"` (prefix `sudo -n` when not root; offline: `-o Dir::Etc::sourcelist=<offline list>` instead of `--config "$RYOKU_PACMAN_CONF"`).
2. Kernel enumeration: replace `/usr/lib/modules/*/pkgbase` with `for d in /usr/lib/modules/*/; do kv=${d%/}; kv=${kv##*/}; headers+=("linux-headers-$kv"); done` (Debian) or `linux-headers-generic` (Ubuntu metapackage).
3. Multilib test (`:178`): `dpkg --print-foreign-architectures | grep -qx i386`.
4. Generation -> package map (choose a source, see question):
   - Debian archive: GSP -> `nvidia-open-kernel-dkms firmware-nvidia-gsp nvidia-driver-libs nvidia-vulkan-icd nvidia-vaapi-driver nvidia-suspend-common nvidia-smi`; Maxwell/Pascal/Volta -> same with `nvidia-kernel-dkms`; Kepler -> nothing (nouveau) on trixie/forky; i386 -> `nvidia-driver-libs:i386`. Requires `contrib non-free non-free-firmware` components. Blackwell cards get no working driver from this source.
   - NVIDIA CUDA repo (debian13): install `cuda-keyring_1.1-1_all.deb` from the repo URL; GSP -> `nvidia-open` (pulls `nvidia-kernel-open-dkms`); Maxwell/Pascal/Volta -> not available (repo starts at 590) -> fall back to Debian archive `nvidia-kernel-dkms` 550; optional branch pin `nvidia-driver-pinning-<br>`.
   - Ubuntu: `ubuntu-drivers install` (ubuntu-drivers-common 1:0.10.9) or explicit `nvidia-driver-<br>-open` + `linux-modules-nvidia-<br>-open-generic` (prebuilt, Canonical-signed: the analogue of Arch's prebuilt `nvidia-open`, so `prebuilt_for()` maps to this name); Pascal -> `nvidia-driver-580`; Kepler -> none.
   - GSP detection regex (`:96`) and Kepler regex (`:104`) read `lspci` names from pci.ids and work unchanged; `nvidia-detect` (Debian) is an alternative oracle.
5. Module probe (`:139-148`): accept any of `nvidia`, `nvidia-current`, `nvidia-current-open`: `modinfo -k "$kv" nvidia || modinfo -k "$kv" nvidia-current || modinfo -k "$kv" nvidia-current-open`, or test `find /usr/lib/modules/$kv -name 'nvidia*.ko*' -print -quit`.
6. Early KMS: replace `/etc/mkinitcpio.conf.d/nvidia.conf` with lines `nvidia`, `nvidia_modeset`, `nvidia_uvm`, `nvidia_drm` in `/etc/initramfs-tools/modules` (or a Ryoku-owned hook in `/usr/share/initramfs-tools/hooks/` calling `manual_add_modules` / `force_load`), keep `/etc/modprobe.d/nvidia.conf`, then `update-initramfs -u -k all`. For the Debian archive driver, list the renamed names or rely on the `install` aliases (verify on hardware). Remove the paths at `:228` accordingly.
7. Replace the pacman hook (`:251-276`) with: (a) `/etc/kernel/postinst.d/dkms-ryoku-nvidia-guard` (sorts after `/etc/kernel/postinst.d/dkms` and before `initramfs-tools` in `run-parts` C-locale order) for kernel installs; (b) a dpkg file trigger in the `ryoku-desktop` deb (`interest-noawait /usr/src` or explicit `interest-noawait` names) or an apt `DPkg::Post-Invoke` hook for driver-package changes. Debian already orders dkms before initramfs generation for a new kernel, which is the race the hook comment cites (`ryoku-nvidia-guard:81-83`).
8. Suspend units: unchanged `systemctl enable ...` (`:237`).
9. Port the Go doctor mirror (`reconcile_hardware.go:200-470`) with the same name/path changes (owned by the CLI port).
10. Secure Boot: Debian DKMS signs with `/var/lib/dkms/mok.key` and needs MOK enrolment; Ubuntu prebuilt modules are Canonical-signed. Ryoku itself refuses Secure Boot (`docs/installation-hardware.md:54-71`), so this only matters if the port's bootloader changes that.
**Complexity:** High; three driver sources with different names, module naming, initramfs mechanism and hook mechanism all change.
**Issues / risks:**
- Debian archive's 550 driver fails the parity goal on RTX 50xx (no driver) and on every NVIDIA card under Hyprland/niri (no explicit sync, flicker class bugs). Arch users get 615.
- The `modinfo nvidia` probe failing on Debian archive modules would make `nvidia.sh` delete the modeset drop-in (`:228`) and `ryoku-nvidia-guard` "heal" by restoring nouveau (`ryoku-nvidia-guard:121-125`) on a working system.
- `nvidia-open-kernel-dkms` absent from forky today; a forky/sid base can lose the open module at any time.
- `nvibrant` (screen vibrance, `ryoku/shell/quickshell/shell/services/Devices.qml:51`, from `system/packages/aur.packages`) is NVIDIA-only and AUR-only; upstream ships only a manylinux Python wheel (v1.3.0).
- DKMS on Debian builds on every kernel upgrade; trixie-backports/forky kernels are 7.2 while Debian's 550 package declares `LINUX_KMOD_TESTED = 6.15` (`nvidia-open-gpu-kernel-modules/debian/rules.defs`). Build success on 7.2 not verified.
- Initramfs size: Ryoku trims nouveau and its GSP blobs from mkinitcpio images (`system/boot/mkinitcpio/install/ryoku-gpu-trim`); initramfs-tools `MODULES=most` also includes nouveau plus its firmware. Owned by the boot port.
**Questions for the human:**
- NVIDIA driver source. (a) Debian archive non-free 550: signed by Debian, security-supported, but no RTX 50xx, no explicit sync, renamed modules. (b) NVIDIA CUDA repo (590-615, `nvidia-open`): Arch-equivalent versions and module names, but a third-party repo whose `dkms` overrides Debian's and which has no Maxwell/Pascal/Volta branch (those fall back to (a)). (c) Ubuntu base: `ubuntu-drivers` with prebuilt signed modules (closest to Arch's prebuilt `nvidia-open`), 580/595/610 branches, Pascal on 580.

### NVIDIA login-loop guard (`system/hardware/drivers/ryoku-nvidia-guard`)

**What it does:** Run by the pacman hook with changed targets on stdin (`:54-71`). If an NVIDIA module package is installed or nouveau is blacklisted (`:76-91`, `:118`), and nouveau is blacklisted while no installed kernel has an `nvidia` module (`:95-103`), deletes `/etc/modprobe.d/nvidia.conf` and `/etc/mkinitcpio.conf.d/nvidia.conf` (`:121-125`); rebuilds the initramfs after a heal, a driver change, or a kernel change on a DKMS box (`:131-135`) via `limine-mkinitcpio`, `mkinitcpio -P`, `dracut-rebuild` or `dracut --regenerate-all --force` (`:105-115`). Exits during installs when `90-mkinitcpio-install.hook.ryoku-off` exists (`:52`). Called by `ryoku/cli/internal/doctor/reconcile_hardware.go:403` (hook content).
**Arch couplings:** pacman package regexes (`:63-66`, `:77-78`, `:85`), `NeedsTargets` stdin protocol, `/etc/pacman.d/hooks` (`:35`, `:52`), mkinitcpio paths (`:34`), `limine-mkinitcpio` (`:106`), "SDDM login loop" assumption (`:3-15`).
**Dependencies:** kmod (`modinfo`), initramfs-tools; versions as in the NVIDIA table.
**As-is on Debian:** NO.
**Port steps:**
1. Package tests: `dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' | awk '$1=="ii"{print $2}' | grep -qE '^(nvidia-(open-)?kernel-dkms|nvidia-kernel-open-dkms|nvidia-tesla-[0-9]+-kernel-dkms|linux-modules-nvidia-.*|nvidia-dkms-[0-9]+(-open)?)$'`.
2. Targets: kernel hook gets the kernel version as `$1` (`/etc/kernel/postinst.d` protocol); dpkg trigger gets no list. Set `kernel_changed`/`driver_changed` from the hook type instead of stdin.
3. Probe: same three-name `modinfo` change as `nvidia.sh` step 5.
4. `rebuild_initramfs`: `update-initramfs -u -k all` (or `-k "$1"` from the kernel hook). Remove the mkinitcpio file path; delete `/etc/initramfs-tools/modules` NVIDIA lines on heal.
5. Install-time marker (`:52`): replace with whatever the Debian installer uses to defer initramfs builds (e.g. `INITRD=No` in `/etc/initramfs-tools/update-initramfs.conf` during install, or a Ryoku marker file).
**Complexity:** Medium.
**Issues / risks:** Logic gap that ports as-is: the heal fires only when **no** kernel has the module (`:121`); a failed DKMS build for the new kernel while the old kernel still has the module leaves the new kernel booting with nouveau blacklisted and no nvidia driver.

### AMD, Intel, Vulkan installers (`system/hardware/drivers/amd.sh`, `intel.sh`, `vulkan.sh`)

**What it does:** Each detects its hardware via `lspci` or `/sys/class/drm/card*/device/uevent` (`amd.sh:56-62`, `intel.sh:56-62`, `vulkan.sh:56-58`) and installs missing packages with `pacman -S --needed --noconfirm` (`amd.sh:43-54`): AMD `mesa vulkan-radeon` (`amd.sh:69`); Intel `intel-media-driver vpl-gpu-rt vulkan-intel` (`intel.sh:69`) and `sof-firmware` (`intel.sh:73`); any GPU `vulkan-icd-loader` (`vulkan.sh:65`). Offline mode uses `--config "$RYOKU_PACMAN_CONF"` (`amd.sh:38-41`).
**Arch couplings:** pacman, package names.
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| mesa (26.2.5) | GL (`amd.sh:69`) | libgl1-mesa-dri, libglx-mesa0, libegl-mesa0, mesa-va-drivers | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 (no mesa-va-drivers binary) | none stated |
| vulkan-radeon / vulkan-intel | RADV/ANV (`amd.sh:69`, `intel.sh:69`) | mesa-vulkan-drivers | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | |
| intel-media-driver | iHD VA-API (`intel.sh:69`) | intel-media-va-driver-non-free (non-free, with encoders) or intel-media-va-driver (main) | 25.2.3+ds1-1 | - | 26.2.4+ds1-1 | 26.2.4+ds1-1 | 26.1.2+ds1-1 | |
| vpl-gpu-rt | oneVPL runtime (`intel.sh:69`) | libmfx-gen1.2 (src onevpl-intel-gpu) | 25.1.4-1 | - | 26.3.3-1 | 26.3.3-1 | 26.1.2-1 | |
| sof-firmware | Intel DSP audio (`intel.sh:73`) | firmware-sof-signed | 2025.01-1 | - | 2026.09.1-1 | 2026.09.1-1 | 2025.12.2-1 | |
| vulkan-icd-loader | loader (`vulkan.sh:65`) | libvulkan1 | 1.4.309.0-1 | - | 1.4.363.0-1 | 1.4.363.0-1 | 1.4.341.0-1 | |
| amd-ucode / intel-ucode | microcode (`system/packages/hardware.packages:22,27`) | amd64-microcode / intel-microcode | 3.20250311.1 / 3.20251111.1~deb13u1 | - | 3.20251202.1 / 3.20260227.1 | same | 3.20251202.1ubuntu2 / 3.20260210.1ubuntu2 | |
| vulkan-swrast | VM ICD (`hardware.packages:50`) | mesa-vulkan-drivers (lavapipe) | as above | | | | | |
| linux-firmware | GPU firmware | firmware-amd-graphics, firmware-intel-graphics, firmware-misc-nonfree (Ubuntu: linux-firmware) | 20250410-2 | 20260916-1~bpo13+1 | 20260916-1 | 20260916-1 | 20260319.git217ca6e4.1ubuntu… | |

**As-is on Debian:** NO.
**Port steps:**
1. Same `dpkg-query`/`apt-get install -y` substitution as `nvidia.sh` step 1.
2. Name map: `mesa` -> `libgl1-mesa-dri libglx-mesa0 libegl-mesa0 mesa-va-drivers`; `vulkan-radeon`/`vulkan-intel` -> `mesa-vulkan-drivers`; `intel-media-driver` -> `intel-media-va-driver-non-free`; `vpl-gpu-rt` -> `libmfx-gen1.2`; `sof-firmware` -> `firmware-sof-signed`; `vulkan-icd-loader` -> `libvulkan1`. Add `firmware-amd-graphics` to amd.sh (Debian splits AMD GPU firmware out of the kernel firmware, without it amdgpu does not initialize).
**Complexity:** Low.
**Issues / risks:** trixie Mesa 25.0.7 is ~1.5 years behind Arch 26.2.5; trixie-backports has 26.1.6. The Mesa source suite decision is shared with the graphics-stack port.

### Laptop classifier (`system/hardware/power/ryoku-hw-laptop`)

**What it does:** Laptop if DMI `chassis_type` in 8/9/10/11/14/30/31/32, desktop if 3-7/13/23-25, else a `BAT*` of type Battery, a "Lid Switch" input device or `/proc/acpi/button/lid/*` (`:5-35`).
**Call sites:** `ryoku-gpu-detect:258-266`, power and idle helpers.
**Arch couplings:** none.
**Dependencies:** grep, bash (essential on Debian).
**As-is on Debian:** YES.
**Port steps:** ship unchanged.
**Complexity:** Low.

### Idle timers (`system/hardware/power/ryoku-idle`)

**What it does:** Renders `~/.config/ryoku/hypridle.conf` from `power.json` with battery/AC listener pairs (`:156-214`), `lock_cmd = ryoku-shell lock` (`:197`), dim via `brightnessctl -s set 20%`/`brightnessctl -r` (`:204-205`), screen-off via `ryoku wm act output.power` (`:62`, `:210-211`), suspend via `ryoku-shell suspend` (`:213-214`); restarts hypridle with `setsid hypridle -c "$IDLE_CONF"` (`:252-260`).
**Call sites:** `ryoku/hub/backend/cputune.go:317`, `ryoku/hub/quickshell/schema/GpuPage.js:272,281`, `ryoku/cli/internal/updater/update.go:949-981`, `ryoku-power-cutover` (9 uses).
**Arch couplings:** none in code; `hypridle` is a hard depend of `ryoku-desktop` (`release/packages/ryoku-desktop/PKGBUILD:195-200`).
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| hypridle 0.1.8 | idle daemon (`:255`) | hypridle | - | 0.1.8-1~bpo13+1 | 0.1.8-1+b1 | 0.1.8-1+b1 | 0.1.7-2 | listener/on-resume syntax (0.1.x) |
| brightnessctl | dim (`:204`) | brightnessctl | 0.5.1-3.1+b1 | - | 0.5.1-3.1+b2 | same | 0.5.1-3.1build1 | `-s`/`-r` (0.5) |
| jq | power.json | jq | 1.7.1-6+deb13u3 | - | 1.8.2-1 | 1.8.2-1 | 1.8.1-4ubuntu2 | |

**As-is on Debian:** PARTIAL; needs hypridle from trixie-backports on trixie, or the Ryoku-built Hyprland stack.
**Port steps:** ship unchanged; `Depends: hypridle, brightnessctl, jq`. On trixie, either enable trixie-backports or build hypridle with the Hyprland deb stack.
**Complexity:** Low.
**Issues / risks:** trixie-backports hypridle links the backports hyprlang/hyprutils; if the port builds its own Hyprland stack, hypridle must come from that same stack to avoid soname skew.

### Power knobs (`system/hardware/power/ryoku-power`, `47-ryoku-power.rules`)

**What it does:** Per-profile CPU settings stored in `~/.config/ryoku/power.json`, applied on top of power-profiles-daemon's active profile (`powerprofilesctl get`, `:442-444`, `:558-559`, `:570`, `:677-678`); writes `/sys/firmware/acpi/platform_profile` (`:39`), `/sys/devices/system/cpu/cpu*/cpufreq/{scaling_governor,energy_performance_preference,scaling_max_freq}` (`:270-306`), battery `charge_control_end_threshold` (`:145`), `/sys/module/pcie_aspm/parameters/policy` (`:36`, `:194-253`); privileged writes re-exec via pkexec (18 pkexec references); `idle get|set` for ryoku-idle. Polkit grants `/usr/bin/ryoku-power` (`47-ryoku-power.rules:10-16`). `ryoku-desktop.install:52-64` enables `power-profiles-daemon.service` once.
**Arch couplings:** `wheel` (`47-ryoku-power.rules:13`). Kernel knobs are generic. Debian 6.12 config has `CONFIG_PCIEASPM=y`, `CONFIG_PCIEASPM_DEFAULT=y`.
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| power-profiles-daemon 0.30 | `powerprofilesctl` (`:442`) | power-profiles-daemon | 0.30-1.1 | - | 0.30-2+b1 | 0.30-2+b1 | 0.30-2 | 0.30 (same as Arch) |
| jq | config (35 uses) | jq | 1.7.1-6+deb13u3 | - | 1.8.2-1 | 1.8.2-1 | 1.8.1-4ubuntu2 | |
| polkit | grant | polkitd, pkexec | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | |

**As-is on Debian:** PARTIAL (group).
**Port steps:** ship unchanged; group decision for the rule; `Depends: power-profiles-daemon, pkexec, jq`; enable `power-profiles-daemon.service` in `postinst` (Debian's package enables it itself via deb-systemd-helper).
**Complexity:** Low.
**Issues / risks:** `power-profiles-daemon` Conflicts with `tlp` and `tuned-ppd` on Debian/Ubuntu; Ubuntu desktop images may ship `tuned`/`tuned-ppd` instead (not verified for 26.04). `/sys/firmware/acpi/platform_profile` multi-handler behaviour differs on 6.12 vs 7.x (the class interface `/sys/class/platform-profile` arrived after 6.12); `docs/power.md` measurements are on kernel 7.1 (`docs/power.md:9`).

### Power-policy package cutover (`system/hardware/power/ryoku-power-cutover`, `94-ryoku-power-cutover-prepare.hook`, `95-ryoku-power-cutover.hook`)

**What it does:** Session-lifecycle and package-adoption boundary (`system/hardware/README.md:90-101`). libalpm `PreTransaction` hook on Path `usr/bin/ryoku-clamshell` runs `ryoku-power-cutover prepare-package` with `AbortOnFail` (`94-ryoku-power-cutover-prepare.hook:1-12`); `PostTransaction` hook runs `ryoku-power-cutover package` (`95-ryoku-power-cutover.hook:1-11`); the post half execs a staged copy `/run/ryoku-power-cutover` written by the pre half (`ryoku-power-cutover:1689-1700`). The package scriptlet takes a durable sleep block with `systemd-run ... systemd-inhibit --what=sleep --mode=block` before extraction (`release/packages/ryoku-desktop/ryoku-desktop.install:81-114`) and, on the first transaction that installs the hooks, schedules `ryoku-power-cutover package-deferred` via `systemd-run` (`:115-140`), which polls until `/var/lib/pacman/db.lck` no longer exists (`ryoku-power-cutover:957-970`). Uses `systemctl` (83), `systemd-run` (19), `ryoku-shell` (19), `ryoku-clamshell` (16), `flock` (15), `loginctl` (14), `systemd-inhibit` (10), state `/var/lib/ryoku/power-cutover-hook-active`, `/run/ryoku-power-cutover.sessions`, `/run/lock/ryoku-power-cutover.lock` (`:9-26`, `:908`). Hook files install to `/usr/share/libalpm/hooks/` (`PKGBUILD:696-699`).
**Call sites:** `ryoku/cli/internal/updater/update.go:949-1003`, session entries, `ryoku-desktop.install:123-137`.
**Arch couplings:**
- libalpm hook files and semantics (Pre/PostTransaction around the whole transaction, `AbortOnFail`, Path trigger).
- `/var/lib/pacman/db.lck` existence as "transaction finished" (`:960`).
- The "first install cannot run its own hooks" workaround (`ryoku-desktop.install:77-81`, `:115-120`) exists only because libalpm loads hooks before extraction.
**Dependencies:** systemd (systemctl, systemd-run, systemd-inhibit, loginctl: package `systemd` 257.13-1~deb13u1 / forky 262-1 / sid 262.1-1 / resolute 259.9-0ubuntu0.1), util-linux (`flock`, 2.41.5-0+deb13u1 / 2.42.4-1 / 2.41.3-3ubuntu2.3), jq, procps (`pgrep`).
**As-is on Debian:** NO.
**Port steps:**
1. Map the hook pair to Debian maintainer scripts of the package that ships `/usr/bin/ryoku-clamshell`:
   - `prerm` (`upgrade`/`remove`, old package's script, old files still on disk) -> `ryoku-power-cutover prepare-package` (matches "staged copy in /run is the pre-upgrade code", `:1690-1693`); `preinst install` -> the same from the new package plus the sleep block now in `_pre_upgrade_power_guard`. A non-zero exit aborts the unpack (the `AbortOnFail` equivalent).
   - `postinst configure` and `postrm remove` -> `ryoku-power-cutover package`.
   - The deferred path (`package-deferred`) is unnecessary for the first install because maintainer scripts of the new package do run in that same dpkg invocation.
2. If transaction-level timing is required (pacman's PostTransaction runs after **all** packages; dpkg may configure `ryoku-desktop` before `ryoku-shell`), use apt hooks instead: `DPkg::Pre-Install-Pkgs` (receives the .deb list and `**REMOVE**` lines on stdin with `DPkg::Tools::Options::<cmd>::Version "3"`; filter for the package owning ryoku-clamshell, non-zero exit aborts apt) and `DPkg::Post-Invoke` (runs after dpkg finishes, gated by a marker the pre half wrote). These only fire for apt-driven runs, not plain `dpkg -i`.
3. If any deferred wait remains, replace the `db.lck` test (`:960`): dpkg/apt hold fcntl locks on files that always exist (`/var/lib/dpkg/lock-frontend`, `/var/lib/dpkg/lock`), and `flock(1)` uses flock(2) which does not see fcntl locks. Use `fuser -s /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock` (psmisc 23.7-2) or `lslocks -n -o PATH | grep -q /var/lib/dpkg/lock`.
4. Install nothing to `/usr/share/libalpm/hooks/`.
**Complexity:** High; the script itself is portable, the package-transaction contract around it is pacman-specific and has no exact dpkg equivalent.
**Issues / risks:** dpkg configure ordering within one apt run is not a "post transaction" guarantee; a cutover run from `postinst` can see a not-yet-configured `ryoku-shell`. Unattended-upgrades runs dpkg without a user TTY, same as pacman hooks (no change).

### Clamshell and logind drop-in (`system/hardware/power/ryoku-clamshell`, `logind-ryoku-lid.conf`)

**What it does:** Holds a login1 `handle-lid-switch` inhibitor while the session is active (`systemd-inhibit`, 5 uses), follows login1 owner restarts with `dbus-monitor --system` on `NameOwnerChanged` for `org.freedesktop.login1` (`:605-665`), watches AC/display with `udevadm monitor --udev` (`:822-830`), reads lid state from `/proc/acpi/button/lid/*/state` (`:30`, `:204`) and UPower `LidIsClosed` via `busctl` (`:43`, `:220-221`), `loginctl show-session` (`:262`). logind drop-in: `HandleLidSwitch=suspend`, `HandleLidSwitchExternalPower=suspend`, `HandleLidSwitchDocked=ignore`, `InhibitDelayMaxSec=15` installed to `/etc/systemd/logind.conf.d/10-ryoku-lid.conf` (`logind-ryoku-lid.conf:9-17`, `PKGBUILD:694-695`).
**Call sites:** `ryoku/niri/lid.kdl:6,9`, `ryoku/cli/internal/updater/update.go:949-1003`, `ryoku-power-cutover`.
**Arch couplings:** none.
**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| dbus | `dbus-monitor` (`:632`) | dbus-bin | 1.16.2-2 | - | 1.16.2-8 | 1.16.2-8 | 1.16.2-2ubuntu4 | |
| systemd | busctl, loginctl, systemd-inhibit, udevadm | systemd, udev | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | |
| upower | LidIsClosed (`:220`) | upower | 1.90.9-1 | - | 1.91.5-1 | 1.91.5-1 | 1.91.1-1 | |
| jq | state | jq | (above) | | | | | |

**As-is on Debian:** YES.
**Port steps:** ship unchanged; drop-in under `/etc/systemd/logind.conf.d/` is read by Debian's logind 257 (a conffile in the deb; `/usr/lib/systemd/logind.conf.d/` is the vendor alternative).
**Complexity:** Low.
**Issues / risks:** `/proc/acpi/button/lid` requires the `button` driver (built into Debian kernels); not checked on every laptop.

### Game Mode system tune (`system/hardware/power/ryoku-game-tune`, `53-ryoku-game-tune.rules`)

**What it does:** Saves then writes sysctls `kernel/nmi_watchdog 0`, `kernel/split_lock_mitigate 0`, `kernel/sched_energy_aware 0`, `vm/compaction_proactiveness 0`, `vm/page_lock_unfairness 1`, `vm/swappiness 10` (`:100-106`) and disables deep `cpuidle` states above a latency floor (`:166-173`); state in `/run/ryoku/game-tune.saved`; pkexec re-exec (`:62`). Called by `ryoku/shell/scripts/ryoku-cmd-game-mode:38`.
**Arch couplings:** `wheel` (`53-ryoku-game-tune.rules:16`); the header asserts "already right on a stock Arch install": NVMe scheduler `none`, THP `always`, `vm.max_map_count` raised by Arch's `filesystem` package (`:12-15`).
**Dependencies:** procps (`sysctl`), polkit/pkexec (versions above).
**As-is on Debian:** PARTIAL.
**Port steps:** ship unchanged with the group decision. Debian's kernel config has `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y` (linux 6.12.107-1 `debian/config/config:6781`), so the THP assumption holds. `vm.max_map_count`: no Debian package found raising it (not in systemd v257 `sysctl.d`; not checked in every package); to match Arch ship `/usr/lib/sysctl.d/10-ryoku-map-count.conf` with `vm.max_map_count = 1048576`.
**Complexity:** Low.

### Backlight helpers (`system/hardware/display/ryoku-hw-backlight`, `ryoku-hw-backlight-fix`, `90-ryoku-backlight.rules`)

**What it does:** `ryoku-hw-backlight` prints the backlight device driving the connected internal panel, with fallbacks `amdgpu_bl*`, `intel_backlight`, `acpi_video*`, `nvidia_wmi_ec_backlight` (sysfs only). `ryoku-hw-backlight-fix` adds `acpi_backlight=native` for ASUS AMD+NVIDIA panels via `/etc/limine-entry-tool.d/ryoku-backlight.conf` (`:15-16`, `:39`) and regenerates with `limine-mkinitcpio` / `limine-update` (`:77-85`, `:155-161`); run by the installer (`installation/backend/lib/drivers.sh:31-41`) and `ryoku-desktop.install` `_backlight_fix`. The udev rule runs `/usr/bin/chgrp video` and `/usr/bin/chmod g+w` on `/sys/class/backlight/%k/brightness` (`90-ryoku-backlight.rules`).
**Arch couplings:** `limine-entry-tool` drop-in directory and `limine-mkinitcpio`/`limine-update` (Arch/CachyOS tools). Kernel: `CONFIG_NVIDIA_WMI_EC_BACKLIGHT=m` in Debian 6.12 and 7.2.
**Dependencies:** coreutils (`/usr/bin/chgrp` resolves on merged-/usr Debian), the bootloader's cmdline tooling.
**As-is on Debian:** PARTIAL (`ryoku-hw-backlight` and the rule YES; `-fix` NO).
**Port steps:**
1. Ship `ryoku-hw-backlight` and the rule unchanged.
2. Rewrite `ryoku-hw-backlight-fix`'s drop-in + regen for the port's bootloader: GRUB `/etc/default/grub.d/ryoku-backlight.cfg` with `GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT acpi_backlight=native"` + `update-grub`; systemd-boot/UKI `/etc/kernel/cmdline` + `kernel-install`; Limine on Debian depends on the boot port.
**Complexity:** Medium (depends on the bootloader decision owned by the boot port).

### Audio helpers (`system/hardware/audio/*`)

**What it does:**
- `ryoku-mic`: caps the default source at its Base Volume using `pactl list sources`, `pactl get-default-source`, `pactl set-source-volume` (whole file). Launched from `ryoku/hyprland/modules/autostart.lua:62`, `ryoku/niri/autostart.kdl:52`.
- `ryoku-volume`: `wpctl get-volume/set-volume -l` with 5% grid and 100/150% cap from `shell.json` `.qsbar.audioBoost` via `jq`. Bound at `ryoku/hyprland/modules/binds.lua:117-120`, `ryoku/wm/niri/config_binds.go:172-173`, `VolumePanel.qml:19`.
- `ryoku-bt-audio`: PipeWire Bluetooth profile helper (`pactl`, `bluetoothctl`, `jq`); autostart `autostart.lua:46`, `autostart.kdl:37`.
- `ryoku-restart-audio`: `systemctl --user restart wireplumber pipewire pipewire-pulse` with kill fallback (`:7-15`), then `sudo -n usbreset BBB/DDD` for a USB audio device (`:46-48`). Called by `ryoku/cli/internal/doctor/reconcile_audioservice.go:52-61`, `binds.lua:125`, `config_binds.go:168`.
- `70-ryoku-maono.rules`: `uaccess` on vendor `352f` hidraw/usb.
- `99-ryoku-audio-powersave.conf`: `options snd_hda_intel power_save=0 power_save_controller=N` to `/usr/lib/modprobe.d/` (`PKGBUILD:593-594`).
**Arch couplings:** none, except `sudo -n usbreset` requires a NOPASSWD sudoers rule that Ryoku does not ship (no sudoers file in the repo besides the installer's transient AUR drop-in, `installation/backend/lib/aur.sh:56-60`); without it the reset step fails on Arch too.
**Dependencies:**

| Arch pkg | Used for | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| libpulse | `pactl` | pulseaudio-utils | 17.0+dfsg1-2+b1 | - | 17.0+dfsg1-3 | same | 1:17.0+dfsg1-2ubuntu4 | `get-default-source` (>=15) |
| wireplumber | `wpctl` | wireplumber | 0.5.8-2 | 0.5.12-1~bpo13+1 | 0.5.18-1 | 0.5.18-1 | 0.5.13-1ubuntu1.1 | `set-volume -l` (0.4.x+) |
| pipewire, pipewire-pulse | services | pipewire, pipewire-pulse | 1.4.2-1 | 1.6.9-2~bpo13+1 | 1.6.9-2 | 1.6.9-2 | 1.6.2-1ubuntu1.3 | Arch 1.6.9 |
| bluez-utils | `bluetoothctl` | bluez | 5.82-1.1 | - | 5.87-5 | 5.87-5 | 5.85-4ubuntu0.4 | |
| usbutils | `usbreset` | usbutils (ships `/usr/bin/usbreset`) | 1:018-2 | - | 1:019-1+b1 | same | 1:019-1 | |

**As-is on Debian:** PARTIAL (same `usbreset` limitation as Arch).
**Port steps:** ship unchanged; `Depends: pulseaudio-utils, wireplumber, pipewire-pulse, bluez, usbutils, jq`.
**Complexity:** Low.

### Bluetooth helpers (`system/hardware/bluetooth/*`)

**What it does:** `ryoku-bluetooth-tune` rewrites `/etc/bluetooth/main.conf` keys `General:Experimental=true`, `FastConnectable=true`, `JustWorksRepairing=always`, `MultiProfile=multiple`, `Policy:AutoEnable=true` in place (`:29-60`), run by `ryoku-desktop.install:148-151` with `systemctl try-restart bluetooth.service`. `ryoku-bluetooth-reset.service` (user unit, `WantedBy=ryoku-session.target`) runs `/usr/bin/systemctl restart bluetooth.service` once per session, authorized by `54-ryoku-bluetooth-a2dp.rules` (`org.freedesktop.systemd1.manage-units` for unit `bluetooth.service`, `isInGroup("wheel")`, no `active`/`local` check). `99-ryoku-bt-autosuspend.conf` = `options btusb enable_autosuspend=0` (`/usr/lib/modprobe.d/`, `PKGBUILD:627-628`).
**Arch couplings:** `wheel`; pacman's `.pacnew` model for `main.conf`.
**Dependencies:** bluez 5.82-1.1 / forky 5.87-5 / resolute 5.85-4ubuntu0.4 (Arch 5.87).
**As-is on Debian:** PARTIAL.
**Port steps:** ship unchanged with the group decision. `/etc/bluetooth/main.conf` is a dpkg conffile of `bluez`; after Ryoku edits it, a `bluez` upgrade that changes the shipped file prompts (interactive) or keeps the local file under `--force-confold`/unattended defaults.
**Complexity:** Low.
**Issues / risks:** The a2dp rule lets any wheel/sudo member (including inactive or remote sessions) restart `bluetooth.service` without a password (`54-ryoku-bluetooth-a2dp.rules`: no `subject.active`/`subject.local`).

### Network helpers (`system/hardware/network/*`)

**What it does:**
- `ryoku-dns`: writes `/etc/NetworkManager/conf.d/20-ryoku-dns.conf` global DNS and reloads NetworkManager (`:4`, `nmcli`, `systemctl`); pkexec re-exec (`:15`). Polkit rule matches **any** program path ending in `ryoku-dns` (`50-ryoku-dns.rules:10`). Called by `ryoku/shell/ipc/network.go:861-875`.
- `ryoku-wifi-regdom`: persists the country in `/etc/conf.d/wireless-regdom` (the Arch `wireless-regdb` backup file sourced by its udev `85-regulatory.rules` -> `set-wireless-regdom`) (`:10-14`, `:32`, `:57-86`) and in `/etc/iwd/main.conf` `[General] Country` + `[Rank] BandModifier5GHz` (`:15-18`, `:162`, `:179`); `iw reg set` (`:164`, `:187`); `systemctl --no-ask-password try-restart iwd.service` (`:172-173`). Run by `ryoku-desktop.install:161-162`.
- `ryoku-wifi-powersave`: `iw` power_save off/restore with state in `/run/ryoku/wifi-powersave.prev` (`:15-16`). Called by `ryoku/shell/scripts/ryoku-cmd-game-mode:37`.
- `ryoku-wifi-backend`: toggles NetworkManager `wifi.backend` between iwd (Ryoku default) and wpa_supplicant in `/etc/NetworkManager/conf.d/wifi-backend.conf` (`:20-60`). Called by `ryoku/hub/quickshell/pages/ConnectionsPage.qml:517,809`.
- `ryoku-network-kill`: nftables `inet` table + `nmcli networking off`, state `/var/lib/ryoku/network-kill-switch.enabled` (`:8-10`, `:61-67`); system units `ryoku-network-kill-guard.service` (Before `network-pre.target NetworkManager.service`, `RequiredBy=NetworkManager.service`) and `-disconnect.service`. Called by `ConnectionsPage.qml:69,95`.
- Polkit rules 48/49/50/51/55 grant each helper to wheel.
**Arch couplings:**
- `/etc/conf.d/wireless-regdom` and the `set-wireless-regdom` udev hook: Debian's `wireless-regdb` (2026.05.30-1~deb13u1) ships only `/usr/lib/firmware/regulatory.db{,.p7s}-{debian,upstream}` alternatives and docs (packages.debian.org file list); there is no conf file and no udev rule.
- iwd as the NetworkManager Wi-Fi backend is Ryoku's install-time pin (`ryoku-wifi-backend:26-28`); Debian's NetworkManager defaults to wpa_supplicant.
- `wheel` in five rules.
**Dependencies:**

| Arch pkg | Used for | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| networkmanager | nmcli, conf.d | network-manager | 1.52.1-1 | - | 1.58.1-1 | 1.58.1-1 | 1.54.3-2ubuntu3.1 | global-dns conf (1.2+) |
| iwd 3.12 | backend | iwd | 3.8-2 | - | 3.12-1 | 3.12-1 | 3.10-1ubuntu1 | `[Rank] BandModifier5GHz` |
| wpa_supplicant | backend | wpasupplicant | 2:2.10-24 | - | 2:2.10-25+b2 | same | 2:2.11-0ubuntu5 | >= 2.10 for SAE (`ryoku-wifi-backend:6`) |
| iw | regdom, powersave | iw | 6.9-1+b1 | - | 6.17-1+b1 | same | 6.17-1 | |
| wireless-regdb | regdb | wireless-regdb | 2026.05.30-1~deb13u1 | - | 2026.09.03-1 | same | 2026.05.30-0ubuntu1~26.04.1 | |
| nftables | kill switch | nftables | 1.1.3-1 | - | 1.1.7-3 | same | 1.1.6-1 | |

**As-is on Debian:** PARTIAL (`ryoku-wifi-regdom` NO; others need the group decision).
**Port steps:**
1. `ryoku-wifi-regdom`: replace the `/etc/conf.d/wireless-regdom` persistence with `/etc/modprobe.d/ryoku-regdom.conf` containing `options cfg80211 ieee80211_regdom=<CC>` (applied when cfg80211 loads), keep the iwd hint and `iw reg set`. Update `get` to read that file.
2. Decide the default Wi-Fi backend; if iwd stays default, install `iwd` and write `[device] wifi.backend=iwd` in `/etc/NetworkManager/conf.d/wifi-backend.conf` at install, and disable `wpa_supplicant.service`.
3. Units and rules ship unchanged with the group decision; `Depends: nftables, network-manager, iw`.
**Complexity:** Medium.
**Issues / risks:** `50-ryoku-dns.rules:10` authorizes any executable whose path ends in `ryoku-dns` (comment: so a dev checkout works, `:2-3`); a file the user creates at e.g. `~/.local/bin/ryoku-dns` is then runnable as root through pkexec without a password. The rule ports as-is.

### Input rules and modules (`system/hardware/input/*`)

**What it does:** `72-ryoku-keyboard-uaccess.rules` (`TAG+="uaccess"` on keyboards), `62-ryoku-qmk-hid.rules` (`PROGRAM="/usr/bin/ryoku-hw-qmk %S%p"` then uaccess; `ryoku-hw-qmk` scans the HID report descriptor for usage page `06 60 ff` with `od`), `99-ryoku-controller.conf` (`options bluetooth disable_ertm=1`, `/usr/lib/modprobe.d/`), `99-ryoku-uinput.conf` (`uinput` in `/etc/modules-load.d/`; user must be in `input`, `PKGBUILD:613-615`), `ryoku-hw-asus-aura` (DMI vendor/family or bound `asus-nb-wmi` device) used by `installation/backend/lib/deploy.sh:127-132` and `ryoku/cli/internal/doctor/reconcile_asus_aura.go:29`; `ryoku-hw-qmk` used by `reconcile_qmk.go:31` (which installs `qmk-hid` through `ryoku-pkg-aur-add`, `reconcile_qmk.go:18`).
**Arch couplings:** none in the files; `reconcile_qmk.go:18` uses the AUR wrapper.
**Dependencies:** udev, kmod, coreutils (`od`); the `input` group exists on Debian (udev).
**As-is on Debian:** YES.
**Port steps:** ship unchanged; the installer adds the user to `input`. `qmk-hid` (AUR) has no Debian package (route per the store decision).
**Complexity:** Low.

### DDC/CI (`system/hardware/ddc/ryoku-i2c.conf`, `60-ryoku-i2c.rules`)

**What it does:** loads `i2c-dev` (`/etc/modules-load.d/ryoku-i2c.conf`) and gives `/dev/i2c-*` `GROUP="i2c", MODE="0660", TAG+="uaccess"`; `ddcutil` is a hard depend for the shell's external-monitor brightness (`PKGBUILD:189-193`).
**Arch couplings:** none.
**Dependencies:**

| Arch pkg | Used for | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| ddcutil 3.0.2 | `ddcutil setvcp` | ddcutil | 2.2.0-2 | 2.2.7-1~bpo13+1 | 2.2.7-1 | 2.2.7-1 | 2.2.5-1 | not stated by Ryoku |
| i2c-tools | i2c group | i2c-tools (creates the `i2c` group) | 4.4-2 | - | 4.4-3+b1 | same | 4.4-2build3 | |

**As-is on Debian:** PARTIAL (version gap 2.2 vs 3.0; CLI flags used by the shell not audited here).
**Port steps:** ship unchanged; `Depends: ddcutil, i2c-tools`.
**Complexity:** Low.

### Timezone polkit rule (`system/policy/52-ryoku-timedate.rules`)

**What it does:** passwordless `org.freedesktop.timedate1.set-timezone` for active wheel users (`:6-11`), installed to `/usr/share/polkit-1/rules.d/` (`PKGBUILD:675-676`).
**Arch couplings:** `wheel`.
**As-is on Debian:** PARTIAL.
**Port steps:** group decision; same path.
**Complexity:** Low.

---

### Bundle actuator (`system/extras/ryostore-install`)

**What it does:** Installs, removes and reports RyoStore bundle items (`:1-21`). Reads the cached registry via `ryostore internal cache` (`:37-39`) and fetches one bundle definition via `ryostore internal bundle <id>` (`:44-50`). Item types: `package`, `script`, `plugin`, `nautilus-pack` (`:110-118`). Detection: whole installed set from `pacman -Qq` (`:83-87`), `pacman -Qq <name>` (`:88-91`), official routing by `pacman -Si` (`:92`), owner resolution through provides with `pacman -Qq` (`:95-100`). `ensure_requires` handles `multilib` -> `ryoku-pkg-multilib`, `cachyos` -> `ryoku-pkg-cachyos`, `gpu-lib32` -> `ryoku-gpu-lib32` (`:240-276`). Install batches repo packages to `ryoku-pkg-add`, others to `ryoku-pkg-aur-add` (`:290-357`), runs script installers fetched by `ryostore internal installer` (`:197-206`), guests via `ryostore internal install-guest` (`:211-224`); `tier: optional` items install only by item (`:288-289`). Remove targets owners with `ryoku-pkg-remove`, retrying stragglers one by one twice (`:404-485`). Publishes `$XDG_RUNTIME_DIR/ryostore/<id>.json` (`:125-136`). Launched by the store in a floating `kitty --class ryostore -e ryostore-install install bundle <id>` (`ryoku/apps/ryostore/backend/provider_bundles.go:206-220`); status queried by `provider_bundles.go:179`, `ryoku/hub/quickshell/pages/AddonsPage.qml:92`, `schema/AddonsPage.js:58`, `ryoku/shell/deploy.sh:384`.
**Arch couplings:** pacman queries (`:85`, `:90`, `:92`, `:100`); the AUR fallback for anything not in synced repos (`:294-297`); `requires` names tied to pacman repos.
**Doc drift:** `system/extras/README.md:15` says the cache comes from `ryoku-hub extras cache`; the code uses `ryostore internal cache` (`:37-39`), consistent with `docs/store.md:279-280` ("existing callers of moved commands migrate to /usr/bin/ryostore").
**Dependencies:** jq (1.7.1-6+deb13u3 trixie), kitty (0.41.1-2+deb13u2 trixie / 0.48.2-1.1 forky / 0.45.0-1build1 resolute) for the launcher.
**As-is on Debian:** NO.
**Port steps:**
1. `load_pkgset`: `dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' | awk '$1=="ii"{print $2}'` (and also the bare name for `:amd64` packages; `${binary:Package}` qualifies only foreign/M-A:same arches).
2. `pkg_installed`: `dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii'`.
3. `pkg_official`: `apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]'` (a purely virtual name has `Candidate: (none)`).
4. `pkg_owners` (provides-aware): `dpkg-query -W -f='${db:Status-Abbrev}\t${Package}\t${Provides}\n' | awk -F'\t' -v n="$1" '$1~/^ii/ && ($2==n || $3 ~ "(^|, )" n "( |,|$)") {print $2}'`.
5. Routing: replace the AUR branch with the route chosen per item (see catalogue section): apt (`ryoku-pkg-add`), Flatpak (`flatpak install -y --noninteractive flathub <id>`; presence `flatpak info <id>`), vendor apt repo (add keyring + deb822 source, then apt), or a downloaded `.deb` (`apt-get install -y ./file.deb`). Presence detection must follow the route (dpkg for apt/deb/vendor, `flatpak info` for Flatpak).
6. `ensure_requires`: `multilib` -> i386 enablement (`ryoku-pkg-multilib` rewrite); `cachyos` -> refuse or map to a Debian kernel source (question); `gpu-lib32` -> rewritten `ryoku-gpu-lib32`.
**Complexity:** High; the shell rewrite is mechanical, the routing model (no AUR) needs a catalogue schema change.
**Issues / risks:** Unknown `requires` aborts with "run ryoku update" (`:273`), so a Debian actuator receiving the upstream catalogue's `cachyos` requirement aborts the whole bundle.

### Package wrappers (`system/extras/ryoku-pkg-add`, `-aur-add`, `-remove`, `-multilib`, `-cachyos`, `ryoku-cmd-present`)

**What it does:**
- `ryoku-pkg-add`: `exec sudo pacman -Syu --needed --noconfirm "$@"` (`:18`), full upgrade to avoid partial-upgrade soname breaks (`:15-17`). Callers: `ryostore-install:335`, `ryoku/apps/ryovm/bin/ryovm:145`, `ryoku/cli/internal/updater/update.go:1181`, catalogue installer `davinci-resolve.sh:27-28`.
- `ryoku-pkg-aur-add`: refuses root (`:22-25`), uses `yay` then `paru` (`:27-38`), one `-S --needed --noconfirm` per package (`:40-48`). Callers: `ryostore-install:348`, `ryoku/hub/backend/gpuapply.go:85-95` (Looking Glass + kvmfr for passthrough), `ryoku/apps/ryovm/bin/ryovm:146-147`, `ryoku/cli/internal/doctor/reconcile_limine.go:694-696`, `reconcile_qmk.go:18`.
- `ryoku-pkg-remove`: `exec sudo pacman -Rs --noconfirm "$@"` (`:14`); pacman refuses to remove a package others require (`:3-5`).
- `ryoku-pkg-multilib`: uncomments `[multilib]` in `/etc/pacman.conf` under a flock, then `pacman -Sy` (`:10-30`).
- `ryoku-pkg-cachyos`: checks x86-64-v3 with `/lib/ld-linux-x86-64.so.2 --help` (`:23`), appends `x86_64_v3` to `Architecture` (`:35-46`), `pacman-key --recv-keys F3B607488DB35A47` + `--lsign-key` (`:54-56`), inserts `[cachyos-v3]` above `[core]` (`:59-64`), `pacman -Sy`, installs `cachyos-keyring` (`:67-71`).
- `ryoku-cmd-present`: `command -v` (`:6`); used by catalogue installers.
**Arch couplings:** all of the above.
**Dependencies:** apt, dpkg, sudo (1.9.16p2-3+deb13u2 trixie; Ubuntu 26.04 defaults to sudo-rs, not verified here), flatpak (1.16.6-1~deb13u2 / 1.18.4-1 / 1.16.6-1), psmisc for lock checks.
**As-is on Debian:** NO (`ryoku-cmd-present` YES).
**Port steps (concrete code):**

```bash
# ryoku-pkg-add
set -euo pipefail
(($#)) || { echo "ryoku-pkg-add: no packages given" >&2; exit 2; }
sudo apt-get update
exec sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
```
(No full upgrade needed: apt upgrades the libraries a new package depends on in the same transaction. `apt-get install` on an already-installed auto package marks it manual, which changes later autoremove behaviour; pacman `--needed` has no such side effect. Recommends are installed by default; pacman has no Recommends.)

```bash
# ryoku-pkg-remove: refuse instead of cascading, like pacman -R
set -euo pipefail
(($#)) || { echo "ryoku-pkg-remove: no packages given" >&2; exit 2; }
extra=$(apt-get -s remove "$@" | awk '/^Remv /{print $2}' | grep -vxF -f <(printf '%s\n' "$@") || true)
[[ -z $extra ]] || { echo "ryoku-pkg-remove: would also remove: $extra" >&2; exit 1; }
exec sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --autoremove "$@"
```
(`apt-get remove X` removes every installed package that depends on X; pacman `-R` refuses. `--autoremove` removes **all** auto-installed orphans system-wide, not only those freed by X, unlike `-Rs`.)

```bash
# ryoku-pkg-multilib (i386 + the components Steam/NVIDIA need)
set -euo pipefail
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/ryoku-pkg-conf.lock"; flock 9
dpkg --print-foreign-architectures | grep -qx i386 && { echo "i386: already enabled"; exit 0; }
sudo dpkg --add-architecture i386
sudo apt-get update
```
(Debian: `steam-installer` is in `contrib`, NVIDIA in `non-free`/`non-free-firmware`; the deb822 `Components:` line in `/etc/apt/sources.list.d/debian.sources` must carry them. Ubuntu: `multiverse` for `steam-installer`, `restricted` for NVIDIA.)

- `ryoku-pkg-aur-add`: no AUR on Debian. Replace with a per-item route dispatcher (Flatpak / vendor repo / release `.deb` / Ryoku-built deb), driven by catalogue data (see question).
- `ryoku-pkg-cachyos`: no Debian equivalent of the `[cachyos-v3]` repo. If kept as a kernel option: the ld.so path differs (`/lib/ld-linux-x86-64.so.2` does not exist on Debian amd64; use `/lib64/ld-linux-x86-64.so.2 --help`, glibc 2.41 prints the `x86-64-v3 (supported...)` line). Candidate kernel sources that publish trixie suites (HTTP 200 on 2026-10-17): `https://liquorix.net/debian/dists/trixie/`, `https://deb.xanmod.org/dists/trixie/`; Debian's own trixie-backports `linux-image-amd64` 7.2.6-1~bpo13+1.
**Complexity:** Medium.
**Issues / risks:** `sudo DEBIAN_FRONTEND=... apt-get` relies on sudoers allowing env on the command line (implied for `ALL` commands). Running apt from the floating terminal while unattended-upgrades holds the lock fails with "Could not get lock /var/lib/dpkg/lock-frontend"; pacman has the same failure mode with `db.lck`.

### Bundle catalogue (`ryostore` repo, `bundles/*/bundle.json` at `f928795`)

**What it does:** 11 bundles in `bundles/registry.json`; each `bundle.json` lists items with `type`, `name`, `detect`, `source` (display only), `tier`, optional `interactive`, and bundle `requires` (`bundles/README.md` "bundle.json"). Routing ignores `source`; it uses `pacman -Si` (`ryostore-install:294`). Script installers: `bundles/spiceflow/installers/ryoku-palette-bridge.sh` (identical copy in `installers/`), `bundles/the-influencer/installers/{capture-website-cli,youtubeuploader,davinci-resolve}.sh`.

**Installer script couplings:**
- `capture-website-cli.sh:13`: `npm install -g --prefix="$HOME/.local" capture-website-cli` (needs `npm`; distro-neutral).
- `youtubeuploader.sh:13`: `GOBIN="$HOME/.local/bin" go install github.com/porjo/youtubeuploader/cmd/youtubeuploader@latest` (needs `golang-go`; module's go directive not checked).
- `ryoku-palette-bridge.sh`: requires `git go curl systemctl` (`:26-31`), clones a pinned commit, runs upstream `./install.sh`, enables a user unit (`:86+`); distro-neutral except the Go version the bridge needs (not checked).
- `davinci-resolve.sh`: Arch-only: `ryoku-pkg-add git`/`base-devel` (`:27-28`), `git clone https://aur.archlinux.org/davinci-resolve.git` (`:33`), `updpkgsums`, `makepkg -si` (`:69-74`). Debian: Blackmagic's `.run` installer (user-downloaded zip, same manual-download flow) or a community `.deb` maker; no AUR.

**Catalogue mapping (Arch item -> Debian route).** Route key: **apt** = Debian/Ubuntu archive; **vendor** = third-party apt repo; **deb** = upstream release `.deb`; **flatpak** = Flathub id (verified HTTP 200 via flathub.org API on 2026-10-17); **build** = Ryoku must build a deb.

developer-essentials (requires none):

| Item (route on Arch) | Debian route | Debian pkg / id | trixie | trixie-bpo | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|---|
| base-devel (repo) | apt | build-essential | 12.12 | - | 12.12+b1 | 12.12+b1 | 12.12ubuntu2.26.04.2 | |
| git | apt | git | 1:2.47.3-0+deb13u1 | - | 1:2.53.0-1 | 1:2.55.0-1 | 1:2.53.0-1ubuntu1 | |
| github-cli | apt | gh | 2.46.0-3 | - | - | 2.46.0-4+b1 | 2.46.0-4 | not in forky; GitHub's apt repo cli.github.com is the alternative |
| curl, wget, jq | apt | curl / wget / jq | 8.14.1 / 1.25.0 / 1.7.1 | 8.21.0 bpo / - / - | 8.22.0 / 1.25.0 / 1.8.2 | | 8.18.0 / 1.25.0 / 1.8.1 | |
| ripgrep | apt | ripgrep | 14.1.1-1+b4 | - | 15.2.0-1 | 15.2.0-1 | 15.1.0-1ubuntu1 | |
| fd (detect `fd`) | apt | fd-find | 10.2.0-1+b5 | - | 10.5.0-1 | 10.5.0-1 | 10.3.0-2ubuntu1 | binary is `fdfind`: `detect: fd` never turns present |
| fzf, tmux | apt | fzf / tmux | 0.60.3 / 3.5a | - / 3.6b bpo | 0.74.4 / 3.7c | | 0.67.0 / 3.6a | |
| cmake, ninja | apt | cmake / ninja-build | 3.31.6 / 1.12.1 | 4.3.4 bpo / - | 4.3.4 / 1.13.2 | | 4.2.3 / 1.13.2 | |
| gdb, clang, lldb | apt | gdb / clang / lldb | 16.3 / 19 / 19 | 18.1 bpo | 18.1 / 21.1.8 / 21.1.8 | | 17.1 / 21.1.6 | |
| python, python-pip | apt | python3 / python3-pip | 3.13.5 / 25.1.1 | - | 3.14.7 / 26.1.2 | | 3.14.3 / 25.1.1 | Debian marks system Python externally-managed (PEP 668): `pip install` outside a venv refuses |
| nodejs, npm | apt | nodejs / npm | 20.19.2 / 9.2.0 | - | 24.21.0 / 12.2.0 | | 22.22.1 / 9.2.0 | |
| bun | build/upstream | none in Debian/Ubuntu | - | - | - | - | - | upstream zip installer from bun.sh |
| rustup | apt | rustup | 1.27.1-3+b1 | - | 1.27.1-8+b2 | same | 1.27.1-8 | |
| go | apt | golang-go | 2:1.24~2 | 2:1.27~1~bpo13+1 | 2:1.27~1 | same | 2:1.26~1 | |
| jdk-openjdk | apt | openjdk-25-jdk (default-jdk = 21 on trixie, 25 on forky/resolute) | 25.0.3+9-2~deb13u1 | - | 25.0.5~7ea-1 | 25.0.5~7ea-2 | 25.0.4.1+1 | |
| docker, docker-compose | apt or vendor | docker.io, docker-compose (vendor: docker-ce, docker-compose-plugin) | 26.1.5 / 2.26.1 | - | 28.5.2 / 2.40.3 | same | 29.1.3 / docker-compose-v2 2.40.3 | see containers |
| visual-studio-code-bin (AUR) | vendor or flatpak | `code` from packages.microsoft.com/repos/code; flatpak com.visualstudio.code | - | - | - | - | - | |

gaming (requires `multilib`, `gpu-lib32`):

| Item | Debian route | Debian pkg / id | trixie | trixie-bpo | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|---|
| steam | apt (contrib, i386) or vendor | steam-installer (+steam-libs:i386); vendor repo.steampowered.com; flatpak com.valvesoftware.Steam | 1:1.0.0.83~ds-3 | - | 1:1.0.0.87~ds-3 | same | 1:1.0.0.85~ds-2build1 | |
| lutris | apt | lutris | 0.5.19-2 | - | 0.5.22-1 | 0.5.22-1 | 0.5.22-1 | |
| heroic-games-launcher-bin (AUR) | deb or flatpak | Heroic-2.22.4-linux-amd64.deb; com.heroicgameslauncher.hgl | - | - | - | - | - | |
| umu-launcher (Arch multilib 1.4.4) | deb | python3-umu-launcher_1.4.4-1_amd64_debian-13.deb (also `_ubuntu-resolute`) from GitHub releases | - | - | - | - | - | not in Debian |
| wine | apt or vendor | wine, wine64, wine32:i386; vendor dl.winehq.org (trixie suite exists) | 10.0~repack-6 | - | - (absent from testing) | 10.0~repack-12 | 10.0~repack-12ubuntu1 | |
| winetricks | apt (contrib) | winetricks | 20250102-1 | - | - | 20250102-1 | 20250102-1build1 | absent from forky |
| protontricks (Arch extra 1.14.1) | apt or flatpak | protontricks; com.github.Matoking.protontricks | - | - | - | 1.13.1+ds-1 | 1.13.1+ds-1 | sid/resolute only |
| protonup-qt (AUR) | flatpak | net.davidotek.pupgui2 (upstream ships AppImage only) | - | - | - | - | - | |
| vkd3d / lib32-vkd3d | apt | libvkd3d1, libvkd3d-shader1 (+ :i386) | 1.2-15+b2 | - | 2.1+ds-1 | 2.1+ds-1 | 1.2-15build1 | |
| gamemode / lib32-gamemode | apt | gamemode, libgamemode0:i386 | 1.8.2-2 | - | 1.8.2-2+b2 | same | 1.8.2-2build1 | |
| gamescope | apt | gamescope | - | 3.16.22+ds-1~bpo13+1 | 3.16.24+ds-2 | same | 3.16.20+ds-1 | backports on trixie |
| mangohud / lib32-mangohud | apt | mangohud, mangohud:i386 | 0.7.2-2 | - | 0.8.4+dfsg-1+b1 | same | 0.8.2~rc2-1 | |
| goverlay | apt | goverlay | 1.0-1 | - | 1.0-1 | 1.0-1 | 1.0-1build1 | |
| vkbasalt (AUR) | apt | vkbasalt | 0.3.2.10-1+b2 | - | 0.3.2.10-1+b3 | same | 0.3.2.10-1build1 | |
| game-devices-udev (AUR in catalogue; also [ryoku]) | build | see game-devices-udev section | | | | | | |
| vesktop-bin (AUR) | deb or flatpak | vesktop_1.6.7_amd64.deb; dev.vencord.Vesktop | - | - | - | - | - | |
| retroarch, libretro-core-info | apt | retroarch / libretro-core-info | 1.20.0 / 1.20.0 | - | 1.22.2 / 1.20.0 | | 1.22.2 / 1.20.0 | |
| libretro-snes9x | apt | libretro-snes9x | 1.63+dfsg-1 | - | 1.63+dfsg-2 | | 1.63+dfsg-1build1 | |
| libretro-mesen | none | - | - | - | - | - | - | flatpak org.libretro.RetroArch bundles cores |
| libretro-genesis-plus-gx | apt | libretro-genesisplusgx | 1.7.4+git20221128-2 | - | 1.7.4+git20260324-1 | | 1.7.4+git20221128-2build1 | |
| libretro-beetle-psx-hw | apt (partial) | libretro-beetle-psx (software renderer build, no `-hw`) | - | - | 0.9.38.6+git20260515+ds-2 | same | 0.9.38.6+git20260227-1 | |
| libretro-mupen64plus-next | none | (Debian has mupen64plus standalone, not the libretro -next core) | - | - | - | - | - | |
| dolphin-emu | apt | dolphin-emu | 2503+dfsg-1+deb13u1 | - | 2609+dfsg-1+b1 | same | 2512+dfsg-3 | |
| pcsx2 (AUR) | apt or flatpak | pcsx2; net.pcsx2.PCSX2 | 1.6.0+dfsg-3+deb13u1 | - | 2.8.2+dfsg-2 | same | 2.6.3+dfsg-1build1 | trixie's 1.6.0 is the pre-Qt 2020 line |
| rpcs3-bin (AUR) | flatpak | net.rpcs3.RPCS3 (upstream AppImage) | - | - | - | - | - | |
| ppsspp | flatpak | org.ppsspp.PPSSPP | - | - | - | - | - | not in Debian |
| mgba-qt | apt | mgba-qt | 0.10.5+dfsg-1 | - | 0.10.5+dfsg-3+b2 | same | 0.10.5+dfsg-3build1 | |
| melonds (AUR) | flatpak | net.kuribo64.melonDS | - | - | - | - | - | |
| mame, scummvm, dosbox | apt | mame / scummvm / dosbox | 0.276 / 2.9.0 / 0.74-3 | - | 0.289 / 2026.1.0 / 0.74-3 | | 0.285 / 2026.1.0 / 0.74-3 | |
| corectrl | apt | corectrl | 1.4.3+ds-2 | - | 1.5.2+ds-1+b6 | same | 1.5.2+ds-1build1 | |
| antimicrox | flatpak or deb | io.github.antimicrox.antimicrox; upstream ubuntu-24.04 .deb | - | - | - | - | - | not in Debian |
| sc-controller | apt (old) or AppImage | sc-controller (0.6.1); upstream C0rn3j 1.0.7 ships AppImage | - | - | 0.6.1-1+b1 | 0.6.1-1+b1 | - | catalogue upstream is the C0rn3j fork |

rice-showcase (requires none):

| Item | Debian route | Debian pkg | trixie | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|
| cmatrix | apt | cmatrix | 2.0-6+b1 | 2.0-6+b2 | same | 2.0-6build1 | |
| cbonsai | apt | cbonsai | 1.3.1-1+b1 | 1.4.2-1+b2 | same | 1.4.2-1 | |
| cava | apt | cava | 0.10.4+dfsg-1 | 1.0.0+dfsg-2 | same | 0.10.7+dfsg-1 | |
| fastfetch | apt | fastfetch | 2.40.4+dfsg-1 | 2.69.0+dfsg-1 | same | 2.57.1+dfsg-1ubuntu1 | |
| btop | apt | btop | 1.3.2-0.1 | 1.4.7-1 | same | 1.4.6-2 | |
| figlet, lolcat, toilet, cowsay, sl | apt | same names | 2.2.5 / 100.0.1 / 0.3 / 3.03 / 5.02 | | | | |
| pipes.sh (AUR) | apt | pipes-sh | 1.3.0-2 | 1.3.0-2 | same | 1.3.0-2build1 | |
| tty-clock (AUR) | apt | tty-clock | 2.3+git.20211121.f2f847c-1 | …-1+b1 | same | …-1build1 | |
| asciiquarium | none | - | - | - | - | - | Perl script; needs `libterm-animation-perl` + upstream script (not checked) |

(trixie-bpo column omitted: none of these has a backport.)

ryotunes: one `package` item `ryotunes` (`bundles/ryotunes/bundle.json`), a Rust app from `https://github.com/ryoku-dev/ryotunes` (fork of ashmitvoid/ryotunes, GPL-3.0; `bundles/ryotunes/PROVENANCE.txt`), not in Arch repos or AUR; Ryoku builds it into `[ryoku]` (`release/repo/import-ryotunes.sh`, `refresh-ryotunes.sh`). Debian: **build** a deb in Ryoku's own apt repo.

spiceflow: `git`, `go` (golang-go), `curl` (apt), script `ryoku-palette-bridge` (distro-neutral, above).

the-influencer (requires `multilib`):

| Item | Debian route | Debian pkg / id | trixie | trixie-bpo | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|---|
| nautilus-pack video-reformat | ryostore guest | - | | | | | | distro-neutral |
| obs-studio | apt or flatpak | obs-studio; com.obsproject.Studio | 30.2.3+dfsg-3 | - | 32.2.2+ds-1+b1 | same | 32.1.0-0ubuntu3 | |
| obs-vkcapture (AUR) | flatpak ext / build | com.obsproject.Studio.Plugin.OBSVkCapture | - | - | - | - | - | no release assets upstream (v1.5.6) |
| obs-backgroundremoval (AUR) | deb or flatpak ext | obs-backgroundremoval_1.4.1.forky_amd64.deb; com.obsproject.Studio.Plugin.BackgroundRemoval | - | - | - | - | - | upstream deb targets forky |
| obs-pipewire-audio-capture (AUR) | apt | obs-pipewire-audio-capture | 1.2.0-1 | - | 1.2.1-1 | 1.2.1-1 | 1.2.0-1build1 | |
| v4l2loopback-dkms | apt | v4l2loopback-dkms | 0.15.0-2 | - | 0.15.4-2 | same | 0.15.3-1ubuntu2 | |
| linux-headers | apt | linux-headers-amd64 / linux-headers-generic | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | same | 7.0.0-39.39 | |
| gpu-screen-recorder | apt (forky/sid) or flatpak | gpu-screen-recorder; com.dec05eba.gpu_screen_recorder | - | - | 5.13.8-1 | 5.13.8-2 | - | also a `ryoku-desktop` hard depend (`PKGBUILD:184`) |
| wf-recorder | apt | wf-recorder | 0.5.0-2 | - | 0.6.0-1+b2 | same | 0.6.0-1build1 | |
| kdenlive | apt | kdenlive | 24.12.3-2+deb13u1 | - | 26.08.2-1 | same | 4:25.12.3-0ubuntu1.1 | |
| losslesscut-bin (AUR) | flatpak | no.mifi.losslesscut (upstream AppImage) | - | - | - | - | - | |
| easyeffects | apt | easyeffects | 7.2.3-1 | - | 8.3.0+ds-1 | same | 8.1.2+ds-1 | |
| noise-suppression-for-voice | none | - | - | - | - | - | - | build (CMake LADSPA/LV2) |
| audacity, gimp, inkscape, krita | apt | same names | 3.7.3 / 3.0.4 / 1.4 / 5.2.9 | - | 4.0.1 / 3.2.6 / 1.4.3 / 5.3.4.1 | | 3.7.7 / 3.2.2 / 1.4.3 / 6.0.1 | |
| yt-dlp | apt | yt-dlp | 2025.04.30-1 | 2026.08.19-1~bpo13+1 | 2026.08.19-1 | same | 2026.08.19-1~bpo26.04.1 | trixie main copy is stale for a downloader |
| handbrake | apt | handbrake | 1.9.2+ds1-1+b1 | - | 1.11.2+ds1-1+b3 | same | 1.11.0~us1-0ubuntu1 | |
| script capture-website-cli | npm | (needs npm) | | | | | | |
| script youtubeuploader | go | (needs golang-go) | | | | | | |
| script davinci-resolve | vendor `.run` | user-supplied Blackmagic installer | | | | | | AUR path does not port |
| reaper | flatpak / vendor tarball | fm.reaper.Reaper | - | - | - | - | - | |
| wl-screenrec (AUR) | build | cargo build (no release assets) | - | - | - | - | - | |
| distroav (AUR) | deb or flatpak ext | distroav-6.2.2-x86_64-linux-gnu.deb; com.obsproject.Studio.Plugin.DistroAV | - | - | - | - | - | |
| owncast-bin (AUR) | upstream zip | owncast-0.3.0-linux-64bit.zip | - | - | - | - | - | |
| shotcut, blender, darktable | apt | same names | 25.03.29 / 4.3.2 / 5.0.1 | - / - / 5.4.1 bpo | 26.9.27 / 5.0.1 / 5.4.1 | | 26.1.30 / 5.0.1 / 5.4.1 | |
| upscayl-bin (AUR) | deb or flatpak | upscayl-2.15.0-linux.deb; org.upscayl.Upscayl | - | - | - | - | - | |
| qprompt (AUR) | build | GitHub `qPrompt/qprompt-app` releases API returned 404 | - | - | - | - | - | source not resolved |
| subtitleedit (AUR) | upstream tarball | SubtitleEdit v5.3.0 (no Flathub id `org.nikse.SubtitleEdit`) | - | - | - | - | - | Debian `subtitleeditor` is a different program |

vpn-networking:

| Item | Debian route | Debian pkg | trixie | trixie-bpo | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|---|
| wireguard-tools | apt | wireguard-tools | 1.0.20210914-3 | 1.0.20250521-1~bpo13+1 | 1.0.20260223-2 | same | 1.0.20250521-1ubuntu1 | |
| openvpn | apt | openvpn | 2.6.14-1+deb13u3 | 2.7.8-1~bpo13+1 | 2.7.8-1 | same | 2.7.0-1ubuntu1.3 | |
| networkmanager-openvpn | apt | network-manager-openvpn | 1.12.3-1~deb13u1 | - | 1.12.5-2 | same | 1.12.5-1 | detect `nm-openvpn-service` is in `/usr/lib/NetworkManager/`, not on PATH (same on Arch) |
| networkmanager-strongswan | apt | network-manager-strongswan | 1.6.2-1 | - | 1.6.4-1+b1 | same | 1.6.4-1 | |
| proton-vpn-gtk-app (Arch 4.18.6) | apt (forky+) or vendor | proton-vpn-gtk-app; vendor repo.protonvpn.com/debian; flatpak com.protonvpn.www | - | - | 4.15.3-1 | 4.15.3-1 | 4.15.2-1 | |
| mullvad-vpn-bin (AUR) | vendor | `mullvad-vpn` from repository.mullvad.net/deb/stable (trixie suite exists) | - | - | - | - | - | no Flathub id |
| cloudflare-warp-bin (AUR) | vendor | `cloudflare-warp` from pkg.cloudflareclient.com (trixie suite exists) | - | - | - | - | - | |

web-browsers:

| Item | Debian route | Debian pkg / id | trixie | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|
| firefox | vendor or apt | Mozilla apt repo packages.mozilla.org (`firefox`); Debian `firefox-esr` | firefox-esr 140.15.0esr | firefox-esr 153.4.0esr | firefox 158.0-1 | `firefox` is a snap transitional (1:1snap1-0ubuntu9.1) | rapid-release `firefox` only in sid |
| firefox-developer-edition | vendor | `firefox-devedition` from packages.mozilla.org | - | - | - | - | |
| chromium | apt | chromium | 150.0.7871.181-1~deb13u1 | 154.0.8037.92-1 | 155.0.8059.79-1 | - (snap) | |
| brave-bin (AUR) | vendor or flatpak | `brave-browser` from brave-browser-apt-release.s3.brave.com; com.brave.Browser | - | - | - | - | |
| librewolf (Arch extra) | vendor or flatpak | repo.librewolf.net; io.gitlab.librewolf-community | - | - | - | - | |
| zen-browser-bin (AUR; also in `aur.packages`) | flatpak / tarball | app.zen_browser.zen; zen.linux-x86_64.tar.xz | - | - | - | - | |

cachyos-layer (requires `cachyos`, `multilib`):

| Item | Debian status |
|---|---|
| linux-cachyos, linux-cachyos-headers | no Debian build; nearest third-party kernels with trixie suites: Liquorix, XanMod; or Ryoku builds CachyOS-patched kernels as debs |
| cachyos-settings | config bundle (sysctl/udev/modprobe); repack as a deb |
| ananicy-cpp | not in Debian/Ubuntu; upstream gitlab ananicy-cpp/ananicy-cpp v1.2.0 (build) |
| cachyos-ananicy-rules | git repo CachyOS/ananicy-rules (repack) |
| scx-scheds | not in Debian/Ubuntu (upstream sched-ext/scx v1.1.4). Needs `CONFIG_SCHED_CLASS_EXT=y`: absent from Debian linux 6.12.107-1 (trixie), set in 7.2.11-1 (forky/sid; trixie-backports 7.2.6 assumed same config) |
| proton-cachyos-native | upstream tarball `proton-cachyos-11.0-20261014-slr-x86_64(_v3).tar.xz` into `~/.steam/root/compatibilitytools.d` |

mjw-widgets: 25 `plugin` items fetched by `ryostore internal install-guest plugins` (distro-neutral).

After the pin, `main` added `ryoku-zed-theme`: `package bun` (no Debian package) + `script ryoku-zed-theme` (installer not audited).

**As-is on Debian:** PARTIAL: about two thirds of items have an archive package (often older on trixie), 37 items are AUR-routed on Arch, several archive-routed items are missing from forky (wine, winetricks, gh) or trixie (gamescope, protontricks, proton-vpn-gtk-app, gpu-screen-recorder).
**Port steps:**
1. Extend `bundle.json` items (ryostore repo) with per-distro routes, e.g. `"debian": {"apt": "fd-find", "detect": "fdfind"}` / `{"flatpak": "net.pcsx2.PCSX2"}` / `{"repo": "brave", "apt": "brave-browser"}` / `{"deb": "<url>", "sha256": "..."}`, or keep a Debian route table inside the actuator (question).
2. Add `i386` translation for `lib32-*` names (`lib32-X` -> `<debian-name>:i386`).
3. Fix `detect` values that differ on Debian (`fd` -> `fdfind`).
4. Decide the `cachyos-layer` bundle's fate on Debian (question).
**Complexity:** High (catalogue is external, cross-distro schema, vendor-repo keyring management).
**Issues / risks:** Flatpak apps do not show in `dpkg-query`, and `detect` commands are not on PATH for Flatpaks (exported as `/var/lib/flatpak/exports/bin/<app-id>`), so presence logic must be route-aware. Vendor repos add signing keys system-wide; each needs a keyring file under `/usr/share/keyrings` or `/etc/apt/keyrings` and a `Signed-By` deb822 source.

### GlazePKG (`release/packages/gpk/PKGBUILD`)

**What it does:** Repackages the upstream Go release binary `gpk-linux-amd64` v0.6.10 to `/usr/bin/gpk` (`:12`, `:23-33`), `depends=('pacman')` (`:18`), a hard depend of `ryoku-desktop` (`release/packages/ryoku-desktop/PKGBUILD:33`). Upstream `github.com/neur0map/glazepkg` (GPL-3.0): "yay for your whole machine", 46 package managers including **apt** (`internal/manager/apt.go`: `Available()` = `dpkg-query` exists; scan `apt-mark showmanual` + `dpkg-query -W`; search `apt-cache search`; install `apt-get install -y` via its privileged wrapper; remove `apt-get remove -y`/`autoremove -y`; upgrades `apt list --upgradable`), **flatpak** and **snap**. Latest release v0.6.10 (2026-09-22) = the pinned version.
**Call sites:** launcher package provider `ryoku/shell/quickshell/shell/modules/launcher/shared/providers/packages/Packages.qml:6-271`: fast lane `gpk search <term> --json --limit 30 --manager pacman,aur` (`:217`), full search `gpk search <term> --json --limit 30` (`:271`), install/remove `terminal -e gpk install|remove <pkg>` (`:165-166`); `ryoku/hub/quickshell/pages/DictationPage.qml:113,121`.
**Arch couplings:** `depends=('pacman')`; `Packages.qml:217` hardcodes `--manager pacman,aur`; DictationPage use not inspected in detail.
**Dependencies:** none at runtime besides the managers it drives (apt, dpkg, flatpak).
**As-is on Debian:** PARTIAL (binary runs and has an apt backend).
**Port steps:**
1. Deb: `install -Dm755 gpk-linux-amd64 debian/gpk/usr/bin/gpk`; `Depends: dpkg, apt`; `Architecture: amd64` (arm64 asset exists). Verify sha256 `b4e43c24...7be3` (`PKGBUILD:25`).
2. `Packages.qml:217`: `--manager pacman,aur` -> `--manager apt,flatpak` (or derive from `gpk managers`).
3. `gpk update` self-updates from upstream (`PKGBUILD:10`); upstream README says a manager-installed gpk is owned by that manager; whether v0.6.10 refuses to overwrite a dpkg-owned binary was not verified.
**Complexity:** Low.

### Container helper (`system/containers/ryoku-docker`, `46-ryoku-docker.rules`)

**What it does:** The only root path for the stash "Cobalt engine": `state` (binary/service/socket), `provision` (`systemctl enable --now docker`, wait for `/var/run/docker.sock`), `container-status|up|down` for the fixed container `ryoku-cobalt` from `ghcr.io/imputnet/cobalt:11` on `127.0.0.1:<port>:9000` with port 1024-65535 (`:28-30`, `:86-170`); re-execs via pkexec (`:70-81`); never adds the user to `docker` (`:5-12`). Rule: `/usr/bin/ryoku-docker` for active local wheel users (`46-ryoku-docker.rules:19-25`). `docker` is in `system/packages/base.packages:187` and deliberately **not enabled** at install (`base.packages:180-186`). Callers: `ryoku/shell/quickshell/shell/services/Stash.qml:150` (`ryoku-docker provision`), `ryoku/shell/scripts/stash-cobalt-server.sh:22-63` (direct docker when the session already has access, else the helper), `CobaltSetupWizard.qml`.
**Arch couplings:** `wheel`. Comment names `47-ryoku-docker.rules` (`ryoku-docker:69`); the file is `46-ryoku-docker.rules`.
**Dependencies:**

| Arch pkg (29.9.1) | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs |
|---|---|---|---|---|---|---|---|---|
| docker | daemon + CLI (`:43`, `:108`, `:153`) | docker.io (Debian) / docker-ce (download.docker.com) | 26.1.5+dfsg1-9+deb13u1 (docker-ce 5:29.9.1-1~debian.13~trixie) | - | 28.5.2+dfsg4-5 (no docker-ce forky suite) | 28.5.2+dfsg4-5 | 29.1.3-0ubuntu4.1 (docker-ce 5:29.9.1-1~ubuntu.26.04~resolute) | `run -d --restart unless-stopped -p -e`, `inspect -f`, `image inspect`: all present in 26.x |
| polkit | grant | polkitd, pkexec | 126-2 | - | 127-3 | 128-1 | 127-2ubuntu1.1 | |

**As-is on Debian:** PARTIAL.
**Port steps:**
1. Ship unchanged to `/usr/bin/ryoku-docker`; rule to `/usr/share/polkit-1/rules.d/46-ryoku-docker.rules` with the group decision; `Depends: pkexec`.
2. After installing `docker.io` (or `docker-ce`), run `systemctl disable --now docker.service docker.socket`: both packages' maintainer scripts enable and start the units (deb-systemd-helper ignores systemd presets on Debian), which contradicts `base.packages:180-186`. `docker.io` ships `/usr/lib/systemd/system/docker.service` and `docker.socket`.
3. `/var/run/docker.sock` resolves via Debian's `/var/run -> /run` symlink.
**Complexity:** Low.
**Issues / risks:** If `docker.socket` stays enabled, `/var/run/docker.sock` exists while `docker.service` is inactive, so `state` reports `socket yes, service inactive` and `provision` still escalates (`:100-112`); behaviour is correct but differs from Arch's first-run path. The `docker` group is created by both Debian packages; Ryoku does not use it.
**Questions for the human:** `docker.io` (Debian-maintained, 26.1.5 on trixie, security via Debian) vs `docker-ce` (Docker Inc. repo, 29.9.1 = Arch, no forky suite).

### xpadneo-dkms (`release/packages/xpadneo-dkms/PKGBUILD`)

**What it does:** Xbox One/Series Bluetooth pad driver 0.10.4 (`:39`), DKMS source in `/usr/src/hid-xpadneo-v0.10.4` (`:63-69`), modprobe/udev files with `ETC_PREFIX=/usr/lib` (`:56-58`), `depends=('dkms' 'bluez' 'bluez-utils')` (`:44`); in `system/packages/base.packages:221`; `ryoku-desktop` depends `linux-headers dkms` for it (`PKGBUILD:201-211`). Pairs with `99-ryoku-controller.conf` and `99-ryoku-uinput.conf` (`:10-14`). `docs/preinstalled.md:267` lists it under "From the AUR"; the PKGBUILD says it moved to `[ryoku]` (`:16-21`).
**Arch couplings:** none beyond packaging.
**Dependencies:**

| Arch pkg | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Ryoku pin / upstream |
|---|---|---|---|---|---|---|---|
| xpadneo-dkms 0.10.4 | xpadneo-dkms (Debian file list: `/usr/lib/modprobe.d/xpadneo.conf`, `/usr/lib/udev/rules.d/60-xpadneo.rules`, `70-xpadneo-disable-hidraw.rules`, `/usr/src/hid-xpadneo-0.10.4/`) | - | - | 0.10.4-1 | 0.10.4-1 | - | 0.10.4 / v0.10.4 latest |
| dkms | dkms | 3.2.2-1~deb13u1 | - | 3.2.2-1 | 3.2.2-1 | 3.2.2-1ubuntu1 | |
| linux-headers | linux-headers-amd64 / linux-headers-generic | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | 7.0.0-39.39 | |

**As-is on Debian:** PARTIAL (forky/sid only).
**Port steps:** trixie and resolute: rebuild the sid source package (`dget` the sid `.dsc`, `dpkg-buildpackage -us -uc` on trixie; build-deps `debhelper-compat, dh-dkms` — dh-dkms 3.2.2-1~deb13u1 in trixie) or build from the PKGBUILD recipe with `dh-dkms`; `Depends: dkms, bluez, linux-headers-amd64 | linux-headers`.
**Complexity:** Low.
**Issues / risks:** Debian's source names the dkms dir `hid-xpadneo-0.10.4` while Ryoku's names it `hid-xpadneo-v0.10.4`; not a conflict unless both are installed. `xpadneo-dkms/PKGBUILD:23-27` says `xone` "is packaged separately and installed on demand"; `docs/installation-hardware.md:283-310` says Ryoku ships neither xone driver nor firmware.

### game-devices-udev (`release/packages/game-devices-udev/PKGBUILD`)

**What it does:** udev rules for 27 controller vendors, release tarball 1.0 (`:37`, `:46-47`), meson build (`:49-55`), no `uinput.conf` (`:29-32`), `udevadm control --reload-rules` in `.install`; `provides=('nintendo-udev')`; in `base.packages:222` (`docs/preinstalled.md:266` still lists it as AUR).
**Dependencies:**

| Arch/AUR | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Ryoku pin / upstream |
|---|---|---|---|---|---|---|---|
| game-devices-udev 1.0 (AUR has 1.1) | none (Debian `steam-devices` covers Valve/some pads only) | - | - | - | - | - | 1.0 / codeberg tag 1.1 |
| meson (build) | meson | 1.7.0-1 | - | 1.12.1-2 | same | 1.10.1-1ubuntu2 | |

**As-is on Debian:** NO.
**Port steps:** `meson setup build --prefix=/usr && meson compile -C build && meson install -C build --destdir debian/game-devices-udev`; rules land in `/usr/lib/udev/rules.d` (correct on trixie). Drop any `uinput.conf` the upstream meson installs (Ryoku ships its own). Conflicts check with `steam-devices` (both ship `60-steam-*`-style rules? file overlap not checked). postinst `udevadm control --reload-rules` (debhelper `dh_installudev` does the reload).
**Complexity:** Low.

### broadcom-bt-firmware (`release/packages/broadcom-bt-firmware/PKGBUILD`)

**What it does:** Repacks upstream's `.deb` (`winterheart/broadcom-bt-firmware` v12.0.1.1105_p4, `:37-46`): 114 `brcm/*.hcd` patchram files to `/usr/lib/firmware/brcm` (`:59-60`); in `base.packages:230`.
**Dependencies:**

| Arch | Debian/Ubuntu pkg | trixie | forky | sid | resolute | Ryoku pin / upstream |
|---|---|---|---|---|---|---|
| broadcom-bt-firmware | none. `firmware-brcm80211` (20250410-2 / 20260916-1) has 0 `.hcd`; `bluez-firmware` (1.2-13) has 4; `firmware-misc-nonfree` has 2 (packages.debian.org trixie file lists) | - | - | - | - | 12.0.1.1105_p4 / v12.0.1.1105_p5 latest |

**As-is on Debian:** NO.
**Port steps:** upstream already publishes a `.deb`; either use it directly or repack exactly as the PKGBUILD does (payload `lib/firmware/brcm/*.hcd` -> `/usr/lib/firmware/brcm/`), `Architecture: all`, section `non-free-firmware`-equivalent in Ryoku's repo. Check for file overlap with `bluez-firmware`'s 4 `.hcd` files (names not compared).
**Complexity:** Low.

### dualsensectl (`release/packages/dualsensectl/PKGBUILD`)

**What it does:** DualSense control CLI 0.7, meson (`:19-39`), `depends=('dbus' 'hidapi' 'libusb')`; opt-in (`ryoku/cli/internal/ryokumanifest/manifest.go:120-133`).
**Dependencies:** Debian `dualsensectl`: trixie -, forky 0.7+git20250823-1, sid same, resolute 0.7+git20250823-1. Build deps if backporting: meson 1.7.0-1, libhidapi-dev 0.14.0-1+b2, libdbus-1-dev 1.16.2-2, libudev-dev 257.13-1~deb13u1.
**As-is on Debian:** PARTIAL.
**Port steps:** trixie: rebuild the forky source package, or `meson setup build --prefix=/usr && meson compile -C build`.
**Complexity:** Low.

### asusctl (`release/packages/asusctl/PKGBUILD`)

**What it does:** ASUS laptop daemon + Aura CLI 6.4.0 from `github.com/OpenGamingCollective/asusctl` (`:3-15`); `cargo build --release --locked -p asusctl -p asusd -p asus-shutdown` (`:18-21`); `make DESTDIR install-asusctl install-asusd install-asus-shutdown install-data-asusd` (`:25`); `conflicts=('asusctl-git' 'tlp')` (`:12`); `.install` reloads systemd/udev and triggers platform devices (`asusctl.install`). Installed only on ASUS hardware (`installation/backend/lib/deploy.sh:127-132` via `ryoku-hw-asus-aura`; `reconcile_asus_aura.go:29`); opt-in (`manifest.go:128`). Upstream 6.4.0: `rust-version = "1.82"`, workspace deps `zbus ^5.18.0`, `udev ^0.9.3`, `rusb ^0.9.4`, `logind-zbus ^5.3.2` (Cargo.toml). `install-data-asusd` installs `/usr/lib/udev/rules.d/99-asusd.rules`, `/usr/share/asusd/<ledcfg>`, `/usr/share/dbus-1/system.d/asusd.conf`, `/usr/lib/systemd/system/asusd.service`, `asus-shutdown.service`, anime data (Makefile `prefix=/usr`, `libdir=$(exec_prefix)/lib`). Ryoku does not build `rog-control-center` or `supergfxctl`.
**Dependencies:**

| Arch (Arch extra now has 6.5.0) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Need |
|---|---|---|---|---|---|---|---|
| asusctl | none (Debian/Ubuntu); supergfxctl none | - | - | - | - | - | 6.4.0 pin (upstream tags 6.5.0) |
| rust (build) | rustc, cargo | 1.85.1+dfsg1-1+deb13u1 | 1.96.1+dfsg1-2~bpo13+1 | 1.96.1+dfsg1-2 | 1.97.1+dfsg1-1 | 1.93.1ubuntu1 | >= 1.82 (Cargo.toml); `--locked` deps may need newer (not verified) |
| clang, llvm (build) | libclang-dev, clang | 1:19.0-63 | - | 1:21.1.8-74 | same | 1:21.1.6-71 | bindgen |
| libusb (build/run) | libusb-1.0-0-dev | 2:1.0.28-1 | - | 2:1.0.30-1 | same | 2:1.0.29-2build1 | |
| udev (build/run) | libudev-dev | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | |
| (build) | pkg-config | 1.8.1-4 | - | 2.5.1-4 | same | 2.5.1-4 | |

**As-is on Debian:** NO.
**Port steps:**
1. Build in a trixie chroot: `apt-get build-dep`-equivalent `cargo rustc libclang-dev clang libusb-1.0-0-dev libudev-dev pkg-config make`; `cargo build --release --locked -p asusctl -p asusd -p asus-shutdown` (network for crates, or `cargo vendor` for an offline build); `make DESTDIR=debian/asusctl install-asusctl install-asusd install-asus-shutdown install-data-asusd`.
2. `Conflicts: tlp`; postinst: `systemctl daemon-reload; udevadm control --reload; udevadm trigger --subsystem-match=platform --action=add` (mirror `asusctl.install`).
3. If trixie's rustc 1.85 fails `--locked`, use trixie-backports rustc 1.96 or a rustup toolchain in the build chroot.
**Complexity:** Medium.
**Issues / risks:** `Conflicts: tlp` on Debian will make apt **remove** tlp when asusctl is requested, whereas Ryoku's conversion "leaves TLP in place" and reports it (`docs/installation-hardware.md:209-212`); the installer must check before installing.

### prowl-agent (`release/packages/prowl-agent/PKGBUILD`)

**What it does:** Go code indexer/MCP server built from commit `506e54fb` as v0.15.6 (`:19`, `:30-31`) with `CGO_ENABLED=1 -tags sqlite_fts5`, `-X main.managedBy=pacman` (`:34-47`); dependency of `ryoku-rashin` (`release/packages/ryoku-rashin/PKGBUILD:29`). go.mod at that commit: `go 1.26.4`, `github.com/mattn/go-sqlite3 v1.14.45`, `github.com/asg017/sqlite-vec-go-bindings v0.1.6`. Upstream latest release v0.17.2 (license MIT per GitHub API; PKGBUILD says `custom`).
**Dependencies:**

| Arch (build) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Need |
|---|---|---|---|---|---|---|---|
| go | golang-1.26-go / golang-go | 1.24.4-1 (golang-1.24-go) | 1.26.9-1~bpo13+1 / golang-go 2:1.27~1~bpo13+1 | 1.26.9-1 / 1.27.2-1 | same | 1.26.8-1~ubuntu0.26.04.2 | >= 1.26.4 (go.mod) |
| gcc | gcc | 4:14.2.0-1 | - | 4:16.1.0-3 | same | 4:15.2.0-5ubuntu1 | cgo |

**As-is on Debian:** NO.
**Port steps:** build with trixie-backports `golang-1.26-go` (or `GOTOOLCHAIN=go1.26.4` download): `CGO_ENABLED=1 GOFLAGS=-mod=mod go build -trimpath -tags sqlite_fts5 -ldflags "-s -w -X main.version=v0.15.6 -X main.managedBy=apt" -o prowl-agent ./cmd/prowl-agent` (whether `managedBy` accepts any value other than `pacman` was not checked); install `/usr/bin/prowl-agent`.
**Complexity:** Medium (toolchain only).

### blesh (`release/packages/blesh/PKGBUILD`)

**What it does:** ble.sh release tarball 0.4.0-devel3 copied to `/usr/share/blesh` (`:2-16`); sourced by `ryoku/apps/bash/ryoku.bash:18-19` (`. /usr/share/blesh/ble.sh --noattach`); in `base.packages:234`.
**Dependencies:** Debian `ble.sh` (binary also `ble.sh`): trixie -, forky 0.4.0~git20250806.8060b7a-2, sid same, resolute 0.4.0~git20250806.8060b7a-1; installs `/usr/share/blesh/ble.sh` (sid file list), the same path. Upstream latest tag v0.4.0-devel3 = Ryoku pin.
**As-is on Debian:** PARTIAL (path matches; version is a git snapshot, trixie lacks it).
**Port steps:** trixie: repack the release tarball exactly as the PKGBUILD (`Architecture: all`, `/usr/share/blesh/`), or backport the forky package.
**Complexity:** Low.

### ryoku-oh-my-zsh (`release/packages/ryoku-oh-my-zsh/PKGBUILD`)

**What it does:** Oh My Zsh at commit `4b657407` copied to `/usr/share/oh-my-zsh` (`:24-31`), provides/replaces `oh-my-zsh`, `oh-my-zsh-git` (`:20-22`); `ryoku-desktop` depends on it (`ryoku-desktop/PKGBUILD:31`); loaded by `ryoku/apps/zsh/ryoku.zsh:15-26` with `ZSH=/usr/share/oh-my-zsh`.
**Dependencies:** none in Debian/Ubuntu (`oh-my-zsh`: `-` everywhere); zsh 5.9-8+b24 trixie / 5.9.2-1+b1 forky / 5.9-8ubuntu3 resolute.
**As-is on Debian:** NO.
**Port steps:** `Architecture: all` deb copying the pinned git tree to `/usr/share/oh-my-zsh`; `Depends: zsh, git`. Drop the Arch `provides/replaces` names.
**Complexity:** Low.

---

## Questions for the human

1. **Admin group for the eleven polkit rules and sudo.** (a) Rewrite every `isInGroup("wheel")` to `isInGroup("sudo")` and create the user in `sudo`: matches Debian/Ubuntu's polkit admin identity (`-Dprivileged_group=sudo`) and stock sudoers; Ryoku's rules diverge textually from upstream Ryoku. (b) Create a `wheel` group and put the user in both `wheel` and `sudo`: rules ship unchanged; two groups to keep in sync; `wheel` alone would leave all non-Ryoku polkit admin prompts asking for a (usually locked) root password.
2. **NVIDIA driver source** (Debian archive 550 / NVIDIA CUDA repo 590-615 / Ubuntu `ubuntu-drivers`), see the NVIDIA section for consequences (Blackwell support, explicit sync, module naming, Secure Boot signing, third-party dkms).
3. **How AUR-routed catalogue items are delivered** (37 items plus `zen-browser-bin`, `qmk-hid`, Looking Glass/kvmfr, `nvibrant`, `davinci-resolve`): Flatpak (no root, auto-updates through `flatpak update`, different presence detection, sandbox differences e.g. Steam/OBS plugins as Flatpak extensions); vendor apt repos (native, but each adds a third-party signing key); upstream `.deb`/tarball downloads (no updates unless Ryoku re-fetches); or Ryoku-built debs in Ryoku's apt repo (maintenance burden per item). The choice also decides whether `bundle.json` gains per-distro fields (ryostore repo change) or the actuator carries a Debian route table.
4. **cachyos-layer bundle and `requires: cachyos` on Debian:** hide it, map it to a Debian-side kernel (trixie-backports 7.2, Liquorix, XanMod) plus Ryoku-built ananicy-cpp/scx packages, or have Ryoku build CachyOS-patched kernels as debs. scx schedulers need `CONFIG_SCHED_CLASS_EXT`, absent from trixie's 6.12 kernel.
5. **Docker:** `docker.io` (Debian) vs `docker-ce` (Docker Inc.), see containers section.
6. **Recommends policy for `ryoku-pkg-add`:** apt installs Recommends by default (pacman has none); `--no-install-recommends` matches Arch's footprint but drops functionality some packages expect (alternative: `--no-install-recommends` plus a hand-picked keep-list).

## Cross-cutting findings

- `wheel` vs `sudo`: affects the installer (`installation/backend/lib/chroot.sh:117,131-134`), all polkit rules, and the CLI doctor wherever it checks group membership.
- `pkexec` must be an explicit dependency on Debian/Ubuntu (separate package).
- pacman hook replacements needed: `ryoku-nvidia.hook` (kernel postinst.d + dpkg trigger), `94/95-ryoku-power-cutover*.hook` (maintainer scripts or apt `DPkg::Pre-Install-Pkgs`/`Post-Invoke`). Nothing may be installed to `/usr/share/libalpm/hooks/`. dpkg/apt locks are fcntl locks on always-present files; existence tests like `/var/lib/pacman/db.lck` have no equivalent.
- mkinitcpio -> initramfs-tools: `/etc/mkinitcpio.conf.d/nvidia.conf` (nvidia.sh, guard, doctor `reconcile_hardware.go`), `limine-mkinitcpio` calls (guard, backlight-fix, doctor), `ryoku-gpu-trim` (boot port).
- Debian archive NVIDIA modules are renamed (`nvidia-current`, `nvidia-current-open`); every `modinfo ... nvidia` probe (nvidia.sh, guard, `reconcile_hardware.go`) and the `lsmod`-style "loaded == nvidia" check (`reconcile_hardware.go` `nvidiaDriverActiveFor`) must accept those names if the archive driver is used. The kernel's internal module name was not verified.
- The CLI doctor has Go mirrors of nvidia.sh (`ryoku/cli/internal/doctor/reconcile_hardware.go:190-470`), the Kepler 580xx removal (`pacman -R`), QMK install via `ryoku-pkg-aur-add` (`reconcile_qmk.go:18`), Limine AUR installs (`reconcile_limine.go:694-696`); the Hub's passthrough enable builds Looking Glass + kvmfr from the AUR (`ryoku/hub/backend/gpuapply.go:72-97`); `ryovm` calls `ryoku-pkg-add`/`-aur-add` (`ryoku/apps/ryovm/bin/ryovm:145-147`). All need the same apt/route rewrite.
- `system/hardware/README.md:222` says "`pacman` does the installing"; doc text to update.
- `ryoku-desktop/PKGBUILD:518-521` installs every executable `system/hardware/*/ryoku-*` to `/usr/bin`, which includes the sourced library `ryoku-gpu-detect`; the deb should replicate the glob (non-executable unit files are skipped by the `-x` test).
- `/etc/conf.d/` does not exist on Debian; any other Ryoku code writing there needs a Debian path (only `ryoku-wifi-regdom` in this scope).
- Kernel features Ryoku's measurements assume (asus-armoury, `sched_ext`, platform-profile class) are absent in trixie's 6.12 and present in Debian's 7.2 (trixie-backports/forky/sid) per `debian/config` files; the kernel choice is shared with the boot port.
- Mesa version: trixie 25.0.7 vs Arch 26.2.5; i386 Mesa must match the amd64 source.
- Ubuntu 26.04 specifics to recheck: sudo-rs and Rust coreutils defaults, snap-only `firefox`/`chromium`, possible `tuned-ppd` default instead of `power-profiles-daemon`.
- Doc drift found: `system/extras/README.md:15` (`ryoku-hub extras cache` vs `ryostore internal cache`); `docs/preinstalled.md:266-267` (game-devices-udev, xpadneo-dkms "from the AUR" vs `[ryoku]` base packages); `ryoku-docker:69` (`47-` vs `46-ryoku-docker.rules`); `ryoku-gpu-lib32:6-7` ("base install is 64-bit only" vs `hardware.packages` lib32 lines); `xpadneo-dkms/PKGBUILD:23-27` vs `docs/installation-hardware.md:283-310` on xone.
- Security fact that ports as-is: `50-ryoku-dns.rules:10` authorizes any program path ending in `ryoku-dns` without a password; `54-ryoku-bluetooth-a2dp.rules` lacks `active`/`local` checks.

## Debian package list for this section

Runtime (archive): `pciutils`, `udev`, `systemd`, `kmod`, `coreutils`, `util-linux`, `procps`, `psmisc`, `jq`, `polkitd`, `pkexec`, `sudo`, `dbus-bin`, `upower`, `power-profiles-daemon`, `hypridle` (trixie-backports or Ryoku build), `brightnessctl`, `pulseaudio-utils`, `pipewire`, `pipewire-pulse`, `wireplumber`, `bluez`, `usbutils`, `network-manager`, `iwd`, `wpasupplicant`, `iw`, `wireless-regdb`, `nftables`, `ddcutil`, `i2c-tools`, `initramfs-tools`, `dkms`, `linux-headers-amd64`, `libgl1-mesa-dri`, `libglx-mesa0`, `libegl-mesa0`, `mesa-va-drivers`, `mesa-vulkan-drivers`, `libvulkan1`, `intel-media-va-driver-non-free`, `libmfx-gen1.2`, `firmware-sof-signed`, `firmware-amd-graphics`, `firmware-intel-graphics`, `firmware-misc-nonfree`, `amd64-microcode`, `intel-microcode`, `broadcom-sta-dkms`, `flatpak`, `kitty`, `docker.io` (or `docker-ce`), `zsh`, `git`.
NVIDIA (per GPU; archive names): `nvidia-open-kernel-dkms`, `nvidia-kernel-dkms`, `nvidia-driver-libs`, `nvidia-driver-libs:i386`, `nvidia-vulkan-icd`, `nvidia-smi`, `nvidia-suspend-common`, `firmware-nvidia-gsp`, `nvidia-vaapi-driver`, `libnvidia-egl-wayland1`, `libnvidia-egl-gbm1`, `nvidia-detect`; NVIDIA CUDA repo alternative: `cuda-keyring`, `nvidia-open`, `nvidia-kernel-open-dkms`, `nvidia-driver`, `nvidia-driver-pinning-<branch>`; Ubuntu: `ubuntu-drivers-common`, `nvidia-driver-<br>-open`, `linux-modules-nvidia-<br>-open-generic`.
i386 (Gaming bundle): `libgl1-mesa-dri:i386`, `libglx-mesa0:i386`, `libegl-mesa0:i386`, `libvulkan1:i386`, `mesa-vulkan-drivers:i386`.
Archive packages available for hardware extras on some suites: `xpadneo-dkms` (forky/sid), `dualsensectl` (forky/sid/resolute), `ble.sh` (forky/sid/resolute), `steam-devices`.
Ryoku-built debs: `gpk`, `asusctl`, `game-devices-udev`, `broadcom-bt-firmware`, `prowl-agent`, `ryoku-oh-my-zsh`, `blesh` (trixie), `xpadneo-dkms` (trixie/resolute), `dualsensectl` (trixie), `ryotunes`.
Build-only: `build-essential`, `debhelper`, `dh-dkms`, `meson`, `cargo`, `rustc` (trixie-backports for >1.85), `clang`, `libclang-dev`, `libusb-1.0-0-dev`, `libudev-dev`, `pkg-config`, `golang-1.26-go` (trixie-backports), `gcc`, `libhidapi-dev`, `libdbus-1-dev`.
Bundle catalogue (archive, on demand): `build-essential`, `gh`, `curl`, `wget`, `ripgrep`, `fd-find`, `fzf`, `tmux`, `cmake`, `ninja-build`, `gdb`, `clang`, `lldb`, `python3`, `python3-pip`, `nodejs`, `npm`, `rustup`, `golang-go`, `openjdk-25-jdk`, `docker-compose`, `steam-installer`, `lutris`, `wine`, `wine64`, `wine32:i386`, `winetricks`, `protontricks`, `libvkd3d1`, `libvkd3d1:i386`, `gamemode`, `libgamemode0:i386`, `gamescope`, `mangohud`, `mangohud:i386`, `goverlay`, `vkbasalt`, `retroarch`, `libretro-core-info`, `libretro-snes9x`, `libretro-genesisplusgx`, `libretro-beetle-psx`, `dolphin-emu`, `pcsx2`, `mgba-qt`, `mame`, `scummvm`, `dosbox`, `corectrl`, `sc-controller`, `cmatrix`, `cbonsai`, `cava`, `fastfetch`, `btop`, `figlet`, `lolcat`, `toilet`, `cowsay`, `sl`, `pipes-sh`, `tty-clock`, `obs-studio`, `obs-pipewire-audio-capture`, `v4l2loopback-dkms`, `gpu-screen-recorder`, `wf-recorder`, `kdenlive`, `easyeffects`, `audacity`, `gimp`, `inkscape`, `krita`, `yt-dlp`, `handbrake`, `shotcut`, `blender`, `darktable`, `wireguard-tools`, `openvpn`, `network-manager-openvpn`, `network-manager-strongswan`, `proton-vpn-gtk-app`, `firefox-esr`, `chromium`.

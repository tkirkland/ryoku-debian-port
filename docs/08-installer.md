# 08 — Installers: ISO backend, installer TUI, shell installer, install tests

Scope: everything that turns a machine into Ryoku. That is the ISO install backend
(`installation/backend/ryoku-install` + every `lib/*.sh`), the Bubble Tea installer TUI
(`installation/tui/`, including the `RYOKU_*` hand-off contract and its gates), the
live-session glue the TUI depends on (`installation/iso/airootfs/usr/local/bin/*`, only
where the TUI relies on it), the "convert an existing machine" installer
(`ryoku-shell-installer/`: `install.sh` bootstrap + the `ryoku-shell-install` Go TUI),
the install tests (`installation/tests/*`, `tests/install-*.sh`,
`tests/installer-session-scale.sh`) and the installer docs
(`docs/installation-hardware.md`, installer parts of `docs/development.md`). The
per-hardware driver scripts (`system/hardware/drivers/*.sh`) and the boot templates
(`system/boot/{limine,mkinitcpio}/*`) are covered only as far as the installer calls them;
the ISO builder (`installation/iso/build.sh`, `offline-repo.sh`, `profiledef.sh`), the
package-set translation (`system/packages/*.packages` beyond the bootstrap subset), the
`[ryoku]` repo pipeline and `ryoku doctor` belong to other port documents. Source pinned at
`98a0368253d9628be72b853985878a5db90e1547`. Debian/Ubuntu versions below were queried on
2026-10-17 (madison for Debian incl. non-free components, Canonical madison for resolute).

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| `RYOKU_*` contract | `installation/backend/ryoku-install`, `installation/tui/system.go` | PARTIAL | Low | `RYOKU_ONLINE`/`RYOKU_OFFLINE_REPO`/`RYOKU_VARIANT`/`RYOKU_PROFILE` carry Arch semantics |
| Orchestrator + helpers | `installation/backend/ryoku-install`, `lib/common.sh`, `lib/i18n.sh` | PARTIAL | Low | stage order calls pacstrap/mkinitcpio/limine-hook steps |
| Preflight + Secure Boot gate | `lib/preflight.sh` | YES | Low | Limine still unsigned on Debian |
| Network gates (DNS, HTTP, clock-skew heal) | `lib/network.sh:134-230` | PARTIAL | Low | probe hosts are Arch mirrors |
| Mirror ranking | `lib/mirrors.sh` | NO | Low | reflector + archlinux.org API + pacman.conf tuning |
| Keyring init | `lib/pacstrap.sh:18-39` | NO | Low | pacman-key/pacman-init.service |
| Partitioning / alongside / carve | `lib/disk.sh`, `lib/resize.sh` | YES | Low | none (util-linux, gdisk, parted, jq, ntfs-3g, e2fsprogs, btrfs-progs exist) |
| LUKS | `lib/luks.sh` | YES | Low | none |
| Filesystems + subvolumes + swapfile | `lib/filesystem.sh` | PARTIAL | Low | `@pkg` mounts `/var/cache/pacman/pkg` |
| Base bootstrap + fstab | `lib/pacstrap.sh` | NO | Medium | pacstrap → mmdebstrap; Arch package names; `vulkan-driver` provider logic |
| Offline install | `lib/offline.sh` | NO | High | pacman `file://` repo + pacman.conf juggling → baked apt repo |
| Configure in chroot | `lib/chroot.sh` | NO | Medium | `wheel` group missing on Debian; mkinitcpio; locale/vconsole files; pacman hook masks |
| CachyOS variant | `lib/cachyos.sh` | NO | n/a | no Debian equivalent of the CachyOS repos |
| Desktop deploy | `lib/deploy.sh` | NO | Medium | needs a signed Ryoku **apt** repo; pacman-key; `/usr/lib/initcpio` seed |
| Network persistence | `lib/network.sh:29-132` | YES | Low | needs `arch-install-scripts` (arch-chroot) or a chroot wrapper |
| GPU drivers | `lib/drivers.sh` + `system/hardware/drivers/*.sh` | NO | High | NVIDIA branch matrix differs (Debian 550 / NVIDIA repo 590+ / Ubuntu 580-595) |
| Bootloader + services | `lib/bootloader.sh` | NO | High | Limine and limine-entry-tool are not packaged on Debian/Ubuntu; mkinitcpio; kernel file names; `cryptdevice=` cmdline |
| AUR step | `lib/aur.sh` | NO | Medium | no AUR; 9 packages need another source |
| Snapshots | `lib/snapshots.sh` | PARTIAL | Medium | `/etc/conf.d/snapper` → `/etc/default/snapper`; limine-snapper-sync unpackaged |
| Installer TUI | `installation/tui/` | PARTIAL | Low | `/run/archiso` live-medium detection; Arch probe URL; Arch strings; pacman offline-db test |
| Shell installer | `ryoku-shell-installer/` | PARTIAL | High | a Debian path exists but builds from source (violates cardinal rule 7), skips GPU drivers, has an incomplete package rename map |
| Install tests | `installation/tests/`, `tests/install-*.sh` | PARTIAL | Medium | container/VM tests are pacman/archiso-only; most fixture tests are neutral |

---

## 0. The `RYOKU_*` environment contract

The TUI builds the environment in `installEnv()` (`installation/tui/system.go:1055-1147`),
appends it to its own environment and execs `$RYOKU_BACKEND` or `ryoku-install`
(`system.go:1234-1257`). The backend defaults/validates at
`installation/backend/ryoku-install:76-142`. Documented contract:
`installation/backend/README.md:42-92`.

| Variable | Values / default | Set by | Read by (cite) | Debian change |
|---|---|---|---|---|
| `RYOKU_DISK` | block device, required | TUI `system.go:1064` | `ryoku-install:107,122`; `preflight.sh:55-68`; `disk.sh:221,276`; `bootloader.sh:486,532,608` | none |
| `RYOKU_DISK_STRATEGY` | `whole`\|`alongside`, required, no default | TUI `system.go:1068` | `ryoku-install:87,126-138`; `disk.sh:46-51`; `bootloader.sh:34,70,435` | none |
| `RYOKU_HOSTNAME` | default `ryoku` | TUI `system.go:1069` | `chroot.sh:102-111` | also write `127.0.1.1 <host>` to `/etc/hosts` (see §11) |
| `RYOKU_USERNAME` | default `ryoku` (TUI default `you`, `main.go:539`) | TUI `system.go:1070` | `chroot.sh:113-127`, `deploy.sh:19-33`, `aur.sh:32`, `drivers.sh:82` | none |
| `RYOKU_PASSWORD_HASH` | `$6$` sha512-crypt, required | TUI `system.go:1071` (hash from `password.go:41-49`) | `chroot.sh:121-126` (`chpasswd -e`) | none (Debian libxcrypt verifies `$6$`) |
| `RYOKU_KEYMAP` | console keymap, default `us` | TUI `system.go:1072` | `chroot.sh:44-48` (`/etc/vconsole.conf`), `deploy.sh:275` | Debian console keymap comes from XKB via `/etc/default/keyboard` (§11) |
| `RYOKU_XKB_LAYOUT` / `RYOKU_XKB_VARIANT` | derived from keymap (`system.go:919-940`) | TUI `system.go:1073-1074` | `chroot.sh:53-66`, `deploy.sh:274-291` | feed `/etc/default/keyboard` XKBLAYOUT/XKBVARIANT |
| `RYOKU_LOCALE` | default `en_US.UTF-8` | TUI `system.go:1075` | `chroot.sh:19-42`, `network.sh:113-116` | `update-locale` + `/etc/default/locale` (§11) |
| `RYOKU_LANG` | UI language | TUI `system.go:1078` | `i18n.sh:38` | none |
| `RYOKU_TIMEZONE` | `Region/City` or `auto`, default `UTC` | TUI `system.go:1079` | `chroot.sh:69-100` | none (plus `dpkg-reconfigure tzdata`, §11) |
| `RYOKU_PROFILE` | `amd-nvidia`\|`amd`\|`intel`\|`vm`, default `vm` | TUI `system.go:1080` (suggested by `system.go:831-844`) | `pacstrap.sh:49-56`, `bootloader.sh:265` | section names stay; the per-section package lists must be Debian names (§9) |
| `RYOKU_ESP_GIB` | default `1` (TUI default 1, `main.go:948`) | TUI `system.go:1081` | `disk.sh:222` | none |
| `RYOKU_ESP_MODE` | `auto`\|`shared`\|`dedicated` | TUI `system.go:1083` | `ryoku-install:89,131-138`, `preflight.sh:84-97` | none |
| `RYOKU_SWAP_GIB` | default `0` (TUI default 16, `main.go:948`) | TUI `system.go:1082` | `filesystem.sh:38,79-92`, `bootloader.sh:274`, `disk.sh:7` | none |
| `RYOKU_SUBVOL_SNAPSHOTS` / `_HOME` / `_BACKUPS` | `1`/`1`/`0` | TUI `system.go:1084-1086` | `filesystem.sh:30-57`, `snapshots.sh:10` | none |
| `RYOKU_REPO` | payload root, default `/usr/share/ryoku` | ISO session `ryoku-installer-session:19` | everywhere (`preflight.sh:74`, `pacstrap.sh:42-75`, `deploy.sh:99,300-325`, `drivers.sh:11`, `bootloader.sh:332,364,413`) | none |
| `RYOKU_VARIANT` | `plain`\|`cachyos`, from `$RYOKU_REPO/variant` | ISO build (`installation/iso/build.sh:194`), not the TUI | `ryoku-install:98-99,197`; `pacstrap.sh:74-79`; `bootloader.sh:163,358,648` | `cachyos` has no Debian meaning (§12); either drop or repurpose as base-suite marker |
| `RYOKU_ONLINE` | `0`/`1`, default `1` | TUI `system.go:1090-1096` | `mirrors.sh:35`, `network.sh:95,147,190`, `chroot.sh:72`, `deploy.sh:136-174`, `aur.sh:43`, `offline.sh:20,32` | same semantics; offline = baked apt repo |
| `RYOKU_OFFLINE_REPO` | default `/usr/share/ryoku/offline/repo` | TUI `system.go:1093` | `offline.sh:14-41,47-69,98-165` | now points to an apt repo, not a pacman repo |
| `RYOKU_PACMAN_CONF` | internal (offline pacstrap conf) | `offline.sh:67` | `pacstrap.sh:121`, `mirrors.sh:175`, driver scripts (`nvidia.sh:56,120`) | replaced by apt `-o Dir::Etc::sourcelist=…` options (§10) |
| `RYOKU_COMPOSITOR` / `RYOKU_COMPOSITOR_CONFIG_DIR` | e.g. `hyprland` / `hypr`, required | TUI `system.go:1099-1100` (`wm.ConfigDir`) | `ryoku-install:124-125`, `deploy.sh:126`, `drivers.sh:82-92` | none |
| `RYOKU_GPU_MODE` | `offload`\|`sync`\|`vfio` | TUI `system.go:1101-1103` (hybrid only, `main.go:1519-1522`) | `drivers.sh:73-101` | none |
| `RYOKU_ENCRYPT` / `RYOKU_LUKS_PASSPHRASE` | `1` + passphrase | TUI `system.go:1104-1106` | `ryoku-install:142`, `luks.sh:8-42`, `chroot.sh:149,170-178`, `bootloader.sh:256-260` | cmdline syntax changes (§16) |
| `RYOKU_RESIZE_PART` / `RYOKU_RESIZE_TAKE_MIB` | carve request | TUI `system.go:1114-1118` | `resize.sh:17-129`, `preflight.sh:79,175-195` | none |
| `RYOKU_REGION_START` / `_END` | free-region sectors | TUI `system.go:1119-1122`; also exported by `resize.sh:126-127` | `disk.sh:331-334` | none |
| `RYOKU_WIPE_CONFIRMED` | `1` after typed ERASE | TUI `system.go:1130-1133` | `disk.sh:233` | none |
| `RYOKU_RECLAIM_LEFTOVERS` | `1` after typed ERASE (alongside) | TUI `system.go:1134-1143` | `disk.sh:475` | none |
| `RYOKU_REBOOT` | non-empty reboots | manual only | `ryoku-install:234-237` | none |
| `RYOKU_SKIP_AUR` | non-empty skips AUR | manual/tests (`install-vm.py:170`) | `aur.sh:39` | becomes "skip third-party extras" |
| `RYOKU_ALLOW_SECUREBOOT` | `1` overrides SB gate | manual | `preflight.sh:50` | none |
| `RYOKU_ALLOW_DIRTY_NTFS` | `1` overrides Fast Startup gate | manual | `preflight.sh:156` | none |
| `RYOKU_REGDOM` | ISO 3166 country | manual | `network.sh:93-94` | none |
| `RYOKU_DRYRUN` | non-empty = print only | manual/tests | `common.sh:52-120` and every lib | none |
| `RYOKU_BACKEND` | backend path | ISO session `ryoku-installer-session:20` | `system.go:500,621,1238` | none |
| `RYOKU_SESSION`, `RYOKU_KB_PRESET`, `RYOKU_XKB`, `XKB_DEFAULT_*` | live-session glue | `ryoku-installer-session:137,174-177` | `system.go:951-955`, `main.go:551,901` | none |
| `RYOKU_ASCII` | glyph fallback | manual | `main.go:143` | none |
| Test seams: `RYOKU_SB_VAR`, `RYOKU_MIRRORLIST`, `RYOKU_RESOLV_CONF`, `RYOKU_DNS_PROBE_HOSTS`, `RYOKU_MIRROR_PROBE_URLS`, `RYOKU_PROC_MOUNTS`, `RYOKU_PROC_SWAPS`, `RYOKU_REPO_SERVER`, `RYOKU_REPO_SIGLEVEL`, `RYOKU_ALONGSIDE_BOOT_LABEL`, `RYOKU_I18N_DIR`, `RYOKU_MODULES_DIR`, `RYOKU_SYSFS` | tests | — | `preflight.sh:15`, `mirrors.sh:20,175`, `network.sh:154,172,193`, `disk.sh:131-132`, `deploy.sh:64-65`, `filesystem.sh:22`, `i18n.sh:28`, `nvidia.sh:142,156`, `ryoku-installer-session:46` | `RYOKU_MIRRORLIST`, `RYOKU_PACMAN_CONF`, `RYOKU_REPO_SIGLEVEL`, `RYOKU_MODULES_DIR` change meaning; the rest are neutral |
| Progress sentinels | `@@RYOKU_STEP <id>` ×6, `@@RYOKU_DONE` | backend `common.sh:31`, `ryoku-install:231` | TUI `system.go:1198-1206,1265-1273` | none (stage ids `pacstrap` and `bootloader` can keep their names; they are just ids) |

Doc vs code: `installation/backend/README.md:20-22` says "the install is online-only";
the code default on an ISO with a baked repo is offline (`system.go:1090-1093`,
`README.md:130-137` itself). `installation/tui/README.md:58-62` says `netOnline()` returns
true on an offline ISO; the code no longer does (`system.go:1292-1299`).

---

## 1. The install sequence as it runs today

All steps run as root on the live ISO with the target mounted at `/mnt`. `run`/`run_sh`
close stdin (`common.sh:52-68`), so any prompt reads EOF.

| # | Stage sentinel | Function (file:line) | Commands run | Written on target / live system | Debian replacement (detail in the section) |
|---|---|---|---|---|---|
| 0 | — | `probe alongside\|resize` (`ryoku-install:62-74`) | `blkid`, `sfdisk --json`, `jq`, `sgdisk -p`, read-only `mount`, `ntfsresize --info`, `dumpe2fs`, `resize2fs -P`, `btrfs filesystem show` (`disk.sh:785-1035`) | nothing | unchanged |
| 1 | (preflight) | `ryoku_preflight` (`preflight.sh:22-82`) | `lsblk`, `blockdev`, efivar read, `blkid`, `sgdisk`, `ntfsresize --info` | nothing | unchanged (§2) |
| 2 | | `ryoku_offline_verify` (`offline.sh:31-41`) | `compgen -G offline.db*` | nothing | test for an apt repo (`Packages`/`InRelease`) (§10) |
| 3 | | `ryoku_ensure_dns` (`network.sh:142-164`) | `getent hosts archlinux.org geo.mirror.pkgbuild.com` | live `/etc/resolv.conf` (heal) | probe `deb.debian.org`/`archive.ubuntu.com` (§3) |
| 4 | | `ryoku_ensure_mirrors` (`network.sh:184-208`) + `ryoku_fix_clock_skew` (`:217-230`) | `curl -fsSI core.db` + `ryoku.db`; `curl -ksI` Date; `date -s` | live clock | probe `dists/<suite>/InRelease` + Ryoku apt `InRelease` (§3) |
| 5 | | `ryoku_ensure_keyring` (`pacstrap.sh:24-39`) | `systemctl start pacman-init.service`, `pacman-key --init/--populate archlinux` | live keyring | check `/usr/share/keyrings/{debian,ubuntu}-archive-keyring.gpg` + Ryoku key (§5) |
| 6 | `partition` | `ryoku_carve` (`resize.sh:17-129`) | `ntfsresize`/`e2fsck`+`resize2fs`/`btrfs filesystem resize`/`mkswap`, `sfdisk -N`, `partprobe`, `sgdisk -v/-i` | shrinks one partition | unchanged (§6) |
| 7 | | `ryoku_partition` (`disk.sh:42-52`) → `_whole` (`:220-273`) or `_alongside` (`:275-429`) | `swapoff/umount/cryptsetup close/vgchange/mdadm --stop`, `sgdisk --zap-all`, `wipefs`, `parted mklabel gpt/mkpart/set esp`, or `sgdisk -n …-t ea00/ef00,8300 -c ryokuboot/ryoku` | GPT | unchanged |
| 8 | | `ryoku_luks` (`luks.sh:8-42`) | `cryptsetup luksFormat --type luks2 --pbkdf argon2id`, `cryptsetup open … root` | LUKS2 header | unchanged |
| 9 | `filesystems` | `ryoku_filesystems` (`filesystem.sh:19-40`) | `mkfs.vfat -F32 -n BOOT\|RYOKUBOOT`, `mkfs.btrfs -L ryoku`, `btrfs subvolume create @ @home @log @pkg @snapshots @backups @swap` | filesystems | `@pkg` → apt cache (§8) |
| 10 | `mount` | `ryoku_mount` (`filesystem.sh:42-77`), `ryoku_swapfile` (`:79-92`) | `mount -o compress=zstd:1,noatime,subvol=…`, ESP at `/mnt/boot`, `btrfs filesystem mkswapfile`, `swapon` | mount tree, `/swap/swapfile` | ESP/boot layout decision (§16, Q3) |
| 11 | `pacstrap` | `ryoku_offline_prepare` (`offline.sh:47-69`) | writes `/tmp/ryoku-offline-pacman.conf` | live | apt source override (§10) |
| 12 | | `ryoku_rank_mirrors` (`mirrors.sh:19-70`) | `reflector`, `curl archlinux.org/mirrors/status/json`, `jq`, `sed` on `pacman.conf` | live `/etc/pacman.d/mirrorlist`, `/etc/pacman.conf` | Debian mirror choice (§4) |
| 13 | | `ryoku_hooks_quiet` (`chroot.sh:220-227`) | `ln -sf /dev/null /mnt/etc/pacman.d/hooks/{05-snap-pac-pre,zz-snap-pac-post,80-limine-efi-deploy}.hook` | `/etc/pacman.d/hooks` | `policy-rc.d` + snapper `DISABLE_APT_SNAPSHOT` + limine-deploy guard (§11) |
| 14 | | `ryoku_pacstrap` (`pacstrap.sh:41-104`) | `pacstrap [-C conf] -K /mnt --noconfirm <base+hw+dev[+cachy][+broadcom-wl-dkms]>`, retries `--needed [--overwrite '*']`; `genfstab -U /mnt >> /mnt/etc/fstab` | whole base system; `/etc/fstab` | `mmdebstrap` + `genfstab` (from Debian `arch-install-scripts`) (§9) |
| 15 | | `ryoku_hooks_defer_mkinitcpio` (`chroot.sh:207-218`) | masks `90-mkinitcpio-install.hook`, `60-mkinitcpio-remove.hook` | `/etc/pacman.d/hooks` | `update_initramfs=no` or `dpkg-divert` (§11) |
| 16 | `configure` | `ryoku_cfg_locale` (`chroot.sh:19-42`) | `sed` `/etc/locale.gen`, `arch-chroot locale-gen` | `/etc/locale.gen`, `/etc/locale.conf` | `/etc/default/locale` + `update-locale` (§11) |
| 17 | | `ryoku_cfg_keymap` (`chroot.sh:44-67`) | — | `/etc/vconsole.conf`, `/etc/X11/xorg.conf.d/00-keyboard.conf` | `/etc/default/keyboard` + `dpkg-reconfigure keyboard-configuration console-setup` |
| 18 | | `ryoku_cfg_timezone` (`chroot.sh:69-100`) | `curl ipinfo.io/timezone`, `ln -sf zoneinfo`, `arch-chroot hwclock --systohc`, `systemctl enable systemd-timesyncd` | `/etc/localtime`, `/etc/adjtime` | same + `util-linux-extra` for `hwclock` |
| 19 | | `ryoku_cfg_hostname` (`chroot.sh:102-111`) | — | `/etc/hostname` | + `/etc/hosts` 127.0.1.1 |
| 20 | | `ryoku_cfg_user` (`chroot.sh:113-127`) | `useradd -m -G wheel,video,input -s /usr/bin/fish`, `chpasswd -e` ×2 | `/etc/passwd`, `/etc/shadow`, `/home/<u>` | `wheel` does not exist on Debian (§11) |
| 21 | | `ryoku_cfg_sudo` (`chroot.sh:129-135`) | `chmod 0440` | `/etc/sudoers.d/10-wheel` | `sudo` group already in Debian sudoers |
| 22 | | `ryoku_cfg_initramfs` (`chroot.sh:137-168`) | — | `/etc/mkinitcpio.conf.d/ryoku.conf` | `/etc/dracut.conf.d/ryoku.conf` or `/etc/initramfs-tools/*` |
| 23 | | `ryoku_cfg_crypttab` (`chroot.sh:170-178`) | `blkid` | `/etc/crypttab` (`root UUID=… none luks`) | same line works; add `cryptsetup-initramfs` or dracut `crypt` |
| 24 | | `ryoku_cachyos_repo` (cachyos only) (`ryoku-install:197`, `cachyos.sh:12-111`) | `sed` pacman.conf, `pacman-key --populate cachyos` | `/etc/pacman.conf` | none (§12) |
| 25 | | `ryoku_offline_chroot_on` (`offline.sh:104-124`) | `mount --bind` repo into `/mnt`, write `/etc/pacman.d/ryoku-offline.conf`, append `[offline]` | target pacman.conf | bind + store-only apt options (§10) |
| 26 | | `ryoku_deploy` (`deploy.sh:18-33`) | `[ryoku]` stanza, `cp mirrorlist`, `pacman-key --populate ryoku`, `pacman -Sy`, `pacman -S ryoku-keyring ryoku-desktop ryoku-desktop-<wm> [asusctl]`, `runuser … ryoku materialize`, seeds, `chown -R`, `ryoku-sddm-setup`, `ryoku-install-qylock` | pacman.conf, keyring, packages, `~/.config`, `~/Pictures/Wallpapers`, `/usr/share/ryoku/qylock`, SDDM theme/conf, `/usr/lib/initcpio/install/ryoku-gpu-trim` (if missing) | Ryoku apt repo + `apt-get install` (§13) |
| 27 | | `ryoku_network` (`network.sh:29-132`) | `cp *.nmconnection`, `arch-chroot ryoku-wifi-regdom set CC` | `/etc/NetworkManager/conf.d/wifi-backend.conf`, `system-connections/` | unchanged (§14) |
| 28 | | `ryoku_drivers` (`drivers.sh:9-45`) | per vendor `timeout 900 arch-chroot bash ryoku-driver-<v>.sh` (pacman inside); `ryoku-hw-backlight-fix`; `ryoku-gpu mode` | driver packages, `/etc/modprobe.d/nvidia.conf`, `/etc/mkinitcpio.conf.d/nvidia.conf`, `/etc/pacman.d/hooks/ryoku-nvidia.hook`, `/etc/limine-entry-tool.d/ryoku-backlight.conf`, `~/.config/hypr/gpu.lua` | Debian driver scripts (§15) |
| 29 | | `ryoku_offline_aur` (`offline.sh:173-193`), `ryoku_offline_chroot_off` (`:149-165`) | `pacman --config … -Sp/-S` | AUR toolset; cleans pacman.conf | repo packages (§17) |
| 30 | `bootloader` | `ryoku_bootloader` (`bootloader.sh:23-42`) | `plymouth-set-default-theme ryoku`; write `/etc/default/limine`; VMD drop-in; `limine-mkinitcpio` + `limine-update` or `mkinitcpio -P`; `ryoku-windows-entry sync`; `cp BOOTX64.EFI`; `efibootmgr --create/--bootnext`; alongside: two-stage hop, ESP tar backup, `/etc/kernel/cmdline`, `/efi` fstab line, `ryoku-limine-stage.hook`; `systemctl enable sddm NetworkManager bluetooth rtkit-daemon power-profiles-daemon` | `/boot/limine.conf`, `/boot/EFI/{limine,BOOT}/`, `/etc/default/limine`, `/etc/ryoku/default-kernel`, `/etc/mkinitcpio.conf.d/ryoku-vmd.conf`, NVRAM | Limine .deb + Debian initramfs + Debian kernel names (§16) |
| 31 | — | `ryoku_aur` (`aur.sh:31-136`) | temp NOPASSWD sudoers, `pacman -S base-devel git curl`, `git clone yay-bin` + `makepkg -si` (or GitHub binary), `yay -S` boot-critical then rest | AUR packages | repo packages (§17) |
| 32 | — | `ryoku_default_browser` (`aur.sh:143-163`) | `xdg-mime default zen.desktop x-scheme-handler/http(s)` | `~/.config/mimeapps.list` | unchanged if Zen ships |
| 33 | — | `ryoku_bootloader_finalize` (`bootloader.sh:69-130`) | awk surgery on `/boot/limine.conf`; alongside: pin `TARGET_OS_NAME`/`FIND_BOOTLOADERS=no`/`EFI_REGISTER=no`, `limine-update` | `/boot/limine.conf`, `/etc/default/limine` | depends on the limine-entry-tool port (§16) |
| 34 | — | `ryoku_snapshots` (`snapshots.sh:9-117`) | `systemctl enable snapper-cleanup.timer limine-snapper-sync.service`, `sed updatedb.conf` | `/etc/snapper/configs/root`, `/etc/conf.d/snapper`, `/etc/ryoku/snapshots-disabled`, `/etc/updatedb.conf` | `/etc/default/snapper` (§18) |
| 35 | — | `ryoku_hooks_restore` (`chroot.sh:229-239`), `sync`, `swapoff -a`, `umount -R /mnt`, `@@RYOKU_DONE`, optional `reboot` (`ryoku-install:222-237`) | — | removes masks | remove `policy-rc.d`, re-enable initramfs updates |
| ✗ | — | EXIT trap `ryoku_on_exit` (`ryoku-install:247-259`) | names the stage, restores hooks, `offline_chroot_off`, `sync`, leaves `/mnt` mounted | — | same, plus remove `policy-rc.d` and the initramfs deferral |

---

## Component sections

### Orchestrator + shared helpers (`installation/backend/ryoku-install`, `lib/common.sh`, `lib/i18n.sh`)

**What it does:** Sources 18 libs (`ryoku-install:24-57`), runs the read-only probes
(`:62-74`), defaults and validates the contract (`:76-142`), runs the stage list in `main`
(`:144-238`), and installs an EXIT trap that names the failed stage and leaves `/mnt`
mounted (`:247-259`). `common.sh` provides `log`/`step`/`die` (translated via `i18n.sh`),
the dry-run wrappers `run`/`run_sh`/`run_secret`/`write_file`/`append_file`/`deploy_dir`,
and `part_dev`/`part_num`/`dev_uuid` (`common.sh:16-154`). `i18n.sh` loads
`ryoku/i18n/catalog/<lang>.json` with one `jq` pass (`i18n.sh:54-67`).

**Arch couplings:**
- `ryoku-install:4,8` comments ("Ryoku Arch install backend", pacstrap).
- Stage order is built around pacman semantics: hook masks before/after pacstrap
  (`ryoku-install:178-190`), CachyOS repo step (`:197`), offline `[offline]` window
  (`:200-207`), limine hook promotion after AUR (`:216-219`).
- `ryoku-install:98` reads `$RYOKU_REPO/variant` (plain/cachyos).
- `common.sh` and `i18n.sh`: no distro coupling (bash, `jq`, coreutils `printf` at `i18n.sh:90-91`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs |
|---|---|---|---|---|---|---|---|---|
| bash | everything | bash | (essential) | | | | | 5.x (`declare -gA`, `mapfile -O`) |
| jq | catalog load `i18n.sh:64`, free regions `disk.sh:531` | jq | 1.7.1-6+deb13u3 | - | 1.8.2-1 | 1.8.2-1 | 1.8.1-4ubuntu2 | any |
| coreutils | `/usr/bin/printf` positional args `i18n.sh:90` | coreutils | (essential) | | | | | any |

**As-is on Debian:** PARTIAL — helpers are neutral; the stage list calls Arch-only steps.

**Port steps:**
1. Keep `common.sh`, `i18n.sh`, the sentinel protocol and the EXIT trap unchanged.
2. In `main` (`ryoku-install:144-238`) replace, in order: `ryoku_ensure_keyring` → apt keyring check (§5); `ryoku_rank_mirrors` → Debian mirror selection (§4); `ryoku_hooks_quiet` + `ryoku_hooks_defer_mkinitcpio` → `ryoku_chroot_guard_on` (policy-rc.d, initramfs deferral, snapper apt-hook off) and the matching `_off` in `ryoku_hooks_restore` and in `ryoku_on_exit`; `ryoku_pacstrap` → `ryoku_bootstrap` (mmdebstrap, §9); drop the `cachyos` branch (`:197`) or replace (§12); `ryoku_offline_*` → apt equivalents (§10).
3. Add a `ryoku_chroot` wrapper (or keep `arch-chroot` from Debian's `arch-install-scripts`, which ships `/usr/bin/arch-chroot`, `/usr/bin/genfstab`, `/usr/bin/pacstrap`) and export `DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true` for every in-target apt/dpkg call.
4. Add a `RYOKU_SUITE` (trixie|forky|resolute) marker baked by the ISO build next to `variant`, read the same way as `ryoku-install:98`.

**Complexity:** Low — the orchestrator is a list of calls; the work is in the libs.

**Issues / risks:** `arch-chroot` mounts a fresh tmpfs on `/run`; Debian maintainer scripts
call `deb-systemd-invoke`/`invoke-rc.d`, and without `/usr/sbin/policy-rc.d` (exit 101)
they may try to start services inside the target.

---

### Preflight + Secure Boot gate (`installation/backend/lib/preflight.sh`)

**What it does:** Root, UEFI (`/sys/firmware/efi`), Secure Boot off via the last byte of the
`SecureBoot-8be4df61…` efivar (`preflight.sh:14-20,50-52`), whole disk ≥ 32 GiB
(`:54-68`), payload present (`:74-75`); alongside: GPT, ESP scan, ESP free space → shared
vs dedicated (`:84-137`), largest free region ≥ 22 GiB + swap (`:163-172`), BitLocker warn
(`:141-145`), Windows Fast Startup gate via `ntfsresize --info` (`:154-160`); carve:
filesystem/tool checks (`:175-195`).

**Arch couplings:**
- `preflight.sh:189` message "ntfsresize ships in ntfsprogs" (Arch package is `ntfs-3g`; Debian `ntfs-3g` ships `/usr/sbin/ntfsresize`).
- `preflight.sh:46-51` gate text: "Limine ships unsigned" — remains true on Debian unless signed (Q5).
- No package-manager calls.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| util-linux | `lsblk`,`blockdev`,`blkid` (`preflight.sh:61-77,104`) | util-linux | 2.41.5-0+deb13u1 | - | 2.42.4-1 | 2.42.4-1 | 2.41.3-3ubuntu2.3 | any |
| gptfdisk | `sgdisk -p` (`preflight.sh:109`) | gdisk | 1.0.10-2+b1 | - | 1.0.10-3 | 1.0.10-3 | 1.0.10-2build1 | any |
| ntfs-3g | `ntfsresize --info` (`disk.sh:892`) | ntfs-3g | 1:2022.10.3-5+deb13u2 | - | 1:2026.9.28-2 | 1:2026.9.28-2 | 1:2022.10.3-5ubuntu1.1 | any |
| e2fsprogs | `resize2fs` check (`preflight.sh:184`) | e2fsprogs | 1.47.2-3+b12 | - | 1.47.4-1+b2 | 1.47.4-1+b2 | 1.47.2-3ubuntu4 | any |
| btrfs-progs | carve tool check (`preflight.sh:185`) | btrfs-progs | 6.14-1 | 7.1-1~bpo13+1 | 7.1-1 | 7.1-1 | 6.17.1-1build1 | ≥6.1 (mkswapfile, `filesystem.sh:90`) |

**As-is on Debian:** YES (given the tools are on the live image).

**Port steps:**
1. `preflight.sh:189`: "ntfsprogs" → "ntfs-3g".
2. Keep the Secure Boot gate (or relax it per Q5).

**Complexity:** Low.

**Issues / risks:** A Debian live ISO boots with Secure Boot on through Debian's signed shim
+ GRUB (archiso does not), so on Debian the user can reach the TUI with SB on and only be
stopped at Review (`installation/tui/main.go:1958-1961`) or here; the hardware card already
shows the warning (`main.go:2938-2942`).

---

### Network gates: DNS, HTTP reach, clock-skew heal (`installation/backend/lib/network.sh:134-230`)

**What it does:** Before any disk write: resolve probe hosts with `getent` (`network.sh:170-176`),
write fallback resolvers 1.1.1.1/9.9.9.9/8.8.8.8 if broken (`:154-163`); `curl -fsSI` the
Arch `core.db` and `repo.ryoku.dev/stable/x86_64/ryoku.db` (`:192-206`); on failure read the
server `Date` header over `curl -k` and `date -s` if the clock is off by > 1 day (`:217-230`).

**Arch couplings:**
- `network.sh:172` probe hosts `archlinux.org geo.mirror.pkgbuild.com`.
- `network.sh:193-195` probe URLs `https://geo.mirror.pkgbuild.com/core/os/x86_64/core.db`, `https://repo.ryoku.dev/stable/x86_64/ryoku.db` (pacman repo layout).
- Log/die strings name "Arch geo mirror" (`network.sh:186,207`).

**Dependencies:** `curl`, `getent` (libc-bin), `date` — all in Debian/Ubuntu base (curl versions in the package list).

**As-is on Debian:** PARTIAL — logic is neutral, probe targets are Arch.

**Port steps:**
1. `network.sh:172` default → Debian: `deb.debian.org security.debian.org`; Ubuntu: `archive.ubuntu.com security.ubuntu.com`.
2. `network.sh:193-195` default → `https://deb.debian.org/debian/dists/${RYOKU_SUITE}/InRelease` (Ubuntu: `http://archive.ubuntu.com/ubuntu/dists/${RYOKU_SUITE}/InRelease`) and the Ryoku apt repo `…/dists/<suite>/InRelease`.
3. Keep the clock heal: apt rejects a Release file dated in the future ("Release file … is not valid yet"), the same failure class `docs/installation-hardware.md:386-405` describes for pacman.

**Complexity:** Low.

---

### Mirror ranking + pacman tuning (`installation/backend/lib/mirrors.sh`)

**What it does:** Four tiers: `reflector --protocol https --age 24 --sort rate --latest 10`
(`mirrors.sh:74-78`), the archlinux.org mirror-status JSON ranked by score (`:83-92`), the
ISO's shipped mirrorlist (`:96-103`), plus three emergency `Server =` lines appended always
(`:121-138`); sets `ParallelDownloads = 5`, `DisableDownloadTimeout`, `ILoveCandy` in
`/etc/pacman.conf` (`:174-187`). `ryoku_mirrors_fallback` drops a tier after a failed
pacstrap (`:143-166`).

**Arch couplings:** the whole file (`/etc/pacman.d/mirrorlist`, `/etc/pacman.conf`,
`reflector`, `https://archlinux.org/mirrors/status/json/`, `geo/fastly.mirror.pkgbuild.com`,
`mirrors.kernel.org/archlinux`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| reflector | tier 1 (`mirrors.sh:76`) | none (`netselect-apt` is the nearest tool) | netselect-apt 0.3.ds1-31 | - | 0.3.ds1-31 | 0.3.ds1-31 | - | n/a |

**As-is on Debian:** NO.

**Port steps:**
1. Replace the file with a Debian version: default mirror `http://deb.debian.org/debian` (Fastly-backed CDN, geo-routed) and `http://security.debian.org/debian-security`; Ubuntu: `http://archive.ubuntu.com/ubuntu` (or `http://<CC>.archive.ubuntu.com/ubuntu` with CC from the regdom/geolocation already computed in `network.sh:91-116`) and `http://security.ubuntu.com/ubuntu`.
2. Optional ranked tier: `netselect-apt -o /tmp/ns.sources <suite>` then probe the winner's `dists/<suite>/InRelease` before use, falling back to the CDN.
3. Replace `ryoku_pacman_tuning` with `/etc/apt/apt.conf.d/80ryoku-install`: `Acquire::Retries "3";` `Acquire::http::Timeout "30";` `APT::Install-Recommends "false";`. `ILoveCandy` has no apt equivalent; drop it. `DisableDownloadTimeout` has none either (apt retries instead).
4. `ryoku_mirrors_fallback` becomes: on a failed bootstrap, switch from a netselect mirror to the CDN once.

**Complexity:** Low.

**Issues / risks:** machine-state records that netselect ranking killed two builds
(ping-fastest mirrors serving 409 on InRelease) and that the build side therefore defaults to
the CDN; the probe-before-use step is required if a ranked tier is kept.

---

### Keyring init (`installation/backend/lib/pacstrap.sh:18-39`)

**What it does:** `systemctl start pacman-init.service`, then `pacman-key --init` +
`--populate archlinux` if empty, and dies if still empty (`pacstrap.sh:28-38`). Called at
preflight (`ryoku-install:158`) and again before pacstrap (`pacstrap.sh:98`).

**Arch couplings:** `pacman-key`, `pacman-init.service` (ISO unit
`installation/iso/airootfs/etc/systemd/system/pacman-init.service`), `archlinux-keyring`.

**As-is on Debian:** NO.

**Port steps:**
1. Replace with `ryoku_ensure_keyring`: `[[ -s /usr/share/keyrings/debian-archive-keyring.gpg ]]` (Ubuntu: `/usr/share/keyrings/ubuntu-archive-keyring.gpg`) and `[[ -s $RYOKU_REPO/release/packages/ryoku-keyring/ryoku.gpg ]]`; die before the wipe otherwise.
2. Optional signature self-test before the wipe: fetch `dists/<suite>/InRelease` and `gpgv --keyring <keyring> InRelease` (apt 3.0 in trixie verifies with `sqv`; `gpgv` remains available in `gpgv`).
3. The Ryoku key (`release/packages/ryoku-keyring/ryoku.gpg`) is a binary OpenPGP v4 EdDSA certificate (fingerprint `EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3`, `ryoku-trusted:1`), directly usable as an apt `Signed-By` keyring.

**Complexity:** Low.

---

### Partitioning, alongside, carve (`installation/backend/lib/disk.sh`, `lib/resize.sh`)

**What it does:** Whole: release holders, `sgdisk --zap-all`, `wipefs`, `parted` GPT with an
EF00 ESP + root (`disk.sh:220-273`). Alongside: GPT required, reclaim verified debris behind
the ERASE ack (`:442-494`), unique `RYOKUBOOT` label check (`:319-321`), free region from
`sfdisk --json` (`:527-562`), re-validated (`:568-574`), boot = EA00 XBOOTLDR (shared) or EF00
(dedicated) + root 8300 (`:363-368`), new-partition proof by partlabel and PKNAME
(`:384-421`). Carve: shrink fs then `sfdisk -N` in place, verify PARTUUID/type GUID and
`sgdisk -v` (`resize.sh:17-129`).

**Arch couplings:** none in code. Only `preflight.sh:189`'s message (above). Tools used:
`lsblk blkid blockdev wipefs sfdisk` (util-linux / fdisk), `sgdisk` (gdisk), `parted`,
`partprobe` (parted), `udevadm`, `dmsetup`, `cryptsetup`, `vgchange`/`pvs` (lvm2, optional,
`disk.sh:184`), `mdadm` (`:192-195`), `ntfsresize` (ntfs-3g), `dumpe2fs`/`resize2fs`/`e2fsck`
(e2fsprogs), `btrfs`, `mkswap`, `jq`, `findmnt`, `mountpoint`.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| util-linux (sfdisk) | `disk.sh:529`, `resize.sh:52,98` | fdisk (ships `/usr/sbin/sfdisk`) | 2.41.5-0+deb13u1 | - | 2.42.4-1 | 2.42.4-1 | 2.41.3-3ubuntu2.3 | `--json` (≥2.27) |
| parted | `disk.sh:253-259` | parted | 3.6-5 | - | 3.8-2 | 3.8-2 | 3.6-6 | any |
| gptfdisk | `disk.sh:247,365,491`, `resize.sh:77,107` | gdisk | 1.0.10-2+b1 | - | 1.0.10-3 | 1.0.10-3 | 1.0.10-2build1 | any |
| device-mapper | `disk.sh:61,69,178` | dmsetup | 2:1.02.205-2 | - | 2:1.02.205-2+b2 | 2:1.02.205-2+b2 | 2:1.02.205-2ubuntu3 | any |
| lvm2 | `disk.sh:184-189` | lvm2 | 2.03.31-2 | - | 2.03.31-2+b2 | 2.03.31-2+b2 | 2.03.31-2ubuntu3 | optional |
| mdadm | `disk.sh:192-195` | mdadm | 4.4-11 | - | 4.6-3 | 4.6-3 | 4.5-5ubuntu1.1 | optional |
| ntfs-3g | `resize.sh:135-140` | ntfs-3g | (above) | | | | | any |
| dosfstools | `fsck.fat` on shared ESP (`bootloader.sh:558-563`) | dosfstools | 4.2-1.2 | - | 4.2-1.2+b2 | 4.2-1.2+b2 | 4.2-1.2build1 | any |

**As-is on Debian:** YES.

**Port steps:** none in code; the live image must carry the packages above (ISO doc).

**Complexity:** Low.

**Issues / risks:** `mdadm` on Debian installs an initramfs hook and `mdadm.conf` handling;
on the live image only the binary is needed. On the target it is not in the Arch set
either.

---

### LUKS (`installation/backend/lib/luks.sh`)

**What it does:** `cryptsetup luksFormat --type luks2 --pbkdf argon2id --batch-mode` on
`ROOT_PART` with safety checks, `cryptsetup open … root` (`luks.sh:8-42`).

**Arch couplings:** none.

**Dependencies:** cryptsetup (trixie 2:2.7.5-2, forky/sid 2:2.8.8-1, resolute 2:2.8.4-1ubuntu4); min LUKS2 + argon2id (cryptsetup ≥ 2.0).

**As-is on Debian:** YES.

**Port steps:** none here; the boot-side unlock changes (§11 crypttab, §16 cmdline).

**Complexity:** Low.

---

### Filesystems, btrfs subvolumes, swapfile (`installation/backend/lib/filesystem.sh`)

**What it does:** `mkfs.vfat -F32` (label `BOOT`, or `RYOKUBOOT` alongside),
`mkfs.btrfs -f -L ryoku`, subvolumes `@ @log @pkg` always, `@home @snapshots @backups`
toggled, `@swap` when swap > 0 (`filesystem.sh:19-40`); mounts with
`compress=zstd:1,noatime` (`:17,42-59`), ESP at `/mnt/boot`, ≥ 64 MiB free check
(`:67-74`), `btrfs filesystem mkswapfile` + `swapon` (`:79-92`).

**Arch couplings:**
- `@pkg` is mounted at `/var/cache/pacman/pkg` (`filesystem.sh:9,48,55`).
- `/mnt/boot` is the FAT ESP/XBOOTLDR (`filesystem.sh:59`), the Arch layout where the kernel
  package writes `/boot/vmlinuz-linux` directly onto FAT.

**Dependencies:** btrfs-progs (≥ 6.1 for `mkswapfile` and `map-swapfile -r`,
`filesystem.sh:90`, `bootloader.sh:271-284`; trixie 6.14-1), dosfstools, util-linux.

**As-is on Debian:** PARTIAL.

**Port steps:**
1. `filesystem.sh:48,55`: `/mnt/var/cache/pacman/pkg` → `/mnt/var/cache/apt/archives` (keep the subvolume name `@pkg` or rename to `@apt`; the TUI hard-codes `@pkg` in labels at `installation/tui/main.go:1969,2705,3060,3216`).
2. `/boot` mount: depends on Q3. Option A (Arch layout) keeps `mount $ESP_DEV /mnt/boot`. Option B mounts the ESP at `/mnt/efi` (or `/mnt/boot/efi`) and leaves `/boot` on `@`.

**Complexity:** Low (code); the `/boot` decision is cross-cutting.

**Issues / risks:** with Option A, Debian kernel packages are unpacked by dpkg straight into
`/boot` on FAT (`vmlinuz-*`, `config-*`, `System.map-*`); dpkg aborts if `fchown`/`fchmod`
fail, and vfat returns `EPERM` for modes it cannot represent unless mounted with the
`quiet` option. Not verified here; a VM install must prove it before Option A is chosen.
Debian also cannot create its `/vmlinuz` convenience symlinks on FAT (it creates them in
`/` by default, not `/boot`, so that part is unaffected).

---

### Base bootstrap: pacstrap + genfstab (`installation/backend/lib/pacstrap.sh`)

**What it does:** Assembles `base.packages` + the `RYOKU_PROFILE` sections of
`hardware.packages` (`pacstrap.sh:49-63`) + `dev.packages` (`:66-69`) + `cachyos.packages`
on the cachyos variant (`:74-79`) + `broadcom-wl-dkms` when `lspci -d 14e4:` matches
(`:87-90`); runs `pacstrap [-C conf] -K /mnt --noconfirm …` (`:130`) with two retry regimes
(offline: `--needed`, surface the conflict/corrupt line `:140-162`; online: purge cache,
lower mirror tier, `--needed --overwrite '*'` `:169-186`); writes fstab with
`genfstab -U /mnt >> /mnt/etc/fstab` (`:102-103`).

**Arch couplings:**
- `pacstrap -K` (`pacstrap.sh:130,143,175`), `/mnt/var/cache/pacman/pkg/*.pkg.tar.*` (`:170`), pacman error strings parsed (`:150-152,183`).
- Arch package names in `system/packages/{base,hardware,dev,cachyos}.packages` (the full list is another port document; the bootstrap subset is below).
- `hardware.packages:12-19,21-51`: one concrete `vulkan-driver`/`lib32-vulkan-driver` provider per section to stop pacman's provider prompt; `lib32-*` need Arch `[multilib]`.
- `broadcom-wl-dkms` (`pacstrap.sh:87-90`); doc says `broadcom-wl` (`docs/installation-hardware.md:185-188`), code says `-dkms`.
- `genfstab` from `arch-install-scripts` (also packaged in Debian/Ubuntu).

**Dependencies (installer tools on the live image + bootstrap set on the target):**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| arch-install-scripts (pacstrap) | `pacstrap.sh:130` | mmdebstrap | 1.5.7-1+deb13u1 | - | 1.5.7-3 | 1.6.0-5 | 1.5.7-3 | `--skip=check/empty`, hooks (1.x) |
| — | alternative bootstrapper | debootstrap | 1.0.141 | - | 1.0.145 | 1.0.145 | 1.0.142ubuntu2 | — |
| arch-install-scripts (genfstab, arch-chroot) | `pacstrap.sh:103`, every `arch-chroot` | arch-install-scripts | 28-1 | 31-1~bpo13+1 | 31-1 | 31-1 | 31-1 | any |
| archlinux-keyring | signature checks | debian-archive-keyring / ubuntu-keyring | (base) | | | | | — |
| base | system | `--variant=minbase` + systemd-sysv, udev, dbus, kmod | systemd-sysv 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | — |
| linux | kernel | linux-image-amd64 / linux-image-generic | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | linux-generic 7.0.0-39.39 | see Q1 (`system/boot/limine/default.conf:24-29` targets 7.1's async initramfs race) |
| linux-headers | DKMS (`base.packages:14-21`) | linux-headers-amd64 / linux-headers-generic | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | 7.0.0-39.39 | matches kernel |
| linux-firmware | firmware | firmware-linux (= firmware-linux-free + firmware-linux-nonfree + amd64-microcode + intel-microcode), firmware-iwlwifi, firmware-realtek, firmware-atheros, firmware-brcm80211, firmware-mediatek, firmware-intel-graphics, firmware-sof-signed / Ubuntu linux-firmware | firmware-linux 20250410-2 (non-free-firmware) | 20260916-1~bpo13+1 | 20260916-1 | 20260916-1 | linux-firmware 20260319.git217ca6e4 | — |
| amd-ucode / intel-ucode | `hardware.packages:22,27` | amd64-microcode / intel-microcode | 3.20250311.1 / 3.20251111.1~deb13u1 (non-free-firmware) | - | 3.20251202.1 / 3.20260227.1 | same | 3.20251202.1ubuntu2 / 3.20260210.1ubuntu2 | — |
| dkms | DKMS | dkms | 3.2.2-1~deb13u1 | - | 3.2.2-1 | 3.2.2-1 | 3.2.2-1ubuntu1 | — |
| base-devel | DKMS + AUR builds | build-essential | (yes) | | | | | — |
| mkinitcpio | initramfs | dracut **or** initramfs-tools | dracut 106-6 / i-t 0.148.4 | - | 112-7 / 0.151 | 112-7 / 0.151 | 110-11ubuntu0.1 / 0.151ubuntu1 | Q2 |
| sudo | `chroot.sh:129-135` | sudo | 1.9.16p2-3+deb13u2 | - | 1.9.17p2-9 | 1.9.17p2-9 | 1.9.17p2-1ubuntu3.2 | — |
| btrfs-progs, cryptsetup, dosfstools, efibootmgr | boot chain (`base.packages:26-29`) | same names (+ cryptsetup-initramfs with initramfs-tools) | efibootmgr 18-2+b1; cryptsetup-initramfs 2:2.7.5-2 | - | 18-4.1+b1 | 18-4.1+b1 | 18-4ubuntu1 | — |
| limine | `bootloader.sh:471` | **not packaged** (build .deb, §16) | - | - | - | - | - | ≥12 (`system/boot/limine/limine.conf:27`) |
| limine-mkinitcpio-hook, limine-snapper-sync | `base.packages:33-34` | **not packaged** (build .deb, §16/§18) | - | - | - | - | - | 1.37.1 / 1.31.0 pinned in `release/packages/*/PKGBUILD` |
| plymouth | splash (`base.packages:35`) | plymouth | 24.004.60-5 | - | 26.134.222-1 | 26.134.222-1 | 24.004.60+git…ubuntu8.1 | — |
| snapper | `base.packages:36` | snapper | 0.10.6-1.2 | - | 0.10.6-1.3+b1 | 0.10.6-1.3+b1 | 0.10.6-1.3 | ≥0.10 (plugins dir used by limine-snapper-sync) |
| snap-pac | `base.packages:39` | built into Debian `snapper`: `/etc/apt/apt.conf.d/80snapper` | — | | | | | — |
| networkmanager, iwd, wpa_supplicant, wireless-regdb | `base.packages:42-50` | network-manager, iwd, wpasupplicant, wireless-regdb | 1.52.1-1 / 3.8-2 / 2:2.10-24 / 2026.05.30-1~deb13u1 | - | 1.58.1-1 / 3.12-1 | same | 1.54.3-2ubuntu3.1 / 3.10-1ubuntu1 | — |
| fish | `useradd -s /usr/bin/fish` (`chroot.sh:117`) | fish | 4.0.2-1 | - | 4.9.3-1 | 4.9.3-1 | 4.2.1-3.2 | — |
| pciutils | GPU detection (`base.packages:250-252`) | pciutils | 1:3.13.0-2 | - | 1:3.15.0-2 | same | 1:3.14.0-1build2 | — |
| broadcom-wl-dkms | `pacstrap.sh:87-90` | broadcom-sta-dkms (non-free) | 6.30.223.271-26 | 6.30.223.271-30~bpo13+1 | -32 | -32 | -29ubuntu1 (restricted) | — |
| vulkan-radeon / vulkan-intel / vulkan-swrast | `hardware.packages:23,28,50` | mesa-vulkan-drivers | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | — |
| lib32-* | `hardware.packages:24,29,45,51` | `<pkg>:i386` after `dpkg --add-architecture i386` | | | | | | — |
| intel-media-driver | `hardware.packages:33` | intel-media-va-driver-non-free (non-free) or intel-media-va-driver | 25.2.3+ds1-1 / 25.2.3+dfsg1-1 | - | 26.2.4 | 26.2.4 | 26.1.2 (multiverse/universe) | — |
| nvidia-utils / lib32-nvidia-utils | `hardware.packages:44-45` | see §15 | | | | | | — |
| locales, console-setup, keyboard-configuration, tzdata, util-linux-extra | §11 | same names | 2.41-12+deb13u4 / 1.242~deb13u1 / 1.242~deb13u1 / 2026c-0+deb13u1 / 2.41.5-0+deb13u1 | - | 2.43-7 / 1.249 / 1.249 / 2026e-1 / 2.42.4-1 | same | present | — |
| systemd (timesyncd) | `chroot.sh:99` | systemd-timesyncd (separate package) | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | — |

**As-is on Debian:** NO.

**Port steps:**
1. Split the transaction in two, mirroring the Arch staging the offline path already uses (`offline.sh:3-12,71-82`): (a) a bootstrap set via mmdebstrap, (b) the rest of `base.packages` (Debian names from the packages port) via in-target `apt-get install`.
2. Exact invocation, Debian trixie (forky: replace the suite and drop the backports line):
   ```bash
   inc=$(paste -sd, "$RYOKU_REPO/system/packages/debian/bootstrap.packages")
   mmdebstrap --mode=root --variant=minbase --skip=check/empty \
     --components="main contrib non-free non-free-firmware" \
     --aptopt='Acquire::Retries "3"' --aptopt='APT::Install-Recommends "false"' \
     --setup-hook='install -d "$1/usr/sbin"; printf "#!/bin/sh\nexit 101\n" >"$1/usr/sbin/policy-rc.d"; chmod 755 "$1/usr/sbin/policy-rc.d"' \
     --essential-hook='printf "%s\n" "locales locales/default_environment_locale select '"$RYOKU_LOCALE"'" "locales locales/locales_to_be_generated multiselect '"$RYOKU_LOCALE"' UTF-8" "keyboard-configuration keyboard-configuration/xkb-keymap select '"$xkbl"'" | chroot "$1" debconf-set-selections' \
     --include="$inc" \
     "$RYOKU_SUITE" /mnt \
     "deb http://deb.debian.org/debian $RYOKU_SUITE main contrib non-free non-free-firmware" \
     "deb http://deb.debian.org/debian $RYOKU_SUITE-updates main contrib non-free non-free-firmware" \
     "deb http://security.debian.org/debian-security $RYOKU_SUITE-security main contrib non-free non-free-firmware" \
     "deb http://deb.debian.org/debian $RYOKU_SUITE-backports main contrib non-free non-free-firmware" \
     "deb [signed-by=$RYOKU_REPO/release/packages/ryoku-keyring/ryoku.gpg] https://repo.ryoku.dev/debian $RYOKU_SUITE main"
   ```
   Ubuntu 26.04: `--components="main restricted universe multiverse"`,
   `--keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg` when the live host is Debian,
   sources `http://archive.ubuntu.com/ubuntu resolute{,-updates}` and
   `http://security.ubuntu.com/ubuntu resolute-security`, same components.
   `--skip=check/empty` is required because `/mnt` already holds the mounted subvolume
   directories (`home`, `var/log`, `var/cache/…`, `.snapshots`, `boot`, `swap`).
3. `bootstrap.packages` (Debian names; profile/initramfs choices resolved by the installer before the call):
   `systemd-sysv udev dbus kmod util-linux-extra locales console-setup keyboard-configuration kbd tzdata sudo ca-certificates curl gnupg jq pciutils`
   `linux-image-amd64 linux-headers-amd64 dkms build-essential`
   `firmware-linux firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 firmware-mediatek firmware-intel-graphics firmware-sof-signed`
   `dracut` (or `initramfs-tools cryptsetup-initramfs`) `cryptsetup btrfs-progs dosfstools efibootmgr plymouth snapper systemd-timesyncd`
   `network-manager iwd wpasupplicant wireless-regdb iw nftables bluez rtkit power-profiles-daemon fish`
   `limine limine-entry-tool limine-snapper-sync` (from the Ryoku apt repo).
   Ubuntu: `linux-generic linux-firmware amd64-microcode intel-microcode` instead of the Debian kernel/firmware names.
   Kernel from trixie-backports: `linux-image-amd64/trixie-backports linux-headers-amd64/trixie-backports` (apt `pkg/release` syntax in `--include`).
4. Profile sections → Debian: `[amd]` `amd64-microcode mesa-vulkan-drivers mesa-vulkan-drivers:i386`; `[intel]` `intel-microcode mesa-vulkan-drivers mesa-vulkan-drivers:i386 intel-media-va-driver-non-free`; `[nvidia]` see §15; `[vm]` `mesa-vulkan-drivers mesa-vulkan-drivers:i386` (lavapipe is inside `mesa-vulkan-drivers`). i386 needs `dpkg --add-architecture i386 && apt-get update` in the target first; mmdebstrap takes `--architectures=amd64,i386`.
5. Broadcom: `broadcom-wl-dkms` → `broadcom-sta-dkms` (Debian non-free, Ubuntu restricted).
6. Replace both retry regimes: online → `apt-get -o Acquire::Retries=5 install --fix-missing` once more after switching mirrors; offline → print the first `dpkg: error` / `E:` line from the log. dpkg overwrites files not owned by any package without error, so the `--overwrite '*'` recovery for orphaned files (`pacstrap.sh:166-175`) has no counterpart need; file conflicts between packages surface as `trying to overwrite '…', which is also in package …`.
7. fstab: keep `genfstab -U /mnt >> /mnt/etc/fstab` (Debian `arch-install-scripts` ships it, pure bash over `findmnt`), or write fstab explicitly. genfstab carries `compress=zstd:1,noatime,subvol=/@…` and the swapfile line.
8. After the bootstrap, remove `/etc/apt/sources.list` written by mmdebstrap and write deb822 `/etc/apt/sources.list.d/debian.sources` (Ubuntu: `ubuntu.sources`) plus `ryoku.sources` with `Signed-By: /usr/share/keyrings/ryoku-archive-keyring.gpg`.

**Complexity:** Medium.

**Issues / risks:**
- `debootstrap` takes one mirror and resolves `--include` naïvely; mmdebstrap uses apt's resolver and multiple sources.
- minbase lacks `init`; `systemd-sysv` must be named.
- Debian's `firmware-linux-nonfree` only pulls `firmware-amd-graphics` + `firmware-misc-nonfree`; Wi-Fi/BT/audio firmware are separate packages (listed above). Arch's single `linux-firmware` covers them all (`base.packages:224-230` relies on that).
- Arch's `broadcom-bt-firmware` (`.hcd` patchram blobs, `base.packages:230`) has no Debian/Ubuntu package.

---

### Offline install (`installation/backend/lib/offline.sh`)

**What it does:** Detects a baked `[offline]` pacman repo by `offline.db*` (`offline.sh:19-23`),
dies pre-wipe if offline but missing (`:31-41`), writes a `SigLevel = Never` pacstrap conf
(`:47-69`), binds the repo into `/mnt` and writes an `[offline]`-only conf for in-chroot
transactions (`:89-143`), installs the bundled AUR toolset (`:173-193`), strips everything
afterwards (`:149-165`).

**Arch couplings:** pacman repo db, `pacman --config`, `pacman.conf` stanzas,
`/var/lib/pacman/sync`, `Architecture = x86_64 x86_64_v3`.

**As-is on Debian:** NO.

**Port steps:**
1. The ISO bakes a flat apt repo (`Packages.xz` + `Release`, built with `apt-ftparchive` or `dpkg-scanpackages`; optionally signed with the Ryoku key) at `/usr/share/ryoku/offline/repo`. Detection: `[[ -s $RYOKU_OFFLINE_REPO/Packages.xz || -s $RYOKU_OFFLINE_REPO/Packages ]]` (same test in the TUI, §19).
2. Bootstrap: pass `"deb [trusted=yes] file://$RYOKU_OFFLINE_REPO ./"` as the only mmdebstrap source (mmdebstrap accepts file:// mirrors).
3. In-chroot transactions: bind the repo at the same path and run apt store-only: `-o Dir::Etc::sourcelist=sources.list.d/ryoku-offline.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0`.
4. Use `--no-remove` on every offline install so a closure gap cannot evict the desktop.
5. `ryoku_offline_chroot_off`: delete the list file, `rm -rf /var/lib/apt/lists/*_ryoku_offline_repo_*`, unbind.

**Complexity:** High — the ISO must bake a complete, self-consistent closure for the chosen suite including i386 libs, every NVIDIA branch the driver step can choose, and the Ryoku packages.

**Issues / risks:** a frozen apt closure ages like the pacman one; the first online
`apt full-upgrade` reconciles. Point releases of Debian stable keep it installable;
forky/sid closures churn faster.

---

### Configure in chroot (`installation/backend/lib/chroot.sh`)

**What it does:** locale (`chroot.sh:19-42`), keymap (`:44-67`), timezone (`:69-100`), hostname
(`:102-111`), user + root password (`:113-127`), sudo (`:129-135`), mkinitcpio HOOKS drop-in
(`:137-168`), crypttab (`:170-178`); owns the pacman hook masks (`:180-239`).

**Arch couplings:**
- `chroot.sh:22`: `sed "s|^#\(en_US\.UTF-8 \)|\1|" /etc/locale.gen` assumes Arch's `#xx_YY.UTF-8 UTF-8` (no space). Debian's file reads `# xx_YY.UTF-8 UTF-8`; the sed misses and the append fallback (`:29-37`) then adds the line, so it still works on Debian. Ubuntu's `locale-gen` does not use `/etc/locale.gen` as Debian does.
- `chroot.sh:38-40` writes `/etc/locale.conf`; Debian's `pam_env` and `update-locale` use `/etc/default/locale` (Debian's systemd is patched to read it).
- `chroot.sh:46-48` writes `/etc/vconsole.conf`; Debian's console keymap comes from `/etc/default/keyboard` via `console-setup` (`keyboard-setup.service`). systemd-vconsole-setup and dracut's `i18n` module still read `/etc/vconsole.conf`.
- `chroot.sh:98`: `hwclock` is in `util-linux-extra` on Debian/Ubuntu (not in minbase).
- `chroot.sh:107-110`: no `/etc/hosts` because pacman's `filesystem` package owns it.
- `chroot.sh:117`: `useradd -G wheel,…` — Debian has no `wheel` group; `useradd` aborts with "group 'wheel' does not exist", which `set -e` turns into an install failure.
- `chroot.sh:131-134`: `%wheel` sudoers drop-in.
- `chroot.sh:137-168`: `/etc/mkinitcpio.conf.d/ryoku.conf` with `HOOKS=(base udev plymouth keyboard autodetect ryoku-gpu-trim microcode modconf kms keymap consolefont block encrypt resume filesystems fsck)` (`system/boot/mkinitcpio/ryoku.conf:22`) and the `ryoku-gpu-trim` install hook (`system/boot/mkinitcpio/install/ryoku-gpu-trim`).
- `chroot.sh:180-239`: masks under `/etc/pacman.d/hooks` for `snap-pac`, `80-limine-efi-deploy`, `90-mkinitcpio-install`, `60-mkinitcpio-remove`.

**Dependencies:** locales, console-setup, keyboard-configuration, kbd, tzdata, util-linux-extra, sudo, systemd-timesyncd, dracut or initramfs-tools + cryptsetup-initramfs (versions in §9 table).

**As-is on Debian:** NO.

**Port steps:**
1. Locale: `sed -i "s/^# *\(${RYOKU_LOCALE//./\\.} \)/\1/" /mnt/etc/locale.gen`, append if absent, `chroot /mnt locale-gen`, `chroot /mnt update-locale LANG=$RYOKU_LOCALE` (writes `/etc/default/locale`). Ubuntu: `chroot /mnt locale-gen $RYOKU_LOCALE && chroot /mnt update-locale LANG=$RYOKU_LOCALE`. Keep writing `/etc/locale.conf` too (systemd reads it; harmless).
2. Keyboard: write `/etc/default/keyboard` (`XKBMODEL="pc105" XKBLAYOUT="$xkbl" XKBVARIANT="$xkbv" XKBOPTIONS="" BACKSPACE="guess"`), then `chroot /mnt env DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive keyboard-configuration console-setup`. Keep `/etc/vconsole.conf` (read by dracut `i18n` and systemd-vconsole-setup) and the `00-keyboard.conf` X11 snippet.
3. Timezone: keep `ln -sf`; add `chroot /mnt dpkg-reconfigure -f noninteractive tzdata` so debconf matches; include `util-linux-extra` for `hwclock`; `systemctl enable systemd-timesyncd` stays (package `systemd-timesyncd`).
4. Hostname: keep `/etc/hostname`; add `printf '127.0.1.1\t%s\n' "$RYOKU_HOSTNAME" >> /mnt/etc/hosts` (Debian convention; `libnss-myhostname` is not installed by default).
5. User: `useradd -m -G sudo,video,input -s /usr/bin/fish "$RYOKU_USERNAME"` (Debian `/etc/sudoers` already has `%sudo ALL=(ALL:ALL) ALL`); delete `ryoku_cfg_sudo` or keep it writing `%sudo`. Alternative: `groupadd -f wheel` first and keep the drop-in (Q10). Validate any drop-in with `visudo -cqf`.
6. initramfs (dracut path): write `/etc/dracut.conf.d/ryoku.conf`:
   `hostonly="yes"` (≙ `autodetect`), `early_microcode="yes"` (≙ `microcode`), `compress="zstd"`, `add_dracutmodules+=" plymouth btrfs resume "` (+ `" crypt "` when `RYOKU_ENCRYPT=1`), `add_drivers+=" vmd "` when `/sys/module/vmd` exists (≙ `bootloader.sh:301-312`). dracut includes modprobe.d (`modconf`), KMS drivers (`kms`, `drm` module), keymap/font from `/etc/vconsole.conf` (`keyboard keymap consolefont`, `i18n` module), fsck.
   ryoku-gpu-trim ≙ `omit_drivers+=" nouveau "` written only when nouveau is denylisted and an nvidia module exists (same conditions as `system/boot/mkinitcpio/install/ryoku-gpu-trim:21-27`), as a dracut module (`/usr/lib/dracut/modules.d/90ryoku-gpu-trim/module-setup.sh`) shipped by the Ryoku package.
7. initramfs (initramfs-tools path): `/etc/initramfs-tools/initramfs.conf` `MODULES=dep` (≙ autodetect), `COMPRESS=zstd`, `KEYMAP=y`; plymouth, btrfs-progs, cryptsetup-initramfs, intel/amd microcode packages ship their own hooks; `/etc/initramfs-tools/modules` gets `vmd` (VMD) and KMS modules; ryoku-gpu-trim ≙ `/usr/share/initramfs-tools/hooks/ryoku-gpu-trim` that deletes `nouveau.ko*` and `nvidia/*/gsp*` from `$DESTDIR` under the same conditions; resume via `/etc/initramfs-tools/conf.d/resume` (`RESUME=UUID=…`) plus `resume_offset=` on the cmdline.
8. crypttab: the existing line `root UUID=<luks> none luks` (`chroot.sh:176`) is valid Debian syntax. initramfs-tools needs `cryptsetup-initramfs` and a root fstab entry on `/dev/mapper/root`; dracut honours it in hostonly mode (or via `rd.luks.*`, §16).
9. Hook masks → `ryoku_chroot_guard_on/off`: (a) `/usr/sbin/policy-rc.d` exit 101 (from the bootstrap setup-hook), removed at the end; (b) snapper's apt hook is inert until `/etc/snapper/configs/root` exists, which §18 writes last — optionally `DISABLE_APT_SNAPSHOT=yes` in `/etc/default/snapper` for the window; (c) initramfs deferral: `sed -i 's/^update_initramfs=.*/update_initramfs=no/' /mnt/etc/initramfs-tools/update-initramfs.conf` (initramfs-tools) or `dpkg-divert --local --rename --add /etc/kernel/postinst.d/dracut` (dracut), undone before the single explicit build in §16; (d) whatever install-time trigger the Debian limine-entry-tool package registers must be skippable in the chroot (an env check such as `RYOKU_INSTALLER=1`).

**Complexity:** Medium.

**Issues / risks:**
- debconf: every package with questions must be preseeded or run under `DEBIAN_FRONTEND=noninteractive` (locales, keyboard-configuration, console-setup, tzdata, sddm's `shared/default-x-display-manager` when another DM is pulled in).
- Ubuntu's locale handling differs from Debian's (`/var/lib/locales/supported.d`); `update-locale` is the call common to both.

---

### CachyOS variant (`installation/backend/lib/cachyos.sh`)

**What it does:** On `RYOKU_VARIANT=cachyos`: adds `x86_64_v3`, enables `[multilib]`, adds
`[cachyos*]` repos above `[core]`, populates `cachyos` keyring (`cachyos.sh:12-111`);
pacstraps `linux-cachyos linux-cachyos-headers cachyos-keyring … scx-scheds
proton-cachyos-slr` (`system/packages/cachyos.packages`); boots `linux-cachyos`
(`bootloader.sh:163,358`).

**Arch couplings:** all of it.

**As-is on Debian:** NO (no CachyOS repositories for Debian/Ubuntu).

**Port steps:** decision (Q7). Mechanically, removing it means: delete `cachyos.sh`, the
`ryoku-install:197` call, `pacstrap.sh:74-79`, and the `kver=linux-cachyos` branches in
`bootloader.sh:163,358,648`.

**Complexity:** n/a.

---

### Desktop deploy (`installation/backend/lib/deploy.sh`)

**What it does:** Adds `[ryoku]` (`Server = https://repo.ryoku.dev/stable/$arch`,
`SigLevel = Required`) to the target `pacman.conf` (`deploy.sh:62-77`), copies the live
mirrorlist (`:81-90`), imports the Ryoku key with `pacman-key --populate ryoku` (`:98-115`),
installs `ryoku-keyring ryoku-desktop ryoku-desktop-$RYOKU_COMPOSITOR [asusctl]` online or
from `[offline]` with one `--overwrite '*'` retry (`:125-207`), warns on ISO-payload vs repo
version skew via `pacman -Si` (`:215-226`), seeds `/usr/lib/initcpio/install/ryoku-gpu-trim`
when absent (`:254-265`), seeds `~/.config/ryoku/desktop.json` kb layout with `jq`
(`:272-292`), runs `ryoku materialize` as the user (`:232-246`), seeds brand assets,
wallpapers, decor art, `~/.npmrc` (`:297-308`), copies the qylock bundle and runs
`ryoku/lockscreen/sddm/setup` + `install-qylock` in the chroot (`:313-327`), `chown -R`
(`:329-333`).

**Arch couplings:**
- pacman.conf stanza, `$arch`, mirrorlist (`deploy.sh:58-90`).
- `/usr/share/pacman/keyrings` + `pacman-key --populate` (`deploy.sh:99-114`).
- `pacman -Sy/-S/-Qq/-Si`, `--overwrite`, `--noprogressbar` (`deploy.sh:129,186-189,220`).
- Pacman version format in the skew check (`deploy.sh:222-224`, drops `-pkgrel`).
- `/usr/lib/initcpio/install/` path (`deploy.sh:256`).
- `ryoku/lockscreen/sddm/setup:109,112` inserts `pam_gnome_keyring` after `auth/session include system-login`; Debian's `/etc/pam.d/sddm` uses `@include common-auth`/`common-session`, so the `sed` anchors never match and the keyring is not unlocked at login.

**Dependencies:** the Ryoku apt repo (does not exist yet), `jq`, `ryoku` CLI (`/usr/bin/ryoku`), sddm, weston.

**As-is on Debian:** NO.

**Port steps:**
1. Repo: install `ryoku.gpg` to `/mnt/usr/share/keyrings/ryoku-archive-keyring.gpg` (binary key, usable as-is), write `/mnt/etc/apt/sources.list.d/ryoku.sources`:
   `Types: deb` / `URIs: https://repo.ryoku.dev/debian` / `Suites: <suite>` / `Components: main` / `Signed-By: /usr/share/keyrings/ryoku-archive-keyring.gpg`. `RYOKU_REPO_SERVER`/`RYOKU_REPO_SIGLEVEL` (tests) map to `URIs` and `[trusted=yes]`. No trustdb step; delete `ryoku_repo_keyring`'s populate/rm dance. The `ryoku-keyring` .deb then owns the same file (dpkg adopts an unowned file silently).
2. Mirrorlist copy: replace with the deb822 sources written in §9 step 8.
3. Packages: `chroot /mnt env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Progress-Fancy=0 install --no-install-recommends ryoku-keyring ryoku-desktop ryoku-desktop-$RYOKU_COMPOSITOR` after `apt-get update`; one retry. `--overwrite '*'` → not needed for unowned files; for inter-package conflicts `-o Dpkg::Options::=--force-overwrite` (avoid as default).
4. Skew check: `chroot /mnt apt-cache policy ryoku-desktop` → `Candidate:`; Debian versions need `~` for pre-releases (`0.75.5~beta.20-1`) so `0.75.5-beta.20` style stamps must be normalised `~`→`.` before comparing.
5. `ryoku_seed_initcpio_hook` → seed the dracut module or initramfs-tools hook path chosen in §11 step 6/7.
6. `sddm/setup` PAM: anchor on `@include common-auth` / `@include common-session` when `/etc/pam.d/common-auth` exists (Debian/Ubuntu), keep `system-login` otherwise (owner: lockscreen port).
7. `ryoku materialize`, seeds, qylock, chown: unchanged.

**Complexity:** Medium (code); blocked on the Ryoku apt repository (release port).

**Issues / risks:** Debian packages auto-enable their units at install (deb-systemd-helper)
and Recommends are installed by default; `ryoku-desktop`'s dependency tree on Debian must be
installed with `--no-install-recommends` or it pulls in a second display manager and other
desktops, which triggers the debconf DM prompt.

---

### Network persistence (`installation/backend/lib/network.sh:29-132`)

**What it does:** Pins NM's Wi-Fi backend (iwd, or wpa_supplicant if the live session switched)
in `/mnt/etc/NetworkManager/conf.d/wifi-backend.conf` (`network.sh:42-57`), copies live
`*.nmconnection` with 600 root:root (`:61-82`), resolves a Wi-Fi country (override →
geolocation → locale) and runs `arch-chroot /mnt ryoku-wifi-regdom set CC` (`:91-132`).

**Arch couplings:** `arch-chroot` only (Debian `arch-install-scripts` provides it). NM
paths are identical on Debian/Ubuntu.

**Dependencies:** network-manager, iwd, wpasupplicant (versions in §9).

**As-is on Debian:** YES (with `arch-install-scripts` or a chroot wrapper).

**Port steps:** none beyond the chroot wrapper. On Debian `iwd.service` is D-Bus activated by
NM; when the backend is iwd, `wpa_supplicant.service` may also be enabled by its package —
harmless, but `systemctl disable wpa_supplicant.service` matches the Arch state.

**Complexity:** Low.

---

### GPU drivers (`installation/backend/lib/drivers.sh` + `system/hardware/drivers/*.sh`)

**What it does:** Copies `amd.sh intel.sh nvidia.sh vulkan.sh` into the target and runs each
under `timeout 900 arch-chroot … bash` (`drivers.sh:18-29`), runs `ryoku-hw-backlight-fix`
(`:34-41`), applies `RYOKU_GPU_MODE` via `ryoku-gpu mode` as the user (`:73-101`). The NVIDIA
script picks: Turing+ (GSP, by lspci name regex `nvidia.sh:93-97`) → prebuilt
`nvidia-open`/`<kernel>-nvidia-open` else `nvidia-open-dkms` (`:179-192`); Kepler →
`nvidia-470xx-dkms` (`:193-196`); Maxwell/Pascal/Volta → `nvidia-580xx-dkms` (`:197-201`);
then `/etc/modprobe.d/nvidia.conf` (modeset, fbdev, PreserveVideoMemoryAllocations,
blacklist nouveau) and `/etc/mkinitcpio.conf.d/nvidia.conf` only when the module exists
(`:214-229`), enables `nvidia-{suspend,hibernate,resume}.service` (`:235-238`), writes
`/etc/pacman.d/hooks/ryoku-nvidia.hook` → `/usr/bin/ryoku-nvidia-guard` (`:251-276`).

**Arch couplings:**
- `pacman -Qq/-S/-Si`, `pacman-conf --repo-list` for multilib (`nvidia.sh:49-69,116-122,133,178`; same pattern `amd.sh:36-69`, `intel.sh:38-73`, `vulkan.sh:38-65`).
- `/usr/lib/modules/*/pkgbase` to enumerate kernels (`nvidia.sh:156-161`) — Debian kernels have no `pkgbase` file; the fallback is `linux` → headers name `linux-headers` (wrong on Debian).
- Arch package names: `mesa vulkan-radeon` (`amd.sh:69`), `intel-media-driver vpl-gpu-rt vulkan-intel sof-firmware` (`intel.sh:69,73`), `vulkan-icd-loader` (`vulkan.sh:65`), `nvidia-utils libva-nvidia-driver lib32-nvidia-utils nvidia-open nvidia-open-dkms nvidia-470xx-dkms nvidia-580xx-dkms`.
- mkinitcpio `MODULES=` drop-in (`nvidia.sh:223-225`); pacman hook (`:252-276`).
- `ryoku-hw-backlight-fix` writes `/etc/limine-entry-tool.d/ryoku-backlight.conf` and runs `limine-mkinitcpio`/`limine-update` (`system/hardware/display/ryoku-hw-backlight-fix:39,77-85`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| mesa | `amd.sh:69` | libgl1-mesa-dri, mesa-va-drivers | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | — |
| vulkan-radeon / vulkan-intel | `amd.sh:69`, `intel.sh:69` | mesa-vulkan-drivers | 25.0.7-2+deb13u1 | 26.1.6-1~bpo13+1 | 26.1.6-1 | 26.2.5-1 | 26.0.8-1ubuntu0.3 | — |
| intel-media-driver | `intel.sh:69` | intel-media-va-driver-non-free | 25.2.3+ds1-1 | - | 26.2.4+ds1-1 | 26.2.4+ds1-1 | 26.1.2+ds1-1 | — |
| vpl-gpu-rt | `intel.sh:69` | libmfx-gen1.2 (+ libvpl2) | 25.1.4-1 | - | 26.3.3-1 | 26.3.3-1 | 26.1.2-1 | — |
| sof-firmware | `intel.sh:73` | firmware-sof-signed | 2025.01-1 | - | 2026.09.1-1 | 2026.09.1-1 | 2025.12.2-1 | — |
| vulkan-icd-loader | `vulkan.sh:65` | libvulkan1 | 1.4.309.0-1 | - | 1.4.363.0-1 | 1.4.363.0-1 | 1.4.341.0-1 | — |
| nvidia-open (Turing+) | `nvidia.sh:118,186-191` | Debian: nvidia-open-kernel-dkms (contrib) + nvidia-driver; NVIDIA repo: nvidia-open; Ubuntu: nvidia-driver-595-open | 550.163.01-2 | 550.163.01-4~bpo13+1 | **-** (not in testing) | 550.163.01-4 | 595.99.02 (restricted); NVIDIA repo debian13: 590.44.01 … 615.71.09 | RTX 50xx (Blackwell) needs ≥570 open → not served by Debian 550 |
| nvidia-580xx-dkms (Maxwell/Pascal/Volta) | `nvidia.sh:197-201` | Debian nvidia-driver + nvidia-kernel-dkms (550 still supports them); Ubuntu nvidia-driver-580 | 550.163.01-2 (non-free) | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | 580.178.04 (restricted) | NVIDIA's debian13 repo starts at 590 (no 580 branch) |
| nvidia-470xx-dkms (Kepler) | `nvidia.sh:193-196` | nvidia-tesla-470-driver | - | - | - | 470.256.02-10 | - | Kepler only on sid; otherwise nouveau |
| nvidia-utils suspend units | `nvidia.sh:237` | nvidia-suspend-common | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | 550.163.01-5.1 | (in nvidia-utils-NNN) | — |
| libva-nvidia-driver | `nvidia.sh:152,180` | nvidia-vaapi-driver | 0.0.13-1 | 0.0.18-1~bpo13+1 | 0.0.18-1 | 0.0.18-1 | 0.0.14-1 | — |
| lib32-nvidia-utils | `nvidia.sh:181` | nvidia-driver-libs:i386 | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | same | — | — |
| (GSP firmware) | — | firmware-nvidia-gsp | 550.163.01-2 | 550.163.01-4~bpo13+1 | 550.163.01-5.1 | same | — | — |
| Ubuntu selector | — | ubuntu-drivers-common (`ubuntu-drivers install`) | - | - | - | - | 1:0.10.9 | — |

**As-is on Debian:** NO.

**Port steps:**
1. Make the four vendor scripts package-manager neutral: `pkg_installed` → `dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'`; `install_pkgs` → `apt-get -y --no-install-recommends install`; offline → the store-only apt options (§10) instead of `--config $RYOKU_PACMAN_CONF`.
2. Names: amd → `libgl1-mesa-dri mesa-vulkan-drivers mesa-va-drivers firmware-amd-graphics`; intel → `intel-media-va-driver-non-free libmfx-gen1.2 mesa-vulkan-drivers firmware-sof-signed firmware-intel-graphics`; vulkan → `libvulkan1`; i386 counterparts when `dpkg --print-foreign-architectures | grep -qx i386` (replaces the `pacman-conf --repo-list | grep multilib` test, `nvidia.sh:178`).
3. NVIDIA (Debian, Q4 option "NVIDIA repo"): install `cuda-keyring` from `https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/` (Ubuntu: `…/repos/ubuntu2604/x86_64/`), then Turing+ → `nvidia-open` (+ `nvidia-driver-pinning-<branch>` to hold a branch); Maxwell/Pascal/Volta → Debian `nvidia-driver nvidia-kernel-dkms` (550, non-free) because the NVIDIA debian13 repo has no 580 branch; Kepler → leave nouveau (or `nvidia-tesla-470-driver` on sid). i386: `nvidia-driver-libs:i386`.
   NVIDIA (Debian, option "Debian only"): Turing+ → `nvidia-open-kernel-dkms nvidia-driver firmware-nvidia-gsp` (trixie/sid contrib+non-free; missing in forky today; no RTX 50xx).
   NVIDIA (Ubuntu): `ubuntu-drivers install` (or `nvidia-driver-595-open` / `nvidia-driver-580`), which pulls prebuilt signed `linux-modules-nvidia-*` for the Ubuntu kernel.
4. Kernel enumeration: replace `/usr/lib/modules/*/pkgbase` with `ls /usr/lib/modules`; headers → `linux-headers-amd64` (or `linux-headers-$(kver)`); the prebuilt-vs-DKMS split (`nvidia.sh:107-122,183-192`) disappears on Debian (DKMS only; Ubuntu prebuilt via ubuntu-drivers).
5. Early KMS: `/etc/mkinitcpio.conf.d/nvidia.conf` → dracut `/etc/dracut.conf.d/nvidia.conf` `add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "` or initramfs-tools `/etc/initramfs-tools/modules` lines; `/etc/modprobe.d/nvidia.conf` stays. Debian's `nvidia-kernel-common`/`nvidia-driver` already ship a modprobe blacklist of nouveau — check for duplicate/conflicting options.
6. Guard hook: `/etc/pacman.d/hooks/ryoku-nvidia.hook` → `/etc/kernel/postinst.d/zz-ryoku-nvidia-guard` (runs after `dkms` and before/after `initramfs-tools`/`dracut` by name order) plus a dpkg file trigger in the Ryoku package on `/usr/lib/modules` (owner: hardware port; `ryoku-nvidia-guard` itself is pacman-aware).
7. `nvidia-{suspend,hibernate,resume}.service` names are identical in `nvidia-suspend-common`; Debian enables them on install via presets — the explicit enable stays harmless.

**Complexity:** High.

**Issues / risks:**
- Debian's packaged NVIDIA (550) is older than Arch's current branch and lacks Blackwell; the NVIDIA repo lacks the 580 legacy branch; the two sources conflict package-wise (pin one origin per machine).
- Secure Boot + DKMS: Debian's `dkms` signs modules with an auto-generated MOK (`/var/lib/dkms/mok.key`) that must be enrolled with `mokutil --import`; irrelevant while the Limine SB gate stays.
- `timeout 900 arch-chroot … bash` (`drivers.sh:25`): DKMS builds of NVIDIA on Debian run inside this window, as on Arch.

---

### Bootloader, initramfs build, services (`installation/backend/lib/bootloader.sh`)

**What it does:** Builds the cmdline (`root=UUID=… rootflags=subvol=@ rw`, or
`root=/dev/mapper/root … cryptdevice=UUID=<luks>:root`, `nvidia_drm.modeset=1` on amd-nvidia,
`resume=… resume_offset=` from `btrfs inspect-internal map-swapfile -r`) (`bootloader.sh:254-291`);
`plymouth-set-default-theme ryoku` (`:314-326`); writes `/etc/default/limine` from
`system/boot/limine/default.conf` with `@@CMDLINE@@` substituted (`:330-344`); VMD
`MODULES+=(vmd)` drop-in (`:301-312`). Whole/dedicated: if `limine-mkinitcpio` exists →
branding-only `/boot/limine.conf` + `limine-mkinitcpio` + `limine-update`, else a flat entry
`kernel_path: boot():/vmlinuz-linux`, `module_path: boot():/initramfs-linux.img` + `mkinitcpio -P`
(`:44-58,354-389`); `ryoku-windows-entry sync` (`:412-423`); dedicated: existing-ESP chainload
entry by PARTUUID (`:431-460`); copies `/usr/share/limine/BOOTX64.EFI` to
`EFI/limine/limine_x64.efi` and `EFI/BOOT/BOOTX64.EFI`, `efibootmgr --create … --label Ryoku
--loader '\EFI\limine\limine_x64.efi'` + `--bootnext`, best-effort (`:468-501`). Shared
alongside: `mkinitcpio -P`, stage-2 limine on the XBOOTLDR (`/boot/ryoku-limine.efi` +
`limine.conf` with `fslabel(RYOKUBOOT)` kernels and `guid()` chainload), `fsck.fat -a` + tar
backup of the shared ESP, stage-1 static hop in `/EFI/ryoku/`, `/etc/kernel/cmdline`, `/efi`
fstab line, `/etc/pacman.d/hooks/ryoku-limine-stage.hook`, NVRAM entry (`:518-743`). Enables
`sddm NetworkManager bluetooth rtkit-daemon power-profiles-daemon` (`:40-41`). Finalize after
AUR: promote/repoint the tool-managed tree, autoboot entry path by kernel name
(`:69-234`).

**Arch couplings:**
- Limine and limine-entry-tool are Arch/[ryoku] packages; neither is packaged in Debian or Ubuntu (madison: absent in all suites; sources.debian.org search: no `limine`).
- `limine-mkinitcpio`, `mkinitcpio -P` (`bootloader.sh:45-53,522`); `/etc/mkinitcpio.conf.d/ryoku-vmd.conf` (`:308-311`).
- Kernel file names `vmlinuz-linux`, `initramfs-linux.img`, `vmlinuz-linux-cachyos` (`:383-385,661-663`); `kver=linux` pkgbase names used for autoboot matching (`:163-175`) and `/etc/ryoku/default-kernel` (`:362-363`).
- `cryptdevice=UUID=…:root` is the mkinitcpio busybox `encrypt` hook syntax (`:259`), ignored by dracut and initramfs-tools.
- `chroot_has_pkg` = `pacman -Q` (`:245-248`).
- `/etc/pacman.d/hooks/ryoku-limine-stage.hook` (`:729-743`).
- `limine-entry-tool` upstream ships only `install/arch-linux/{limine-entry-tool,limine-mkinitcpio-hook,limine-dracut-support}` with libalpm hooks (`80-limine-efi-deploy.hook`, `90-limine-dracut-install.hook`, …) — no Debian integration exists upstream (gitlab.com/Zesko/limine-entry-tool tree, tags up to 1.40.0; Ryoku pins 1.37.1 in `release/packages/limine-mkinitcpio-hook/PKGBUILD:12`). It is built with GraalVM native-image + vendored Gradle 9.6.1 (`PKGBUILD:18-41,68-79`).
- Service names: identical on Debian/Ubuntu (`sddm.service`, `NetworkManager.service`, `bluetooth.service`, `rtkit-daemon.service`, `power-profiles-daemon.service`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| limine | loader binary `/usr/share/limine/BOOTX64.EFI` (`bootloader.sh:471,547,582,591`) | **build .deb** from github.com/limine-bootloader/limine (latest v12.9.3; Arch 12.9.3) | - | - | - | - | - | ≥12 (RRGGBB colours, `system/boot/limine/limine.conf:27-29`) |
| limine-mkinitcpio-hook (bundles limine-entry-tool) | menu regen, UKI, FIND_BOOTLOADERS (`bootloader.sh:45-49,118-120`) | **build .deb** + Debian kernel hooks | - | - | - | - | - | 1.37.1 pinned (1.37+ "adopts the placeholder", `bootloader.sh:62-64`) |
| mkinitcpio | `bootloader.sh:53,522` | dracut / initramfs-tools | (§9) | | | | | — |
| efibootmgr | `bootloader.sh:486,496-498,608` | efibootmgr | 18-2+b1 | - | 18-4.1+b1 | 18-4.1+b1 | 18-4ubuntu1 | — |
| plymouth | `bootloader.sh:322` | plymouth (ships `/usr/sbin/plymouth-set-default-theme`) | 24.004.60-5 | - | 26.134.222-1 | 26.134.222-1 | 24.004.60+git…ubuntu8.1 | — |
| (UKI stub) | `ENABLE_UKI=yes` (`system/boot/limine/default.conf:33`) | systemd-boot-efi (`linuxx64.efi.stub`), systemd-ukify | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | — |
| sddm, bluez, rtkit, power-profiles-daemon | services `bootloader.sh:41` | same names | 0.21.0+git20250502 / 5.82-1.1 / 0.13-5.1+b1 / 0.30-1.1 | - | newer | newer | present | — |

**As-is on Debian:** NO.

**Port steps:**
1. Build and publish a `limine` .deb (build deps by Debian name: `git nasm mtools llvm lld clang autoconf automake make`): `./bootstrap && ./configure --prefix=/usr --enable-all && make && make DESTDIR=… install` (recipe = Arch PKGBUILD: `makedepends=('git' 'nasm' 'mtools' 'llvm' 'lld' 'clang')`, `./configure --prefix=/usr --enable-all`). `--prefix=/usr` keeps `/usr/share/limine/BOOTX64.EFI`, the path `bootloader.sh` copies.
2. Build and publish `limine-entry-tool` and `limine-snapper-sync` .debs from the same GraalVM recipe (`release/packages/limine-mkinitcpio-hook/PKGBUILD:61-79`); package `install/arch-linux/limine-entry-tool/*` + `limine-dracut-support/usr/bin/limine-{dracut,update}` (dracut path) and replace every libalpm hook with Debian triggers: `/etc/kernel/postinst.d/zz-limine` and `/etc/kernel/postrm.d/zz-limine` (call `limine-update`), a dpkg file trigger on `/usr/share/limine/BOOTX64.EFI` for `limine-install`, and drop the `80-limine-efi-deploy.hook` equivalent during the install chroot (§11 step 9d). Kernel naming inside the tool keys off `/usr/lib/modules/*/pkgbase` on Arch; Debian needs a version-based naming patch (Debian kernels are `vmlinuz-<ver>-amd64`, no pkgbase file).
3. initramfs build (replaces `mkinitcpio -P`): `chroot /mnt dracut --regenerate-all --force` or `chroot /mnt update-initramfs -c -k all` (after undoing the deferral of §11 step 9c). With UKIs: `dracut --uefi` (needs `systemd-boot-efi`) or `ukify build` (initramfs-tools path) driven by the Debian limine-entry-tool port.
4. Flat fallback entry (`bootloader.sh:379-386,659-664`): resolve the installed kernel version at install time (`kv=$(ls /mnt/usr/lib/modules | sort -V | tail -1)`) and write `kernel_path: boot():/vmlinuz-$kv`, `module_path: boot():/initrd.img-$kv` (Debian names; dracut on Debian also writes `initrd.img-<ver>` from its kernel hook). This entry goes stale on the first kernel upgrade unless the Debian limine-entry-tool hook owns the menu.
5. Cmdline (`bootloader.sh:256-264`): dracut → `rd.luks.uuid=<luks> rd.luks.name=<luks>=root root=/dev/mapper/root rootflags=subvol=@ rw`; initramfs-tools → `root=/dev/mapper/root rootflags=subvol=@ rw` and rely on `/etc/crypttab` (§11 step 8). Drop `cryptdevice=`. `resume=`/`resume_offset=` work with both.
6. `/etc/ryoku/default-kernel` (`bootloader.sh:362-363`) and `ryoku_limine_autoboot` (`:161-186`): change the recorded value from Arch pkgbase (`linux`) to the Debian flavour/metapackage (`linux-image-amd64`, Ubuntu `linux-image-generic`) and match entries by version (cross-cutting with `ryoku doctor`'s `limineDefaultKernelPath`).
7. `ryoku_boot_vmd` → dracut `add_drivers+=" vmd "` or `/etc/initramfs-tools/modules` `vmd`.
8. `chroot_has_pkg` → `dpkg-query -W -f='${Status}' "$1" | grep -q 'install ok installed'`.
9. Two-stage alongside refresh hook (`bootloader.sh:729-743`): ship the refresh as a dpkg file trigger (`interest-noawait /usr/share/limine/BOOTX64.EFI`) in a Ryoku boot package, or write `/etc/apt/apt.conf.d/80ryoku-limine-stage` with `DPkg::Post-Invoke { "…same cp logic…"; };` when the installer must create it as a file.
10. efibootmgr inside a plain `chroot` needs `/sys/firmware/efi/efivars` bound (arch-chroot mounts efivarfs itself).
11. Services: same `systemctl enable` line. On Debian these units are already enabled by their packages' postinsts; keep the explicit enable and add explicit `systemctl disable` for units Ryoku intends off (e.g. `docker.service docker.socket`, `base.packages:180-186`).

**Complexity:** High.

**Issues / risks:**
- Limine reads only FAT/ISO9660, so kernels/initrds or UKIs must sit on a FAT volume: that drives Q3 (dpkg writing into FAT `/boot` vs a copy hook into an ESP at `/efi`).
- The whole tool-managed menu (UKI tree, Snapshots submenu, FIND_BOOTLOADERS) depends on porting limine-entry-tool's Arch-only integration; until then only the flat seed entry exists and goes stale on kernel upgrades.
- Debian/Ubuntu ship signed `shim-signed` (trixie 1.51~1+deb13u1+16.1-2~deb13u1) and `grub-efi-amd64-signed`; Limine is not signed by anyone (Q5).

---

### AUR step (`installation/backend/lib/aur.sh`)

**What it does:** Online only, best-effort: temporary `NOPASSWD` sudoers drop-in removed by a
RETURN trap (`aur.sh:55-60`), lend `resolv.conf` (`:64-67`), bootstrap `yay` (AUR
`yay-bin` + `makepkg -si`, fallback GitHub release tarball) (`:70-100`), install
`limine-mkinitcpio-hook limine-snapper-sync` first under 25-minute timeouts (`:21,106-113`),
then the rest of `system/packages/aur.packages` under 40 minutes (`:117-125`); sets Zen as
default browser when its `.desktop` exists (`:143-163`).

**Arch couplings:** AUR, `yay`, `makepkg`, `pacman -S base-devel git curl`.

AUR set (`system/packages/aur.packages:7,19,24,27,35,38,45,52,60,70`): `yay-bin`,
`phinger-cursors`, `catppuccin-cursors-mocha`, `apple_cursor`, `nvibrant-bin`, `localsend-bin`,
`voxtype-bin`, `ttf-fraunces-variable`, `zen-browser-bin`, `pam-fprint-grosshack`.

**Dependencies:**

| Arch (AUR) pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Upstream / version |
|---|---|---|---|---|---|---|---|---|
| yay-bin | helper (`aur.packages:7`) | none needed | - | - | - | - | - | — |
| phinger-cursors | cursor picker (`aur.packages:19`) | none (Ubuntu: phinger-cursor-theme 1.1-0ubuntu…) | - | - | - | - | 1.1 | github phisch/phinger-cursors v2.2 tarball |
| catppuccin-cursors-mocha | (`:24`) | none | - | - | - | - | - | github catppuccin/cursors v2.0.0 zips |
| apple_cursor | (`:27`) | none | - | - | - | - | - | github ful1e5/apple_cursor v2.0.1 `macOS*.tar.xz` |
| nvibrant-bin | NVIDIA vibrance (`:35`) | none | - | - | - | - | - | github Tremeschin/nvibrant v1.3.0 (manylinux wheel) |
| localsend-bin | file stash (`:38`) | none | - | - | - | - | - | github localsend/localsend v1.18.2 ships `LocalSend-1.18.2-linux-x86-64.deb` |
| voxtype-bin | dictation (`:45`) | none | - | - | - | - | - | github peteonrails/voxtype v1.1.1 ships `voxtype_1.1.1-1_amd64.deb` |
| ttf-fraunces-variable | brand font (`:52`) | none | - | - | - | - | - | github undercasetype/Fraunces 1.000 zip |
| zen-browser-bin | default browser (`:60`) | none | - | - | - | - | - | github zen-browser/desktop 1.23.3b `zen.linux-x86_64.tar.xz` |
| pam-fprint-grosshack | fingerprint PAM (`:70`) | none (fprintd/libpam-fprintd are packaged: 1.94.5) | - | - | - | - | - | gitlab mishakmak/pam-fprint-grosshack v1.94.1 (meson; build deps `meson ninja-build libpam0g-dev libsystemd-dev libglib2.0-dev`) |

**As-is on Debian:** NO.

**Port steps:**
1. Delete the yay bootstrap and the NOPASSWD window. Each item becomes a .deb in the Ryoku apt repo (built in CI, so the target needs no toolchain — `AGENTS.md` cardinal rule 7), installed in the desktop transaction (§13) or by an `apt-get install` best-effort step with the same 25/40-minute timeouts.
2. Vendor-supplied .debs (`localsend`, `voxtype`) can be mirrored into the Ryoku repo as-is.
3. `limine-mkinitcpio-hook`/`limine-snapper-sync` move to the bootstrap set (§9) from the Ryoku repo, as they already are in `base.packages:33-34`.
4. Keep `ryoku_default_browser` (`aur.sh:143-163`); add the Debian package's `.desktop` name if it differs.

**Complexity:** Medium (packaging work, not installer code).

---

### Snapshots (`installation/backend/lib/snapshots.sh`)

**What it does:** If `@snapshots`: hand-writes `/etc/snapper/configs/root` (NUMBER_LIMIT 10,
no timeline) (`snapshots.sh:35-64`), registers it in `/etc/conf.d/snapper` (`:67-73`),
`chmod 750 /.snapshots` (`:76-77`), enables `snapper-cleanup.timer` and, if present,
`limine-snapper-sync.service` (`:83-98`), prunes `/.snapshots` from `/etc/updatedb.conf`
(`:102-117`). Opt-out writes `/etc/ryoku/snapshots-disabled` (`:10-23`).

**Arch couplings:**
- `/etc/conf.d/snapper` (`snapshots.sh:67`): Debian's snapper reads `/etc/default/snapper` (Debian ships that file with `SNAPPER_CONFIGS=""`).
- snap-pac pre/post pacman snapshots → Debian `snapper` ships `/etc/apt/apt.conf.d/80snapper` (DPkg::Pre-/Post-Invoke `snapper create -d apt -c number -t pre/post`, gated on `/etc/snapper/configs/root` and `DISABLE_APT_SNAPSHOT`).
- `limine-snapper-sync` (Arch/[ryoku]; upstream ships a libalpm hook `10-limine-snapper-lock.hook` and a snapper plugin `/usr/lib/snapper/plugins/10-limine-snapper-sync`).

**Dependencies:** snapper 0.10.6 (trixie) / 0.10.6-1.3 (forky, sid, resolute); plocate (trixie 1.1.23-1) for `updatedb.conf`.

**As-is on Debian:** PARTIAL.

**Port steps:**
1. `snapshots.sh:67-73`: write `SNAPPER_CONFIGS="root"` into `/mnt/etc/default/snapper` (edit the existing line) instead of `/etc/conf.d/snapper`.
2. Keep the config file and the `snapper-cleanup.timer` enable (unit name identical in Debian's snapper).
3. `limine-snapper-sync`: from the Ryoku apt repo (§16 step 2); its libalpm lock hook becomes `DPkg::Pre-Invoke`/`Post-Invoke` lines in an apt.conf.d file shipped by the package.
4. Debian's snapper also ships `snapper-boot.timer` and `snapper-timeline.timer` (enabled by package presets on install): disable `snapper-timeline.timer` to match `TIMELINE_CREATE="no"` intent and avoid an idle timer.

**Complexity:** Medium (because of limine-snapper-sync).

---

### Installer TUI (`installation/tui/`)

**What it does:** Bubble Tea v2 wizard: keyboard → locale → timezone → network → hardware →
profile → gpu → compositor → target disk → strategy → layout → hostname → username → password →
encryption → review (`main.go:516-555`); live lists and actions in `system.go` (keymaps via
`localectl list-keymaps` `:66-89`, locales from `/usr/share/i18n/SUPPORTED` or `locale -a`
`:92-120`, `timedatectl list-timezones` `:153-166`, disks via `lsblk` minus the live medium
`:250-341`, Wi-Fi via `nmcli` with iwd↔wpa_supplicant fallback `:670-1050`, hardware via
`lscpu`/`systemd-detect-virt`/`lspci`/`/proc/meminfo`/efivars `:742-856`); sha512-crypt in pure
Go (`password.go:41-191`); hand-off + streaming + sentinels (`system.go:1055-1290`).
Gates: BIOS hard block (`main.go:1453`), Secure Boot blocks Review (`:1958-1961`), offline
image or network required (`:1962-1964`), disk ≥ 32 GiB (`:1908-1909`), typed ERASE for
destructive steps (`installEnv` `system.go:1130-1145`), live-medium exclusion
(`system.go:302-316`).

**Arch couplings:**
- `system.go:256-262` `liveDisk()`: only knows archiso (`/run/archiso`, `findmnt … /run/archiso/bootmnt`). On a Debian live-boot ISO the medium is `/run/live/medium`; Ubuntu casper mounts it at `/cdrom`. Without a match the function returns "" and the boot stick is offered as a target.
- `system.go:1307-1308` `netOnline()` probes `https://geo.mirror.pkgbuild.com/`.
- `system.go:1313,1322-1329` `offlineRepo()` tests a pacman db (`offline.db*`).
- `main.go:2398` welcome text "the live Arch image".
- `main.go:3212-3226` `stepLog` sample lines (`pacstrap -K`, `genfstab`, `arch-chroot`, `mkinitcpio -P`, `limine install`) — preview only.
- `main.go:884`, `:1960`, `:2940`, `:3285` name Limine (still true if Limine stays).
- `main.go:1969,2705,3060,3216` show the `@pkg` subvolume.
- Not Arch, but stale on every distro: step descriptions "Sets console.keyMap + xkb.layout", "Sets i18n.defaultLocale", "Sets time.timeZone", "Installs the -luks host variant" (`main.go:519-544`) are NixOS wording; `main.go:1521` tests a non-existent profile `intel-nvidia`.
- `system.go:67` `localectl list-keymaps` needs console keymap files: Debian's `kbd` ships no keymaps; they come from `console-data` (`/usr/share/keymaps/**/*.kmap.gz`). Whether systemd's `localectl` lists Debian's `.kmap.gz` names must be checked on a Debian live image; the TUI falls back to 8 built-in keymaps (`main.go:557-566`).
- Build: `go.mod:3-5` requires Go 1.26.4 / toolchain go1.26.5 (trixie `golang-go` is 1.24; trixie-bpo/forky 1.27; resolute 1.26).

**Dependencies (on the live image, called by the TUI):** systemd (`localectl`, `timedatectl`, `systemd-detect-virt`), console-data (keymaps), locales (`/usr/share/i18n/SUPPORTED`), kbd (`loadkeys`), util-linux (`lsblk`, `blockdev`, `findmnt`, `lscpu`), pciutils (`lspci`), network-manager (`nmcli`), iwd, wpasupplicant, iproute2 (`ip`), curl, xkb-data (`localectl list-x11-keymap-layouts`).

**As-is on Debian:** PARTIAL — logic and UI are distro-neutral Go; four call sites assume Arch.

**Port steps:**
1. `liveDisk()` (`system.go:256-282`): check, in order, `/run/live/medium` (Debian live-boot), `/cdrom` (casper), `/run/archiso/bootmnt`; resolve via the same `findmnt -nro SOURCE <mp>` → PKNAME / `lsblk -s` logic.
2. `netOnline()` (`system.go:1307-1308`): probe `https://deb.debian.org/` (Ubuntu `http://archive.ubuntu.com/`).
3. `offlineRepo()` (`system.go:1322-1329`): `filepath.Glob(offlineRepoPath+"/Packages*")` (the same test the backend uses, §10).
4. Strings: `main.go:2398` "live Arch image" → neutral; `stepLog` samples (`main.go:3212-3226`) → `mmdebstrap …`, `chroot /mnt …`, `dracut --regenerate-all` / `update-initramfs -u`; fix the NixOS step descriptions (`main.go:519-544`). Every changed source string needs the catalog sync (`ryoku-i18n`).
5. Live image must carry `console-data` for the keymap picker.
6. ISO build host needs Go ≥ 1.26.4 (trixie-backports `golang-go` 2:1.27~1~bpo13+1, or a toolchain download).

**Complexity:** Low.

**Issues / risks:** `RYOKU_PROFILE` names (`amd`, `intel`, `amd-nvidia`, `vm`) are fine as
hardware labels; the Debian meaning lives in the package sections.

---

### Live-session glue the TUI depends on (`installation/iso/airootfs/usr/local/bin/ryoku-installer-session`, `ryoku-install`)

**What it does:** Exports `RYOKU_REPO`, `RYOKU_BACKEND` (`ryoku-installer-session:19-20`),
launches `cage -m last -- foot … -e ryoku-tui` with the chosen XKB layout or falls back to the VT
TUI with a scaled console font (`:107-138,162-190`), relaunches cage after a keyboard pick
(`:209-227`).

**Arch couplings:** console fonts `solar24x32`, `latarcyrheb-sun32`, `iso01-12x22` are kbd
upstream font files present on Arch (`ryoku-installer-session:107-122`); Debian's `kbd` ships no
console fonts and `console-setup-linux` ships different names (e.g. `Lat15-Terminus32x16`), so
`setfont` fails (logged) and the VT keeps its default font. `/root/.zlogin` autostart is archiso
convention (ISO port).

**As-is on Debian:** PARTIAL.

**Port steps:** map the three candidates to Debian `console-setup-linux` fonts with the same cell
sizes (owner: ISO port); cage (trixie 0.2.0-2, forky 0.3.1-1) and foot (trixie 1.21.0-2) are
packaged.

**Complexity:** Low.

---

### Shell installer (`ryoku-shell-installer/`)

**What it does:** `install.sh` (run as the user via `curl … | bash`) refuses root, NixOS,
non-x86_64, non-systemd, picks family `arch` (pacman) or `debian` (apt-get)
(`install.sh:25-43`), warns on unknown `ID/ID_LIKE` (`:46-53`), announces "Debian detected:
the desktop is built from source" (`:54-56`), downloads the committed `ryoku-shell-install`
binary + sha256 from `raw.githubusercontent.com/ryoku-dev/ryoku-arch/<ref>`
(`:14-15,62-67`). The Go binary detects facts (`detect.go:203-…`), shows a plan with toggles
(`main.go:…`), and runs 16 steps (`engine.go:224-239`): legacy (Omarchy) retirement,
sysupgrade, tools, sparse payload clone (`github.com/ryoku-dev/ryoku-arch.git`,
`engine.go:29,541-604`), config backup with `restore.sh`, `[ryoku]` repo + keyring trust,
conflict removal, desktop packages, GPU drivers, build-from-source (Debian), SDDM/qylock/NM
wiring, `ryoku materialize` + seeds, AUR extras, fish, `ryoku doctor`, verify. Lifecycle:
resume state + `--uninstall` (`lifecycle.go`).

**Arch couplings:**
- `distro.go:37-45` Arch commands (`pacman -Syu --needed --noconfirm`, `-R`, `-Sy`, `-Qq`).
- `distro.go:47-110` an existing Debian profile: `apt-get -y install/remove/dist-upgrade`, `apt-get update`, `dpkg-query -W -f=${Status}` (`:52-56`), `fromSource: true` (`:51`), build deps `build-essential cmake ninja-build pkgconf golang qt6-*-dev hyprland-dev libhyprutils-dev` (`:57-62`), and a 42-entry rename map (`:63-109`). `detectDistro` maps any `ID_LIKE` containing `debian` (Ubuntu, Mint) to it (`distro.go:116-124`, tested `distro_test.go:16-18`).
- On fromSource, steps `legacy repo aur drivers` are dropped and `build` is added (`engine.go:222,240-250`): **Debian gets no GPU driver step and no extras**.
- `stepPackages` on Debian installs `localAll(base.packages minus bootChainSkip) + build` with plain `apt-get -y install` (`engine.go:871-874`, `distro.go:52`): no `DEBIAN_FRONTEND=noninteractive`, no `--no-install-recommends`.
- Rename map gaps: these names reach `apt-get install` unchanged and do not exist as Debian binaries (checked against madison, binary architectures only): `docker` (→ `docker.io`), `mesa` (→ `libgl1-mesa-dri mesa-vulkan-drivers`), `qt6-declarative`, `qt6-5compat`, `qt6-svg`, `qt6-multimedia` (source names; binaries are `qml6-module-*`/`libqt6*6`), `qt5-wayland` (→ `qtwayland5`), `libnotify` (→ `libnotify-bin`), `libqalculate` (→ `qalc`), `tesseract` (→ `tesseract-ocr`), `zbar` (→ `zbar-tools`), `virglrenderer` (→ `libvirglrenderer1`), `nautilus-python` (→ `python3-nautilus`), `blesh`, `broadcom-bt-firmware`, `game-devices-udev`, `wl-clip-persist`, `zsh-history-substring-search`, `ttf-maple-mono-nf`, `gpu-screen-recorder` (source only in testing/sid). Not in trixie main (backports/forky only): `quickshell`, `hypridle`, `hyprpicker`, `gamescope` (contrib), `xpadneo-dkms`, `openrgb`, `hyprland-dev`, `libhyprutils-dev`; `firefox` is sid-only (Ubuntu: snap transitional). One unknown name fails the whole `apt-get install`.
- `detect.go:455-470` microcode names `amd-ucode`/`intel-ucode` are not in the rename map → `apt-get install amd-ucode` fails (Debian `amd64-microcode`/`intel-microcode`, non-free-firmware).
- `detect.go:268-294`: rival shells, conflict blockers, oh-my-zsh frameworks, installed desktops are only detected when `pacman` exists, although `installed()` already dispatches to `dpkg-query` (`distro.go:153-166`) and the desktop package names (`gnome-shell plasma-desktop cinnamon xfce4-session`, `de.go:22-27`) are identical on Debian.
- `engine.go:747` `pacman -Rdd` (only reachable when the pacman-gated list is non-empty).
- `engine.go:945-957` `stepBuild` runs `ryoku/shell/deploy.sh`, which calls `pacman -Q qt6-base` (`ryoku/shell/deploy.sh:474`), prints `sudo pacman -S …` fixes (`:120,229`), installs `/usr/lib/initcpio/install/ryoku-gpu-trim` and runs `ryoku-boot-apply` (`:429-438`).
- `engine.go:1010-1025` initramfs probe knows `limine-mkinitcpio`, `mkinitcpio`, `dracut-rebuild`, `dracut` — not `update-initramfs` (Arch-only path today).
- `engine.go:1032-1138` `stepSession`: runs `sddm/setup` (PAM anchor `system-login`, see §13), appends GNOME keyring PAM lines (`:1096-1104`) with the Arch layout in mind, writes the iwd backend pin (`:1126-1132`).
- `engine.go:1446` message "install with: sudo pacman -S go"; `engine.go:1431-1437` matugen "not packaged here" (forky packages… not checked by this doc; packages port).
- `detect.go:227` reachability probe `https://repo.ryoku.dev/stable/x86_64/ryoku.db`.
- `lifecycle.go:130-160` uninstall removes packages and the repo stanza only on Arch; on Debian nothing built into `~/.local`, `/usr/share/ryoku/qylock`, `/usr/share/sddm/themes/ryoku` is removed.
- Secure Boot NVIDIA policy text "Arch kernels reject unsigned DKMS modules" (`README.md:77`, `main.go:103-107`): Debian/Ubuntu DKMS signs with a MOK that can be enrolled.
- `main.go:821-825` Manjaro gate (Arch-only concept).

**Dependencies:** the Ryoku apt repo (for a packaged Debian path); otherwise the fromSource build deps listed in `distro.go:57-62`: `hyprland-dev` (trixie-bpo 0.55.2+ds-1~bpo13+1, forky/sid 0.56.2+ds-3, resolute 0.53.3+ds-4), `libhyprutils-dev` (trixie-bpo 0.14.2-1~bpo13+1, forky/sid 0.14.2-1, resolute 0.11.0-3), `golang` (trixie 1.24 < Go 1.26.4 required by `ryoku-shell-installer/go.mod:3`, other Ryoku Go modules: Go port).

**As-is on Debian:** PARTIAL — a Debian code path exists and is unit-tested
(`distro_test.go`), but on a real Debian box the package step fails on unknown names, GPU drivers
are never installed, and the desktop is compiled locally.

**Port steps:**
1. Replace `fromSource` on Debian with a packaged path once the Ryoku apt repo exists: `stepRepo` writes `ryoku-archive-keyring.gpg` + `ryoku.sources` and `apt-get update`; `stepPackages` installs `ryoku-keyring ryoku-desktop ryoku-desktop-<wm>` exactly like the ISO (§13); remove `stepBuild` and the `build` list for Debian.
2. Run every apt call as `sudo -n env DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends …` (`distro.go:52-55`).
3. Rename map: replace the hand map with the Debian package list owned by the packages port (`system/packages/debian/*.packages`), or at minimum add the entries listed under couplings plus `amd-ucode→amd64-microcode`, `intel-ucode→intel-microcode`.
4. Remove `drivers` from `pacmanOnly` (`engine.go:222`) and run the Debian driver scripts (§15); add `update-initramfs -u -k all` to the probe list (`engine.go:1013-1025`).
5. Drop the `f.pacman` gate around rival/blocker/desktop detection (`detect.go:268-294`); keep pacman-only extras (`illogical-impulse-*` scan) behind it; map `conflictBlockerPkgs` to Debian names (`pulseaudio`, `pulseaudio-module-bluetooth`).
6. `sddm/setup` PAM anchor fix (§13 step 6) covers `stepSession`.
7. Uninstall on Debian: `apt-get remove ryoku-desktop ryoku-keyring …`, delete `ryoku.sources` and the keyring.
8. Strings: `engine.go:1446`, Secure Boot texts, `install.sh:55`.
9. Repo URL (`engine.go:29`, `install.sh:15`) names `ryoku-arch`; a Debian port either keeps one repo or adds a per-family ref.

**Complexity:** High (Debian path is a redesign around an apt repo; the Arch path is untouched).

**Issues / risks:**
- The current Debian path contradicts cardinal rule 7 ("the installed target has no build toolchain assumptions", `AGENTS.md`) and `docs/development.md:121-125` ("never assume `go` at install time").
- `README.md:5-9` claims Debian hosts get apt dependencies and local builds with the Hyprland plugins skipped; the code matches that claim but the dependency install fails as listed above.
- Ubuntu and Mint are routed to the Debian profile (`distro.go:118-121`); Ubuntu component names (`universe`/`multiverse`) and snaps (firefox) differ.

---

### Install tests (`installation/tests/*`, `tests/install-*.sh`, `tests/installer-session-scale.sh`)

**What it does / Arch couplings / rewrite:**

| Test | What it checks | Arch couplings (cite) | As-is on Debian | Debian rewrite |
|---|---|---|---|---|
| `installation/tests/container-install.sh` | build `[ryoku]` from checkout, install `ryoku-desktop` in a container, materialize, assert tree, release marker, track probe, boot-guard, logind lid drop-in ownership, alpm power hooks, niri variant coexistence | `archlinux:latest`/CachyOS base (`:9,28-33`), `pacman -Sy/-Syu/-S/-Qq/-Ql/-Qo` (`:46-52,108-116,286-293,313,341-346`), `DisableSandboxNetwork` (`:55-59`), `pacman-key` (`:72-75`), `bsdtar .PKGINFO` (`:91-95`), `/usr/lib/qt6/qml/Ryoku` (`:184-185` in file numbering), `/usr/share/libalpm/hooks/9{4,5}-ryoku-power-cutover*.hook` (`:310-321`) | NO | `debian:<suite>`/`ubuntu:resolute` container; build .debs; local `[trusted=yes]` apt repo; `apt-get install ryoku-desktop`; ownership via `dpkg -S`; file lists via `dpkg -L`; Qt path `/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku`; power-cutover hooks become apt/dpkg hook paths; metadata via `dpkg-deb -f` |
| `installation/tests/build-ryoku-repo.sh` | build signed throwaway pacman repo | `makepkg` as `builder`, `release/repo/build-repo.sh` (`:21-50`) | NO | build .debs + `apt-ftparchive`/`reprepro` with a throwaway key |
| `installation/tests/install-vm.py` | boot ISO in QEMU, run backend over serial, assert installed tree | archiso serial autologin (`:93-101`), OVMF lookup already includes Debian paths `/usr/share/OVMF/OVMF_CODE_4M.fd` (`:22-36`), hint "pacman -S edk2-ovmf" (`:127`), mirror probe URL `geo.mirror.pkgbuild.com` (`:149-151`), `RYOKU_REPO_SERVER='…/$arch'` (`:149`), asserts `/etc/vconsole.conf` KEYMAP (`:245`), subvol layout `/dev/vda2` `subvol=@`, ESP at `/boot` (`:228-231`) | PARTIAL | live-boot serial login, Debian probe URL, apt repo server, KEYMAP assertion → `/etc/default/keyboard XKBLAYOUT`; deps `qemu-system-x86 ovmf python3-pexpect` |
| `installation/tests/install-dualboot-vm.py` | Windows golden + alongside + byte-identity + both boot legs | needs the Arch ISO; host tools `qemu`, `edk2-ovmf`, `python-pexpect`, `tesseract`, `ntfs-3g`, `qemu-nbd` (`README.md:36-48`) | PARTIAL | host package names (`qemu-system-x86 ovmf python3-pexpect tesseract-ocr ntfs-3g qemu-utils`); ISO serial expectations |
| `installation/tests/iso-preflight.sh` | pre-mkarchiso gate: syntax, shellcheck, package lists, offline/hook suites, boot-menu suites, contract suites, TUI build, delivery, woke | `packages_gate` accepts pacman name grammar (`:106-123`), suite names `install-hooks offline-repo-integrity limine-*` (`:145-152`) | PARTIAL | package-list grammar for Debian names (`:i386` suffix); swap pacman-hook suites for Debian hook suites |
| `installation/tests/iso-stage-check.sh` | `build.sh --stage-only` twice, diff | depends on `iso/build.sh` (archiso) (`:22`) | NO | re-target to the Debian ISO builder's stage mode |
| `tests/install-dryrun-matrix.sh` | sentinels/narration across strategies, encryption, swap, ESP mode, variant, GPU mode | expects `limine_x64.efi` path (`:92`), `luksFormat` string (`:63`); variant matrix includes cachyos | PARTIAL | drop/replace cachyos rows; keep sentinel/narration checks |
| `tests/install-hooks.sh` | pacman hook masking regressions | `/etc/pacman.d/hooks`, `snap-pac`, `90-mkinitcpio-install.hook`, `limine-efi-deploy`, pacstrap stubs (18 refs) | NO | rewrite for policy-rc.d / initramfs deferral / snapper apt-hook guard |
| `tests/install-mirrors.sh` | four-tier mirror logic | reflector, archlinux.org JSON, pkgbuild.com, pacstrap retries (`34` pacstrap refs) | NO | rewrite for CDN/netselect + InRelease probe |
| `tests/install-offline.sh` | offline path end-to-end dry run | pacman/pacstrap/arch-chroot stubs, `[offline]` conf | NO | rewrite for apt store-only options |
| `tests/install-noninteractive.sh` | nothing waits for input | pacstrap/pacman/mkinitcpio/limine-mkinitcpio stubs | NO | assert `DEBIAN_FRONTEND=noninteractive`, preseeds, `</dev/null` on apt/dpkg |
| `tests/install-dns.sh` | DNS gate | one `pacstrap` mention in narration | YES (after probe-host change) | update default hosts |
| `tests/install-clock-skew.sh` | clock heal | one `pacman` mention | YES | none |
| `tests/install-chroot-safety.sh` | no bare `systemctl --user` in chroot phases | none | YES | none |
| `tests/install-disk-teardown.sh`, `install-largest-free.sh`, `install-partition-whole.sh`, `install-preflight.sh`, `install-windows-faststartup.sh` | disk/preflight fixtures | none | YES | none |
| `tests/install-partition-alongside.sh`, `install-resize.sh`, `install-swapfile.sh` | real loop-device tests (root) | `install-partition-alongside.sh` mentions limine-entry-tool/limine-update (11 limine refs) in assertions about boot layout | YES / PARTIAL | host tools by Debian name; alongside limine assertions follow §16 |
| `tests/install-chainload-vm.sh` | QEMU+OVMF two-stage Limine chain | host `/usr/share/limine/BOOTX64.EFI` (`:46-47`), OVMF dirs incl. `/usr/share/OVMF` (`:49-53`) | PARTIAL | needs the Limine .deb on the test host; OVMF already found |
| `tests/installer-session-scale.sh` | console/kiosk font sizing helpers | kbd font names (via the session script) | PARTIAL | follows the font-name change |

**As-is on Debian:** PARTIAL (≈ 12 fixture tests are neutral; container/VM/hook/mirror/offline tests are pacman-specific).

**Complexity:** Medium.

---

### Installer docs (`docs/installation-hardware.md`, `docs/development.md`)

**What it does:** Per-hardware-class symptom/cause/installer-action/user-action notes, and the
installer verification workflow.

**Arch couplings:**
- `installation-hardware.md:41-45` VMD via mkinitcpio `MODULES+=(vmd)` / "UKI and `mkinitcpio -P` paths".
- `:54-71` Secure Boot vs unsigned Limine.
- `:185-188` "adds `broadcom-wl`" (code: `broadcom-wl-dkms`, `pacstrap.sh:87-90`).
- `:271` "Arch's `linux-firmware` default set".
- `:307-308` `xone-dkms` from the AUR.
- `:386-405` "pacman signatures".
- `:433-436` archiso squashfs discovery under Ventoy (Debian live-boot has its own medium discovery).
- `development.md:26-49` dry-run matrix, `iso-preflight.sh` "before mkarchiso"; `:98-100` "pacstrapped"; `:121-130` `[ryoku]` pacman packages, AUR post-install.

**As-is on Debian:** NO (content is Arch-specific in the places listed).

**Port steps:** rewrite the listed paragraphs to the Debian mechanisms chosen in §9-§18.

**Complexity:** Low.

---

## Issues across the installer (deliverable 6)

1. **Limine is not packaged** in Debian (trixie, bpo, forky, sid) or Ubuntu resolute; Ryoku must
   build `limine`, `limine-entry-tool` (GraalVM native-image, vendored Gradle) and
   `limine-snapper-sync` as .debs and write Debian kernel/dpkg integration for a tool whose
   upstream only ships libalpm hooks.
2. **Kernel naming and `/boot` on FAT.** Arch writes unversioned `/boot/vmlinuz-linux` +
   `initramfs-linux.img` onto the FAT ESP; Debian writes versioned files via dpkg and has no
   `pkgbase`; everything that names kernels (`bootloader.sh`, `/etc/ryoku/default-kernel`,
   `nvidia.sh:156-161`, doctor) changes, and the FAT `/boot` layout needs VM proof (Q3).
3. **initramfs generator** (Q2): mkinitcpio HOOKS have direct dracut equivalents; initramfs-tools
   needs hooks + crypttab-driven unlock and has no UKI builder. Debian default is
   initramfs-tools; Ubuntu 25.10 announced dracut as its default (both packages exist in
   resolute — dracut 110-11ubuntu0.1, initramfs-tools 0.151ubuntu1; which one resolute's
   kernel/minimal seed pulls was not confirmed here).
4. **LUKS cmdline**: `cryptdevice=` (`bootloader.sh:259`) is mkinitcpio-only.
5. **debconf**: no Arch counterpart; every installer apt/dpkg call needs
   `DEBIAN_FRONTEND=noninteractive` and preseeds (locales, keyboard-configuration,
   console-setup, tzdata, display-manager choice).
6. **Services auto-enable/auto-start** on Debian package install; `policy-rc.d` in the chroot and
   explicit `disable` for units Ryoku keeps off.
7. **Recommends** are installed by default on Debian; Arch has no equivalent. Installer apt
   calls need `--no-install-recommends` (or `APT::Install-Recommends "false"`).
8. **Firmware split**: Debian `firmware-linux` ≠ Arch `linux-firmware`; Wi-Fi/BT/audio firmware
   are separate non-free-firmware packages; `broadcom-bt-firmware` has no package.
   Ubuntu has a single `linux-firmware`.
9. **Components**: Debian needs `contrib non-free non-free-firmware` (NVIDIA, intel-media
   non-free, broadcom-sta, microcode, firmware, gamescope contrib); Ubuntu needs
   `restricted universe multiverse`.
10. **Kernel choice** (Q1): trixie 6.12.107, trixie-backports 7.2.6, forky/sid 7.2.11, Ubuntu
    resolute 7.0.0-39; `system/boot/limine/default.conf:24-31` carries a 7.1-specific
    `initramfs_async=0` workaround (harmless on 6.12).
11. **NVIDIA branches** (Q4): Debian 550 (no RTX 50xx; open module absent in forky today),
    NVIDIA repo 590–615 (no 580 legacy), Ubuntu 580/595 (prebuilt signed modules).
12. **"Install needs no build toolchain"** (`AGENTS.md` rule 7): broken by the AUR step on Arch
    already being online-only, and on Debian by (a) the shell installer's fromSource path,
    (b) any AUR-equivalent built on the target. DKMS (`dkms` + `build-essential` + headers)
    stays on target exactly as Arch's `base-devel`+`dkms`+`linux-headers` (`base.packages:7,20-21`).
13. **No `wheel` group** on Debian: `useradd -G wheel` fails the install (`chroot.sh:117`).
14. **Live-medium detection**: archiso paths in the TUI (`system.go:256-262`); Debian live-boot
    `/run/live/medium`, Ubuntu casper `/cdrom`.
15. **Offline ISO**: a baked apt closure for one suite, i386 included, plus every NVIDIA branch
    the driver step may pick.
16. **Version strings**: Ryoku's `-beta.N` versions need `~beta.N` in Debian versions for correct
    ordering; the installer's skew check and doctor/updater compare versions.
17. **Secure Boot**: the Debian live ISO can boot under SB (signed shim), so the SB block moves
    from "ISO will not boot" to "TUI refuses at Review".

## Questions for the human

1. **Base suite.** Debian trixie (+bpo) / forky / Ubuntu 26.04. Installer consequences: kernel
   6.12 vs 7.2-bpo vs 7.0; Hyprland stack pieces in the bootstrap only from bpo/forky/resolute;
   NVIDIA source options differ (Q4); Ubuntu needs snap-free Firefox handling and different
   components/mirrors; offline closure churn is lowest on stable.
2. **initramfs generator.** dracut: direct HOOKS mapping, UKI via `dracut --uefi`, upstream
   limine-entry-tool already has a dracut flavour; non-default on Debian. initramfs-tools:
   Debian default, crypttab-driven unlock, ryoku-gpu-trim and VMD as hooks, UKIs need `ukify`.
3. **/boot layout.** (A) keep `/boot` = FAT ESP like Arch: same fstab/limine paths, doctor
   reconcilers unchanged; dpkg writes kernels onto FAT (EPERM risk on chmod/chown; needs
   `quiet` mount option or proof). (B) ESP at `/efi` with `/boot` on btrfs `@`: dpkg-safe and
   snapshot-covered kernels; requires the limine hook to copy kernels/UKIs to the ESP,
   changes `ESP_PATH` (`system/boot/limine/default.conf:12`), the alongside XBOOTLDR mount, and
   every doctor check that reads `/boot/limine.conf`.
4. **NVIDIA source.** Debian non-free 550 only (simple, one origin; no Blackwell; open module
   missing in forky) / NVIDIA CUDA repo for Turing+ (current 590–615) + Debian 550 for
   Maxwell–Volta (two origins, pinning) / Ubuntu `ubuntu-drivers` (only if base = Ubuntu).
5. **Secure Boot.** Keep the hard block (no work) / sign Limine + UKIs with a MOK key chained
   from Debian's signed shim (requires key management, `sbsigntool`, `mokutil` enrollment,
   DKMS MOK signing).
6. **Shell installer on Debian.** Keep fromSource builds (violates rule 7, slow, needs Go ≥1.26
   and Qt -dev on the user box) / switch to the Ryoku apt repo (requires the apt publishing
   pipeline first) / drop Debian support from the shell installer until the repo exists.
7. **CachyOS variant.** Drop on Debian / replace with another kernel line (e.g. a Ryoku-built
   kernel .deb).
8. **AUR set.** Build each as .deb in the Ryoku repo / mirror vendor .debs where they exist
   (localsend, voxtype) and build the rest / ship some as Flatpak (Zen).
9. **Offline install.** Keep fully offline ISO (large baked closure per suite, plus NVIDIA
   stores) / online-only first release.
10. **Admin group.** Use Debian's `sudo` group (native, no extra file) / create `wheel` and keep
    the `%wheel` drop-in (identical to Arch, non-native on Debian).

## Cross-cutting findings

- `/etc/pacman.d/hooks`, `/usr/share/libalpm/hooks`, `/usr/lib/initcpio/install`,
  `/etc/mkinitcpio.conf.d` are written by: `chroot.sh:137-239`, `deploy.sh:254-265`,
  `nvidia.sh:223-225,251-276`, `bootloader.sh:301-312,729-743`, `ryoku/shell/deploy.sh:436-437`,
  `ryoku-boot-apply`, and doctor reconcilers. All need Debian equivalents: dracut
  `/etc/dracut.conf.d` + dracut modules or `/etc/initramfs-tools/{hooks,modules,conf.d}`;
  `/etc/kernel/postinst.d` / `postrm.d`; dpkg file triggers shipped in Ryoku packages; apt
  `DPkg::Pre-/Post-Invoke` for transaction-wrapping hooks.
- Kernel identity: Arch pkgbase (`linux`, `linux-cachyos`) via `/usr/lib/modules/*/pkgbase` is used
  by the installer, `nvidia.sh`, limine-entry-tool and `ryoku doctor`; Debian has versioned
  kernels and no pkgbase file.
- PAM: Arch `system-login` vs Debian/Ubuntu `common-auth`/`common-session` (`ryoku/lockscreen/sddm/setup:109,112`, `ryoku-shell-installer/engine.go:1096-1104`); the qylock and greeter PAM stacks (lockscreen port) have the same issue.
- Debian auto-enables units shipped by packages (docker.io → `docker.service`/`docker.socket`,
  snapper timers, `wpa_supplicant.service`); Ryoku's "deliberately not enabled" units
  (`base.packages:180-186`) need explicit disables in the installer and doctor.
- Subvolume `@pkg` → `/var/cache/apt/archives`; doctor's snapper/subvolume reconcilers and
  `ryoku/cli/internal/updater/bootguard.go` reference the layout.
- Qt QML path for Ryoku modules on Debian is `/usr/lib/x86_64-linux-gnu/qt6/qml` (container test
  asserts `/usr/lib/qt6/qml/Ryoku`, `installation/tests/container-install.sh` assertion block).
- Ryoku key = binary ed25519 OpenPGP cert usable directly as apt `Signed-By`.
- Go ≥ 1.26.4 is required to build the TUI and the shell installer (`installation/tui/go.mod:3-5`,
  `ryoku-shell-installer/go.mod:3`); trixie main has 1.24.
- `/etc/locale.conf` vs `/etc/default/locale`, `/etc/vconsole.conf` vs `/etc/default/keyboard`,
  `/etc/conf.d/snapper` vs `/etc/default/snapper`: any Ryoku component reading the Arch file
  names on a running system (doctor, Hub settings pages) needs the Debian path.
- `/etc/hosts`: Debian expects `127.0.1.1 <hostname>`; Ryoku deliberately writes none on Arch.
- Live medium path: archiso `/run/archiso/bootmnt` vs live-boot `/run/live/medium` vs casper `/cdrom`.
- `hwclock` is in `util-linux-extra` on Debian/Ubuntu.

## Debian/Ubuntu packages this section needs

Live image (installer tools): `mmdebstrap` `debootstrap` `arch-install-scripts` `debian-archive-keyring`
`ubuntu-keyring` `gdisk` `parted` `fdisk` `util-linux` `dosfstools` `btrfs-progs` `cryptsetup`
`dmsetup` `lvm2` `mdadm` `ntfs-3g` `e2fsprogs` `jq` `curl` `ca-certificates` `gnupg` `gpgv`
`efibootmgr` `pciutils` `iproute2` `network-manager` `iwd` `wpasupplicant` `kbd` `console-data`
`console-setup` `locales` `xkb-data` `cage` `foot` `rsync` `tar` `zstd` `netselect-apt`

Target bootstrap: `systemd-sysv` `udev` `dbus` `kmod` `util-linux-extra` `locales` `console-setup`
`keyboard-configuration` `kbd` `tzdata` `sudo` `ca-certificates` `curl` `gnupg` `jq` `pciutils`
`linux-image-amd64` `linux-headers-amd64` `dkms` `build-essential` `firmware-linux`
`firmware-linux-free` `firmware-linux-nonfree` `firmware-misc-nonfree` `firmware-amd-graphics`
`firmware-intel-graphics` `firmware-iwlwifi` `firmware-realtek` `firmware-atheros`
`firmware-brcm80211` `firmware-mediatek` `firmware-sof-signed` `amd64-microcode` `intel-microcode`
`dracut` `initramfs-tools` `cryptsetup-initramfs` `cryptsetup` `btrfs-progs` `dosfstools`
`efibootmgr` `plymouth` `snapper` `systemd-timesyncd` `systemd-boot-efi` `systemd-ukify`
`network-manager` `iwd` `wpasupplicant` `wireless-regdb` `iw` `nftables` `bluez` `rtkit`
`power-profiles-daemon` `fish` `sddm` `weston` `plocate`

Ubuntu substitutes: `linux-generic` `linux-headers-generic` `linux-firmware` `ubuntu-drivers-common`
`nvidia-driver-595-open` `nvidia-driver-580`

Drivers: `libgl1-mesa-dri` `mesa-vulkan-drivers` `mesa-va-drivers` `libvulkan1`
`intel-media-va-driver-non-free` `intel-media-va-driver` `libmfx-gen1.2` `libvpl2`
`nvidia-driver` `nvidia-kernel-dkms` `nvidia-open-kernel-dkms` `nvidia-driver-libs`
`nvidia-suspend-common` `nvidia-vaapi-driver` `firmware-nvidia-gsp` `nvidia-tesla-470-driver`
`broadcom-sta-dkms` (NVIDIA repo: `cuda-keyring` `nvidia-open` `nvidia-driver-pinning-<branch>`)

Secure Boot option: `shim-signed` `mokutil` `sbsigntool`

Build-only (Ryoku CI, not target): `golang-go` (≥1.26.4 → trixie-backports) `git` `nasm` `mtools`
`llvm` `lld` `clang` `autoconf` `automake` `make` `meson` `ninja-build` `libpam0g-dev`
`libsystemd-dev` `libglib2.0-dev` `dpkg-dev` `apt-utils` (apt-ftparchive)

Test hosts: `qemu-system-x86` `qemu-utils` `ovmf` `python3-pexpect` `tesseract-ocr` `shellcheck`

To be built as .deb (not packaged anywhere): `limine` `limine-entry-tool` (+ Debian kernel hooks)
`limine-snapper-sync` `broadcom-bt-firmware` and the AUR set (`phinger-cursors`
`catppuccin-cursors` `apple-cursor` `nvibrant` `localsend` `voxtype` `fonts-fraunces`
`zen-browser` `libpam-fprint-grosshack`)

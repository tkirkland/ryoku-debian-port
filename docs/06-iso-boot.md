# 06: Live ISO and boot chain

Scope: everything from "build the installer ISO" to "the installed machine reaches
the greeter". That covers the archiso profile and its build orchestrator
(`installation/iso/`), the offline package bake, the ISO CI workflows, the boot
chain the installer lays on the target (`system/boot/`: Limine, limine-entry-tool,
limine-snapper-sync, the initramfs config, Plymouth, `ryoku-boot-apply`), the
boot-chain half of `installation/backend/lib/bootloader.sh` and `snapshots.sh`, the
kernel story (stock and CachyOS), and Secure Boot. Source pinned at
`98a0368253d9628be72b853985878a5db90e1547`. External facts were checked on
2026-10-17 against: Debian/Ubuntu madison (via `tools/pkgver`, re-run after its
contrib/non-free/non-free-firmware fix; every package marked absent here is absent
in all components), sources.debian.org,
archlinux.org, upstream git tags, archiso v91 `mkarchiso`, and the upstream sources
of limine 12.9.3, limine-entry-tool 1.37.1 and limine-snapper-sync 1.31.0.

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| ISO build orchestrator | `installation/iso/build.sh`, `profiledef.sh` | NO | High | mkarchiso/pacman/archiso-only; rewrite onto live-build or mmdebstrap + squashfs + xorriso |
| Live package set | `installation/iso/packages.x86_64`, `pacman.conf` | NO | Medium | names differ; `limine`, JetBrainsMono Nerd Font, `reflector`, `ryoku-cursors` absent from Debian |
| Live environment overlay | `installation/iso/airootfs/` | PARTIAL | Low | `/usr/bin/agetty` path, pacman keyring units, `localectl`/console fonts the session script needs are not in Debian's `kbd` |
| Live boot menus + live initramfs | `syslinux/`, `efiboot/`, `grub/loopback.cfg`, `airootfs/etc/mkinitcpio*` | NO | Medium | archiso cmdline (`archisobasedir`, `archisosearchuuid`, `cow_spacesize`, `copytoram`, `img_dev`) and `/run/archiso` paths |
| Offline package closure | `installation/iso/offline-repo.sh` | NO | High | pacman/repo-add/makepkg/AUR throughout; apt rewrite |
| ISO CI | `.github/workflows/build-iso*.yml` | NO | Medium | `archlinux:latest` container + pacman toolchain |
| Limine config | `system/boot/limine/*.conf`, `backend/lib/bootloader.sh` | PARTIAL | Medium | `/boot` = FAT ESP layout collides with Debian kernel packages writing `/boot`; kernel names `linux`/`linux-cachyos` |
| Limine binary | `limine` (Arch extra) | NO | Low | not packaged in Debian or Ubuntu; build 12.9.3 |
| limine-entry-tool + mkinitcpio hook | `release/packages/limine-mkinitcpio-hook` | NO | High | pacman hooks, `/usr/lib/modules/*/pkgbase`, `pacman -Qqo`, `mkinitcpio --uki`; GraalVM native-image build |
| limine-snapper-sync | `release/packages/limine-snapper-sync`, `backend/lib/snapshots.sh` | PARTIAL | Medium | pacman lock hook; snapper config file path; GraalVM build |
| Existing-OS entries | `system/boot/limine/ryoku-windows-entry`, `45-ryoku-windows` | YES | Low | none (depends on the entry-tool port for its post.d hook to fire) |
| Initramfs config | `system/boot/mkinitcpio/` | NO | Medium | mkinitcpio HOOKS have no 1:1 file; `encrypt`/`cryptdevice=`; nouveau-trim hook must be rewritten |
| Plymouth theme | `system/boot/plymouth/ryoku/` | YES (theme) / PARTIAL (integration) | Low | `plymouth-label` + Cantarell font copy into the initramfs |
| ryoku-boot-apply | `system/boot/ryoku-boot-apply` | PARTIAL | Low | calls `limine-mkinitcpio`/`mkinitcpio -P`; pacman scriptlet caller |
| Kernel command line | `system/boot/limine/default.conf`, `bootloader.sh` | PARTIAL | Low | `cryptdevice=` is Arch-only; `rd.udev.log_level` behaviour under initramfs-tools |
| Kernels (stock + CachyOS) | `docs/kernels.md`, `system/packages/cachyos.packages`, `backend/lib/cachyos.sh` | PARTIAL | High | trixie 6.12 lacks sched_ext/ntsync/asus-armoury; no CachyOS repo for Debian; whole CachyOS layer absent |
| Secure Boot | `backend/lib/preflight.sh`, `tui/system.go` | PARTIAL | High | Debian kernels enforce lockdown under SB (unsigned DKMS modules + hibernation blocked); Limine unsigned; `sbctl` not packaged |

---

### ISO build orchestrator (`installation/iso/build.sh`, `installation/iso/profiledef.sh`)

**What it does:** stages a throwaway copy of the archiso profile, bakes the
installer and the repo payload into its airootfs, then runs `mkarchiso`
(`installation/iso/build.sh:4-7`). Step by step:

| Step | Lines | Action |
|---|---|---|
| env | `build.sh:26-29` | `RYOKU_ISO_OUT` (./out), `RYOKU_ISO_WORK` (./work), `RYOKU_ISO_STAGE` (./staging) |
| reproducibility anchor | `build.sh:36-40` | `SOURCE_DATE_EPOCH` = commit committer time (`git log -1 --pretty=%ct`); an exported value survives only when there is no git history |
| provenance | `build.sh:45-48` | `PAYLOAD_COMMIT/DATE/VERSION/NAME` from git, `VERSION`, `CODENAME` |
| variant | `build.sh:58,62` | `RYOKU_VARIANT` = `plain` or `cachyos` |
| 0 preflight | `build.sh:125-127` | TUI `go.mod`, backend script and `lib/` must exist |
| 1 stage profile | `build.sh:130-136` | copies `profiledef.sh packages.x86_64 pacman.conf airootfs efiboot syslinux grub` into `staging/profile` |
| optional freeze | `build.sh:144-149` | `RYOKU_ISO_REPRO=1` rewrites `[core]/[extra]` to `archive.archlinux.org/repos/<YYYY/MM/DD>` of the commit date |
| 1b [ryoku] repo | `build.sh:82-122,153` | stages a local file:// `[ryoku]` repo (from `RYOKU_ISO_LOCAL_REPO`, `release/repo/out/x86_64`, or fetched from `repo.ryoku.dev/stable/x86_64`), requires `ryoku-cursors-*.pkg.tar.zst`, rewrites `file://@RYOKU_ISO_REPO@` in the staged `pacman.conf` |
| 2 TUI | `build.sh:157-160` | `CGO_ENABLED=0 go build -trimpath -ldflags '-s -w -buildid='` -> `airootfs/usr/local/bin/ryoku-tui` |
| 3 backend | `build.sh:165-168` | `ryoku-install` + `lib/` -> `airootfs/usr/local/lib/ryoku/backend/` |
| 3b i18n | `build.sh:173-176` | `ryoku/i18n/catalog/*.json` + `langs.json` -> `/usr/share/ryoku/i18n` |
| 4 payload | `build.sh:66-70,179-180` | `git archive HEAD` of the whole repo -> `/usr/share/ryoku` (tracked files only) |
| stamp | `build.sh:185-190,194` | `/usr/share/ryoku/.payload` (commit/date/version/name), `/usr/share/ryoku/variant` |
| motd | `build.sh:198-202` | fills `@RYOKU_NAME@ @RYOKU_VERSION@ @RYOKU_COMMIT@` in the staged motd |
| 4b ryoku-shell | `build.sh:207-209` | static Go build -> `/usr/share/ryoku/ryoku/shell/ipc/ryoku-shell` |
| 4d ryoku-hub | `build.sh:212-214` | static Go build -> `/usr/share/ryoku/ryoku/hub/backend/ryoku-hub` |
| 4c Ryoku.Blobs | `build.sh:219-224` | `cmake`+`ninja` Qt6 QML plugin (`ryoku/shell/plugin/build.sh`) -> `/usr/share/ryoku/ryoku/shell/plugin/dist` |
| 4e offline repo | `build.sh:231-242` | `offline-repo.sh` bakes the full target closure into `/usr/share/ryoku/offline/repo` (skipped with `RYOKU_OFFLINE_SKIP=1`) |
| 5 modes | `build.sh:246-250` | chmod 0755 on the launchers |
| 6 mkarchiso | `build.sh:260-290` | wipes `work/` (stale-image trap, `:276-280`), runs `mkarchiso -v -w work -o out` under `sudo --preserve-env=SOURCE_DATE_EPOCH` |
| checksums | `build.sh:297-298` | `sha256sum *.iso > SHA256SUMS` |

`profiledef.sh`: `iso_name=ryoku` (`:11`), `iso_label=RYOKU_<YYYYMM>` and
`iso_version=<YYYY.MM.DD>` from `SOURCE_DATE_EPOCH` (`:12,15`), `install_dir=arch`
(`:16`), `bootmodes=('bios.syslinux' 'uefi.systemd-boot')` (`:18-19`), squashfs
with `-comp zstd -Xcompression-level 19 -b 1M` (`:22-23`), `file_permissions`
for `/etc/shadow` 0400, `/root` 0750 and the four launchers (`:25-34`).

Output layout (archiso v91 `mkarchiso`, the tool `build.sh:287` runs):
`/arch/x86_64/airootfs.sfs` (`mkarchiso:190`), kernel/initramfs under
`/arch/boot/x86_64/`, `/boot/<iso_uuid>.uuid` where `iso_uuid` is
`SOURCE_DATE_EPOCH` formatted `%F-%H-%M-%S-00` (`mkarchiso:1738,1797`).
xorriso is run as `-as mkisofs -iso-level 3 -full-iso9660-filenames -joliet
-joliet-long -rational-rock -volid -appid -publisher -preparer`
(`mkarchiso:1574-1586`) plus, for `bios.syslinux`: El Torito
`boot/syslinux/isolinux.bin` + `boot.cat`, `-no-emul-boot -boot-load-size 4
-boot-info-table`, `-isohybrid-mbr isohdpfx.bin --mbr-force-bootable
-partition_offset 16` (`mkarchiso:1453-1462`); for `uefi.systemd-boot`: a FAT
`efiboot.img` (`mkfs.fat -C -n ARCHISO_EFI`, `mkarchiso:586-615`) appended as GPT
partition 2 type `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`, `-isohybrid-gpt-basdat`
(because BIOS mode is also present), `-eltorito-alt-boot -e
--interval:appended_partition_2:all:: -no-emul-boot` (`mkarchiso:1463-1476`).
Result: one hybrid image that boots BIOS (isolinux El Torito + MBR) and UEFI (El
Torito EFI + GPT ESP) from optical media or a raw `dd` to USB.

**Arch couplings:**
- `build.sh:260-290` runs `mkarchiso` (package `archiso`), which itself pacstraps the airootfs, runs `mkinitcpio` in it and assembles the ISO.
- `build.sh:107-113` parses `ryoku.db` with `bsdtar`/`awk %FILENAME%` (pacman repo db format).
- `build.sh:118` rewrites a pacman `Server = file://` line; `build.sh:147` points pacman at the Arch Linux Archive.
- `build.sh:157,219-220` error messages say `pacman -S go`, `pacman -S cmake ninja qt6-shadertools`.
- `build.sh:219-224` builds Ryoku.Blobs against the BUILD HOST's Qt (Arch container in CI) and ships it inside the payload; on Debian the target's Qt is 6.8 (trixie) and the plugin must be compiled against the target suite's Qt, not the host's.
- `profiledef.sh:16-19` (`install_dir`, `bootmodes`) are archiso concepts; `profiledef.sh:12,15` `iso_label`/`iso_version` feed mkarchiso.

**Dependencies (build host):**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| archiso | ISO assembly (`build.sh:287`) | live-build, or mmdebstrap + squashfs-tools + xorriso | live-build 1:20250505+deb13u1; mmdebstrap 1.5.7-1+deb13u1 | - | live-build 1:20250814; mmdebstrap 1.5.7-3 | 1:20250814; 1.6.0-5 | live-build 3.0~a57-1ubuntu54 (old Ubuntu fork); mmdebstrap 1.5.7-3 | live-build >= 20230502 for `--chroot-squashfs-compression-type zstd` (lb_config.1:303) |
| squashfs-tools | airootfs.sfs (`profiledef.sh:22-23`) | squashfs-tools | 1:4.6.1-1+b1 | - | 1:4.7.5-1 | 1:4.7.5-1 | 1:4.7.5-1 | honors `SOURCE_DATE_EPOCH` (mksquashfs.c:6125 in 4.6.1) |
| libisoburn (xorriso) | ISO write | xorriso | 1.5.6-1.2+b1 | - | 1.5.8.pl02-2 | 1.5.8.pl02-2 | 1:1.5.6-1.1ubuntu4 | - |
| dosfstools | efiboot.img | dosfstools | 4.2-1.2 | - | 4.2-1.2+b2 | 4.2-1.2+b2 | 4.2-1.2build1 | 4.2 honors `SOURCE_DATE_EPOCH` (mkfs.fat.c:1077) |
| mtools | populate efi.img | mtools | 4.0.48-1 | - | 4.0.49-1+b1 | 4.0.49-1+b1 | 4.0.49-1 | - |
| go | 3 static binaries (`build.sh:160,209,214`) | golang-go | 2:1.24~2 | 2:1.27~1~bpo13+1 | 2:1.27~1 | 2:1.27~1 | 2:1.26~1 | each module's `toolchain` line (README.md:168-171); `GOTOOLCHAIN=auto` downloads it |
| cmake, ninja, qt6-base, qt6-declarative, qt6-shadertools, qt6-multimedia | Ryoku.Blobs (`build.sh:219-224`, `ryoku/shell/plugin/CMakeLists.txt:18`) | cmake, ninja-build, qt6-base-dev, qt6-declarative-dev, qt6-shadertools-dev, qt6-multimedia-dev | see shell agent | | | | | Qt >= 6.5 (`CMakeLists.txt:18`) |
| git, curl, bsdtar | payload, repo fetch | git, curl, libarchive-tools | 1:2.47.3; 8.14.1; 3.7.4 | | | | | - |

**As-is on Debian:** NO, mkarchiso and pacman are the build engine.

**Port steps:**

Two implementations are possible; both map the same profile files. The choice is
under "Questions for the human".

*Option A: live-build (Debian only).* Directory layout and file map:

| archiso file | live-build file |
|---|---|
| `profiledef.sh` | `auto/config` calling `lb config` (flags below) |
| `packages.x86_64` | `config/package-lists/ryoku.list.chroot` (one Debian name per line) |
| `airootfs/**` | `config/includes.chroot_after_packages/**` (same relative paths) |
| `profiledef.sh:25-34 file_permissions` | modes from the checkout + `config/hooks/normal/0100-ryoku-perms.hook.chroot` (`chmod 0400 /etc/shadow; chmod 0750 /root`) |
| build.sh steps 2-4e (bake into airootfs) | run before `lb build`, writing into `config/includes.chroot_after_packages/` |
| `pacman.conf [ryoku]` | `config/archives/ryoku.list.chroot` + `config/archives/ryoku.key.chroot` |
| `syslinux/*.cfg` | `config/bootloaders/isolinux/` (overrides live-build's `share/bootloaders/isolinux`) |
| `efiboot/loader/*` (systemd-boot) | `config/bootloaders/grub-pc/` grub.cfg/config.cfg (live-build's EFI loader is GRUB only: `functions/configuration.sh:632` rejects anything but `grub-efi`) |
| `grub/loopback.cfg` | live-build ships its own `/boot/grub/loopback.cfg` template in `share/bootloaders/grub-pc`; override in `config/bootloaders/grub-pc/loopback.cfg` |
| `airootfs/etc/mkinitcpio.conf.d/archiso.conf`, `mkinitcpio.d/linux.preset` | deleted; `--initramfs live-boot` |

```sh
# auto/config
lb config noauto \
  --mode debian --distribution trixie --architecture amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-image iso-hybrid \
  --bootloaders "syslinux,grub-efi" --uefi-secure-boot enable \
  --debian-installer none --linux-flavours amd64 \
  --initramfs live-boot --initsystem systemd \
  --apt-recommends false --memtest none \
  --firmware-chroot true --firmware-binary true \
  --security true --updates true --backports false \
  --chroot-squashfs-compression-type zstd --chroot-squashfs-compression-level 19 \
  --iso-volume "RYOKU_$(date -u -d@"$SOURCE_DATE_EPOCH" +%Y%m)" \
  --iso-application "Ryoku Linux Installer" \
  --iso-publisher "Ryoku Linux <https://ryoku.sh>" \
  --image-name ryoku \
  --bootappend-live "boot=live components overlay-size=1G quiet loglevel=3 console=ttyS0,115200 console=tty0" \
  --checksums sha256 --zsync false \
  "${@}"
```
live-build honors an exported `SOURCE_DATE_EPOCH` (`functions/configuration.sh:48-57`,
`_REPRODUCIBLE`); pin packages with `--mirror-bootstrap/--mirror-chroot
http://snapshot.debian.org/archive/debian/<YYYYMMDDTHHMMSSZ>/` (replaces
`RYOKU_ISO_REPRO`, `build.sh:144-149`). The squashfs block size (`-b 1M`,
`profiledef.sh:23`) has no lb_config flag.

*Option B: custom pipeline (Debian and Ubuntu).* Prior art:
`/home/me/src/debian13-stripped/build-rootfs.sh:53-56` (mmdebstrap) +
`/home/me/src/debian13-stripped/build-iso.sh:33-78` (squashfs + grub-mkrescue);
`/home/me/src/Debian13-Hyprland/tools/iso-assemble.sh:409-455` (xorriso with
shim/signed GRUB replay and appended EFI partition).

1. `export SOURCE_DATE_EPOCH=$(git -C "$REPO_ROOT" log -1 --pretty=%ct)` (same as `build.sh:36-40`).
2. Root filesystem (replaces mkarchiso's pacstrap):
   ```sh
   mmdebstrap --variant=minbase --mode=root \
     --components="main contrib non-free non-free-firmware" \
     --include="$(grep -vE '^\s*(#|$)' packages.live | paste -sd, -)" \
     --aptopt='Acquire::Retries "3"' \
     --customize-hook='sync-in overlay /' \
     --customize-hook='chroot "$1" passwd -d root' \
     --customize-hook='chroot "$1" update-initramfs -u -k all' \
     trixie work/rootfs \
     "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" \
     "deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware" \
     "deb [signed-by=/usr/share/keyrings/ryoku-archive-keyring.gpg] https://repo.ryoku.dev/debian trixie main"
   ```
   mmdebstrap honors `SOURCE_DATE_EPOCH` for mtimes and filesystem UUID/hash seed
   (`mmdebstrap:5563,8356`) and empties `/etc/machine-id` (`mmdebstrap:8646`).
   Ubuntu: same command with suite `resolute`, archive `http://archive.ubuntu.com/ubuntu`, components `main restricted universe multiverse`.
3. Bake steps 2-4e of `build.sh` into `work/rootfs` unchanged (Go builds are distro-neutral; Ryoku.Blobs must be built inside a chroot of the target suite so it links the target Qt).
4. `mksquashfs work/rootfs iso/live/filesystem.squashfs -comp zstd -Xcompression-level 19 -b 1M -noappend` (options of `profiledef.sh:23`).
5. `cp work/rootfs/boot/vmlinuz-$KVER iso/live/vmlinuz; cp work/rootfs/boot/initrd.img-$KVER iso/live/initrd.img` (kernel selection as `debian13-stripped/build-iso.sh:41-49`).
6. `printf '%s\n' "Ryoku <name> <version> $(date -u -d@$SOURCE_DATE_EPOCH +%F)" > iso/.disk/info` (required: Debian's signed CD GRUB searches `/.disk/info` to find its prefix, grub2 `debian/build-efi-images:62-74`).
7. Write `iso/boot/grub/grub.cfg`, `iso/boot/grub/loopback.cfg`, `iso/isolinux/isolinux.cfg` (contents under "Live boot menus").
8. EFI image (shim + Debian-signed GRUB, Secure Boot capable):
   ```sh
   mkfs.fat -C -n RYOKU_EFI iso-efi.img 8192
   mmd   -i iso-efi.img ::/EFI ::/EFI/boot
   mcopy -i iso-efi.img /usr/lib/shim/shimx64.efi.signed                 ::/EFI/boot/bootx64.efi
   mcopy -i iso-efi.img /usr/lib/grub/x86_64-efi-signed/gcdx64.efi.signed ::/EFI/boot/grubx64.efi
   mcopy -i iso-efi.img /usr/lib/shim/mmx64.efi.signed                   ::/EFI/boot/mmx64.efi
   ```
   `mmx64.efi` is mandatory: without it shim dies with `import_mok_state() failed` on a machine with a pending MOK request (`Debian13-Hyprland/tools/iso-assemble.sh:340-347`).
9. BIOS: `cp /usr/lib/ISOLINUX/isolinux.bin /usr/lib/syslinux/modules/bios/{ldlinux,vesamenu,libcom32,libutil,reboot,poweroff}.c32 iso/isolinux/`.
10. Assemble with the same xorriso flags archiso v91 uses (swap only the EFI payload):
    ```sh
    xorriso -no_rc -as mkisofs -iso-level 3 -full-iso9660-filenames -joliet -joliet-long -rational-rock \
      -volid "RYOKU_$(date -u -d@$SOURCE_DATE_EPOCH +%Y%m)" -appid "Ryoku Linux Installer" \
      -publisher "Ryoku Linux <https://ryoku.sh>" -preparer "prepared by ryoku build.sh" \
      -eltorito-boot isolinux/isolinux.bin -eltorito-catalog isolinux/boot.cat \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin --mbr-force-bootable -partition_offset 16 \
      -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B iso-efi.img -isohybrid-gpt-basdat \
      -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot \
      -output "out/ryoku-$(date -u -d@$SOURCE_DATE_EPOCH +%Y.%m.%d)-x86_64.iso" iso/
    ```
    xorriso derives volume timestamps from `SOURCE_DATE_EPOCH`. Alternative without Secure Boot: `grub-mkrescue -o out.iso iso -- -volid RYOKU_...` (`debian13-stripped/build-iso.sh:67-78`, which stages `grub-pc-bin` by `apt-get download` + `dpkg -x` and binds it over `/usr/lib/grub` inside `unshare -m` so nothing is installed on the host).
11. `sha256sum *.iso > SHA256SUMS` (unchanged, `build.sh:297-298`).

**Complexity:** High. Every assembly step changes tool; the bake steps (2-4e) survive.

**Issues / risks:**
- live-build's EFI path is GRUB only (`functions/configuration.sh:632`); the systemd-boot UEFI menu (`efiboot/loader/`) cannot be reproduced with live-build. Option B can use systemd-boot (`systemd-boot-efi` ships `/usr/lib/systemd/boot/efi/systemd-bootx64.efi`), but then kernel+initrd must live inside the FAT efi image (systemd-boot reads FAT only) and Secure Boot needs shim + Debian's signed `systemd-boot-efi-amd64-signed` (257.13+1~deb13u1) renamed `grubx64.efi`; not tested here.
- Debian's modern live-build is not in Ubuntu: resolute carries the Ubuntu fork `3.0~a57-1ubuntu54`. An Ubuntu base needs Option B (mmdebstrap 1.5.7 and `live-boot` 1:20250815 are in resolute) or Ubuntu's own `casper` (26.04.2).
- CI comment says `SOURCE_DATE_EPOCH="$(date -u +%s)"` makes builds reproducible (`build-iso-reusable.yml:172-174`), but `build.sh:36-38` overwrites it with the commit time whenever git history exists (CI checks out with `fetch-depth: 0`, `:95`). The CI value is dead.
- Stock Debian live GRUB configs have no `timeout` and isolinux uses `timeout 0` (menus wait forever, `Debian13-Hyprland/tools/iso-assemble.sh:390-404`); a custom grub.cfg must set `timeout` itself (Ryoku's syslinux uses `TIMEOUT 50`, `syslinux/archiso_sys.cfg:4`; systemd-boot `timeout 5`, `efiboot/loader/loader.conf:1`).
- mmdebstrap/mkinitramfs in a chroot read the build host's `/proc` (mdadm `mkconf` leaked host arrays into the image, `debian13-stripped/build-rootfs.sh:579-588`); scrub `/etc/mdadm/mdadm.conf ARRAY` lines and `/etc/machine-id`.
- Host rule from the brief/user: tools missing on the build host must be staged with `apt-get download` + `dpkg -x`, never installed (`debian13-stripped/build-iso.sh:9-27`).

**Questions for the human:**
- ISO toolchain: (a) live-build: declarative `lb config`, Debian-only, GRUB-only EFI, built-in reproducibility switch; (b) mmdebstrap + squashfs + xorriso script: works for Debian and Ubuntu, any EFI loader, the script owns every step (~150 lines, prior art in debian13-stripped).

---

### Live package set (`installation/iso/packages.x86_64`, `installation/iso/pacman.conf`)

**What it does:** defines the live installer environment only; the target is
pacstrapped from `system/packages` (`packages.x86_64:1-6`). `pacman.conf` enables
`[core]`, `[extra]` and a build-time file:// `[ryoku]` repo with `SigLevel = Never`
(`pacman.conf:17-39`).

**Arch couplings:**
- Arch package names throughout (`packages.x86_64:9-93`); `base` meta (`:9`), `mkinitcpio-archiso` (`:15`), `arch-install-scripts` for pacstrap (`:24`), `reflector` (`:41`), `ttf-jetbrains-mono-nerd` (`:61`), `ryoku-cursors` from `[ryoku]` (`:66`).
- `pacman.conf:14-15,38` signature policy; `pacman.conf:18,21` mirrorlist Include.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| base | live base (`:9`) | mmdebstrap minbase + systemd, systemd-sysv, udev, dbus | systemd 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | - |
| linux | live kernel (`:10`) | linux-image-amd64 (Ubuntu: linux-image-generic) | 6.12.107-1 | 7.2.6-1~bpo13+1 | 7.2.11-1 | 7.2.11-1 | 7.0.0-39.39 | - |
| linux-firmware | live hw (`:11`) | firmware-linux-free + firmware-misc-nonfree, firmware-amd-graphics, firmware-iwlwifi, firmware-realtek, firmware-sof-signed, firmware-nvidia-gsp (non-free-firmware); Ubuntu linux-firmware | free 20241210-2; nonfree 20250410-2; sof 2025.01-1; nvidia-gsp 550.163.01-2 | nonfree 20260916-1~bpo13+1; nvidia-gsp 550.163.01-4~bpo13+1 | 20260916-1; sof 2026.09.1-1 | 20260916-1 | linux-firmware 20260319.git217ca6e4.1ubuntu; firmware-sof-signed 2025.12.2-1 | - |
| mkinitcpio | live initramfs (`:12`) | initramfs-tools | 0.148.4 | - | 0.151 | 0.151 | 0.151ubuntu1 | - |
| mkinitcpio-archiso | squashfs/cow hooks (`:13-15`) | live-boot, live-boot-initramfs-tools | 1:20250815~deb13u1 | - | 1:20250815 | 1:20250815 | 1:20250815 | `overlay-size=`, `toram`, `findiso=` (live-boot `components/9990-cmdline-old`) |
| amd-ucode | early microcode (`:16`) | amd64-microcode (non-free-firmware) | 3.20250311.1 | - | 3.20251202.1 | 3.20251202.1 | 3.20251202.1ubuntu2 | - |
| intel-ucode | early microcode (`:17`) | intel-microcode (non-free-firmware) | 3.20251111.1~deb13u1 | - | 3.20260227.1 | 3.20260227.1 | 3.20260210.1ubuntu2 | - |
| syslinux | BIOS ISO loader (`:21`) | isolinux, syslinux-common | 3:6.04~git20190206.bf6db5b4+dfsg1-3.1 | - | -3.2 | -3.2 | -3.2ubuntu1 | - |
| (systemd-boot in systemd) | UEFI ISO loader (`:19-20`) | shim-signed + grub-efi-amd64-signed (or systemd-boot-efi) | shim 1.51~1+deb13u1+16.1-2~deb13u1; grub 1+2.12+9+deb13u2 | - | 1.51+16.1-2; 1+2.14+4 | same | 1.59+15.8-0ubuntu2; 1.215+2.14-2ubuntu1 | - |
| arch-install-scripts | pacstrap/arch-chroot/genfstab (`:24`) | arch-install-scripts (arch-chroot, genfstab) + mmdebstrap or debootstrap (replaces pacstrap) | 28-1; mmdebstrap 1.5.7-1+deb13u1; debootstrap 1.0.141 | 31-1~bpo13+1 | 31-1; 1.5.7-3; 1.0.145 | 31-1; 1.6.0-5; 1.0.145 | 31-1; 1.5.7-3; 1.0.142ubuntu2 | installer agent decides |
| parted | partitioning (`:25`) | parted | 3.6-5 | - | 3.8-2 | 3.8-2 | 3.6-6 | - |
| gptfdisk | partitioning (`:26`) | gdisk | 1.0.10-2+b1 | - | 1.0.10-3 | 1.0.10-3 | 1.0.10-2build1 | - |
| btrfs-progs | root fs (`:27`) | btrfs-progs | 6.14-1 | 7.1-1~bpo13+1 | 7.1-1 | 7.1-1 | 6.17.1-1build1 | >= 5.16 for `mkswapfile`/`map-swapfile -r` (`system/boot/README.md:64-67`, `bootloader.sh:271-273`) |
| dosfstools | ESP (`:28`) | dosfstools | 4.2-1.2 | - | 4.2-1.2+b2 | 4.2-1.2+b2 | 4.2-1.2build1 | - |
| cryptsetup | LUKS (`:29`) | cryptsetup | 2:2.7.5-2 | - | 2:2.8.8-1 | 2:2.8.8-1 | 2:2.8.4-1ubuntu4 | - |
| e2fsprogs | (`:30`) | e2fsprogs | 1.47.2-3+b12 | - | 1.47.4-1+b2 | 1.47.4-1+b2 | 1.47.2-3ubuntu4 | - |
| ntfsprogs, ntfs-3g | NTFS shrink (`:34-35`) | ntfs-3g (ships ntfsresize/mkntfs) | 1:2022.10.3-5+deb13u2 | - | 1:2026.9.28-2 | 1:2026.9.28-2 | 1:2022.10.3-5ubuntu1.1 | - |
| efibootmgr | NVRAM entry (`:36`) | efibootmgr | 18-2+b1 | - | 18-4.1+b1 | 18-4.1+b1 | 18-4ubuntu1 | - |
| limine | target loader source (`:37`, `bootloader.sh:471`) | none: build (see "Limine binary") | - | - | - | - | - | 12 (`limine.conf:29`) |
| reflector | mirror ranking (`:38-41`) | netselect-apt (Debian only) | 0.3.ds1-31 | - | 0.3.ds1-31 | 0.3.ds1-31 | - | installer agent |
| networkmanager | Wi-Fi (`:47`) | network-manager | 1.52.1-1 | - | 1.58.1-1 | 1.58.1-1 | 1.54.3-2ubuntu3.1 | - |
| iwd | NM backend (`:48`) | iwd | 3.8-2 | - | 3.12-1 | 3.12-1 | 3.10-1ubuntu1 | - |
| wpa_supplicant | WPA3-SAE fallback (`:43-49`) | wpasupplicant | 2:2.10-24 | - | 2:2.10-25+b2 | same | 2:2.11-0ubuntu5 | - |
| wireless-regdb | (`:50`) | wireless-regdb | 2026.05.30-1~deb13u1 | - | 2026.09.03-1 | same | 2026.05.30-0ubuntu1~26.04.1 | - |
| kbd | keymaps + setfont (`:53`) | kbd + console-data (keymaps) + console-setup-linux (fonts) | kbd 2.7.1-2; console-data 2:1.12-9; console-setup-linux 1.242~deb13u1 | - | 2.10.0-1+b1; 2:1.12-11; 1.249 | same | 2.7.1-2ubuntu2; 2:1.12-10; 1.237ubuntu3.1 | Debian `kbd` ships no `/usr/share/keymaps` and no `/usr/share/consolefonts` (packages.debian.org filelist) |
| cage | kiosk (`:58`) | cage | 0.2.0-2 | - | 0.3.1-1 | 0.3.1-1 | 0.2.1-1 | `-m last` (`ryoku-installer-session:181`) |
| foot | terminal (`:59`) | foot | 1.21.0-2 | - | 1.28.0-1 | 1.28.0-1 | 1.25.0-1 | `main.dpi-aware` (foot >= 1.16, `ryoku-installer-session:87-88`) |
| xorg-xwayland | (`:60`) | xwayland | 2:24.1.6-1 | - | 2:24.1.14-1 | same | 2:24.1.10-1 | - |
| ttf-jetbrains-mono-nerd | kiosk font `JetBrainsMono Nerd Font` (`:61`, `ryoku-installer-session:182`) | none; `fonts-jetbrains-mono` is the non-Nerd family (2.304+ds-5) | - | - | - | - | - | build deb from nerd-fonts v3.5.1 `JetBrainsMono.tar.xz` -> `/usr/share/fonts/truetype/jetbrains-mono-nerd/` |
| ryoku-cursors | Bibata pointer (`:62-66`) | Ryoku apt repo deb | - | - | - | - | - | packages agent |
| git curl jq sudo less vim openssl | CLI (`:69-81`) | same names | 1:2.47.3; 8.14.1; 1.7.1; 1.9.16p2; 668; 2:9.1.1230; 3.5.7 | curl 8.21.0 | | | | - |
| pciutils | GPU/VMD probe (`:85`) | pciutils | 1:3.13.0-2 | - | 1:3.15.0-2 | same | 1:3.14.0-1build2 | - |
| mdadm | (`:91`) | mdadm | 4.4-11 | - | 4.6-3 | 4.6-3 | 4.5-5ubuntu1.1 | - |
| lvm2 | (`:93`) | lvm2 | 2.03.31-2 | - | 2.03.31-2+b2 | same | 2.03.31-2ubuntu3 | - |

**As-is on Debian:** NO, names and two packages (limine, Nerd font) differ or are absent.

**Port steps:**
1. Create `installation/iso/packages.live` with the Debian names from the table (plus `live-boot`, `live-boot-initramfs-tools`, `console-data`, `console-setup-linux`, `debian-archive-keyring`, the Ryoku archive keyring deb, and the locally built `limine` and JetBrainsMono Nerd Font debs).
2. Replace `pacman.conf` with apt sources (Option A: `config/archives/*.list.chroot`; Option B: mmdebstrap positional sources). The build-time Ryoku repo maps to `deb [trusted=yes] file:/path/to/staged-repo ./` inside the chroot only, mirroring `SigLevel = Never` scoped to the build (`pacman.conf:30-36`).
3. Build the JetBrainsMono Nerd Font deb: download `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.tar.xz`, install `*.ttf` to `/usr/share/fonts/truetype/jetbrains-mono-nerd/`, `fc-cache` trigger is automatic via fontconfig's dpkg trigger.

**Complexity:** Medium. Mostly renames; two packages to build.

**Issues / risks:**
- `reflector` has no Ubuntu equivalent (netselect-apt is Debian-only).
- `non-free-firmware` must be enabled or firmware/microcode are absent (Debian splits `linux-firmware` across ~15 packages).

---

### Live environment overlay (`installation/iso/airootfs/`)

**What it does:** files laid over the live root:
- `etc/hostname` = `ryoku` (`:1`); `etc/locale.conf` `LANG=C.UTF-8` (`:1`); `etc/vconsole.conf` `KEYMAP=us` (`:1`); symlink `etc/localtime -> /usr/share/zoneinfo/UTC`.
- `etc/shadow` `root::14871::::::` (empty root password, `:1`).
- `etc/systemd/system/getty@tty1.service.d/autologin.conf`: `ExecStart=-/usr/bin/agetty --noreset --noclear --autologin root - ${TERM}` (`:1-3`).
- Enabled units (symlinks): `multi-user.target.wants/NetworkManager.service`, `multi-user.target.wants/pacman-init.service`, `sysinit.target.wants/systemd-timesyncd.service`, `getty.target.wants/serial-getty@ttyS0.service`; masked `systemd-firstboot.service -> /dev/null`.
- `etc/systemd/system/pacman-init.service` + `etc-pacman.d-gnupg.mount`: tmpfs keyring, `pacman-key --init/--populate` each boot (`pacman-init.service:1-15`, `etc-pacman.d-gnupg.mount:1-8`).
- `etc/NetworkManager/conf.d/wifi-backend.conf`: `wifi.backend=iwd` (`:3-4`).
- `etc/pacman.d/mirrorlist`: Fastly/geo/rackspace/kernel.org/leaseweb (`:5-9`), "copied verbatim into the target" (`:1`).
- `etc/motd`: placeholders filled by `build.sh:198-202`.
- `root/.bash_profile` sources `root/.zlogin` (`:5`); `.zlogin` runs `/usr/local/bin/ryoku-installer-session` only on `/dev/tty1` (`:5-7`).
- `usr/local/bin/ryoku-install`: `exec /usr/local/lib/ryoku/backend/ryoku-install "$@"` (`:7`).
- `usr/local/bin/ryoku-installer-session`: exports `RYOKU_REPO=/usr/share/ryoku`, `RYOKU_BACKEND`, `COLORTERM`, `WLR_RENDERER=pixman`, `WLR_RENDERER_ALLOW_SOFTWARE=1`, `XCURSOR_THEME=Bibata-Modern-Ice` (`:12-21`); waits up to 5 s for a KMS connector (`:77-84,196`); sizes the foot font from the panel (`:44-56,92-98`); runs `cage -m last -- foot ... -e ryoku-tui` with xkb env from `/tmp/ryoku-xkb` (`:155-183`), retries 3x then falls back to the VT with a `setfont` sized from `/sys/class/graphics/fb0/virtual_size` (`:64-71,105-131,198-220`); prints a recovery notice (`:136-148`).

**Arch couplings:**
- `getty@tty1.service.d/autologin.conf:3` hardcodes `/usr/bin/agetty`; Debian ships `/usr/sbin/agetty` only (util-linux filelist). Prior art: `debian13-stripped/build-rootfs.sh:550-553` uses `/sbin/agetty`.
- `pacman-init.service`, `etc-pacman.d-gnupg.mount`, `etc/pacman.d/mirrorlist`: pacman-only.
- `etc/locale.conf`, `etc/vconsole.conf`: Debian's canonical files are `/etc/default/locale` and `/etc/default/keyboard` (+ `/etc/default/console-setup`).
- `ryoku-installer-session:107` font list `solar24x32`, `latarcyrheb-sun32`, `iso01-12x22`, `default8x16` are upstream-kbd font names. Debian: only `default8x16` exists (console-data); there is no 24x32 font; nearest are `Lat15-Terminus32x16` (16x32) and `Lat15-Terminus24x12` / `Lat15-Terminus22x11` (console-setup-linux).
- `ryoku-installer-session:100-104` comment "fonts kbd already ships": false on Debian (kbd has no consolefonts).

**Dependencies:** see "Live package set" (util-linux, console-setup-linux, console-data, cage, foot, network-manager, iwd, systemd-timesyncd 257.13-1~deb13u1).

**As-is on Debian:** PARTIAL, most files are distro-neutral; agetty path, pacman units and console fonts break.

**Port steps:**
1. `getty@tty1.service.d/autologin.conf`: `ExecStart=-/usr/bin/agetty ...` -> `ExecStart=-/sbin/agetty --noreset --noclear --autologin root - ${TERM}`.
2. Delete `pacman-init.service`, `etc-pacman.d-gnupg.mount`, the `multi-user.target.wants/pacman-init.service` symlink and `etc/pacman.d/mirrorlist`; add `etc/apt/sources.list.d/debian.sources` (deb822, `URIs: http://deb.debian.org/debian`, suites `trixie trixie-updates`, plus a `trixie-security` stanza, components `main contrib non-free non-free-firmware`, `Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg`) and the Ryoku repo `.sources` with its keyring.
3. `etc/locale.conf` -> `etc/default/locale` (`LANG=C.UTF-8`; C.UTF-8 is built into Debian glibc, no `locale-gen`).
4. Keep `etc/vconsole.conf` (systemd-vconsole-setup reads it) and add `etc/default/keyboard` (`XKBLAYOUT="us"`, `XKBMODEL="pc105"`).
5. `etc/shadow` cannot be overlaid (Debian generates it at bootstrap): drop the file, run `passwd -d root` in a chroot hook.
6. `ryoku-installer-session:107`: `"solar24x32 24 32" "latarcyrheb-sun32 16 32" "iso01-12x22 12 22"` -> `"Lat15-Terminus32x16 16 32" "Lat15-Terminus24x12 12 24" "Lat15-Terminus22x11 11 22"`; `default8x16` stays (console-data). Or package upstream kbd fonts into a deb and keep the script as-is.
7. Remove `/etc/update-motd.d/10-uname` (Debian prints uname above `/etc/motd`).
8. `getty.target.wants/serial-getty@ttyS0.service`, `sysinit.target.wants/systemd-timesyncd.service`, `NetworkManager.service` symlinks, `systemd-firstboot.service` mask, `wifi-backend.conf`, `.bash_profile`, `.zlogin`, `ryoku-install`, `motd`, `hostname`, `localtime`: unchanged.

**Complexity:** Low.

**Issues / risks:**
- Debian's `network-manager` defaults to wpa_supplicant; the iwd backend file is honoured but `iwd` must be installed and `wpa_supplicant.service` should not be enabled concurrently (Debian enables `wpa_supplicant.service` from its postinst).
- `localectl list-keymaps` (used by the TUI keyboard step per `packages.x86_64:52-53`) returns nothing on Debian unless `console-data` provides `/usr/share/keymaps`.

---

### Live boot menus and live initramfs (`installation/iso/syslinux/`, `efiboot/`, `grub/loopback.cfg`, `airootfs/etc/mkinitcpio.conf.d/archiso.conf`, `airootfs/etc/mkinitcpio.d/linux.preset`)

**What it does:** three entries on every path, default first: normal, safe
graphics (`nomodeset`), copy to RAM (`copytoram`) (`syslinux/archiso_sys-linux.cfg:1-29`,
`efiboot/loader/entries/01..03-*.conf`, `grub/loopback.cfg:28-44`). Common
cmdline: `archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID%
cow_spacesize=1G quiet loglevel=3 console=ttyS0,115200 console=tty0`
(`efiboot/loader/entries/01-ryoku-linux.conf:5`). systemd-boot `timeout 5`,
`console-mode max` (`efiboot/loader/loader.conf:1-3`); syslinux vesamenu with
`SERIAL 0 115200`, `TIMEOUT 50`, reboot/poweroff entries
(`archiso_head.cfg:1-26`, `archiso_sys.cfg:3-4`, `archiso_tail.cfg:1-13`).
`loopback.cfg` is the GRUB-loopback/Ventoy-GRUB2-mode path: finds the carrier
with `search --file "${iso_path}"` and boots with `img_dev=UUID=... img_loop="${iso_path}"`
(`grub/loopback.cfg:19-22,30`). The live initramfs uses
`HOOKS=(base udev microcode modconf kms memdisk archiso archiso_loop_mnt block filesystems keyboard)`,
`COMPRESSION="xz"` `-9e` (`archiso.conf:6-8`); the PXE hooks were removed
(`archiso.conf:1-5`). `linux.preset` builds only the `archiso` preset
(`linux.preset:3-8`).

**Arch couplings:**
- archiso cmdline keys `archisobasedir`, `archisosearchuuid`, `cow_spacesize`, `copytoram`, `img_dev`, `img_loop` (all files above).
- `%INSTALL_DIR%`, `%ARCH%`, `%ARCHISO_UUID%` substituted by mkarchiso (`mkarchiso:520,641,723`).
- mkinitcpio hooks `archiso`, `archiso_loop_mnt`, `memdisk` (`archiso.conf:6`).
- Runtime path `/run/archiso/bootmnt` consumed by the TUI disk filter (`installation/tui/system.go:257-260`).

**Dependencies:** live-boot, live-boot-initramfs-tools, initramfs-tools, isolinux, syslinux-common, grub-efi-amd64-signed, shim-signed (versions in "Live package set").

**As-is on Debian:** NO.

**Port steps:**
1. Parameter map (live-boot `components/9990-cmdline-old` parses these):

   | archiso | live-boot | Notes |
   |---|---|---|
   | `archisobasedir=arch` | `boot=live` (+ `live-media-path=/live`, the default) | squashfs at `/live/filesystem.squashfs` |
   | `archisosearchuuid=<uuid>` | none, or `/conf/uuid.conf` in initrd matched against `/.disk/live-uuid*` on the medium (`components/9990-misc-helpers.sh:18-34`) | without `uuid.conf` live-boot takes the first medium carrying `/live/filesystem.squashfs` |
   | `cow_spacesize=1G` | `overlay-size=1G` | default is `50%` of RAM (`components/9990-overlay.sh:306,311`) vs archiso's 256 MiB |
   | `copytoram` | `toram` | `toram` copies the WHOLE medium to tmpfs and moves it onto `/run/live/medium` (`components/9990-toram-todisk.sh:8-10,77-84`); `toram=filesystem.squashfs` copies only the squashfs |
   | `img_dev=UUID=.. img_loop=<path>` | `findiso=<path>` | loopback.cfg passes `findiso=${iso_path}` |
   | `nomodeset`, `console=`, `quiet`, `loglevel=3` | same | |
2. `boot/grub/grub.cfg` (UEFI path; signed GRUB sources it via `/.disk/info`):
   ```
   set default=0
   set timeout=5
   menuentry "Ryoku Linux installer (x86_64, UEFI)" {
     linux /live/vmlinuz boot=live overlay-size=1G quiet loglevel=3 console=ttyS0,115200 console=tty0
     initrd /live/initrd.img
   }
   menuentry "Ryoku Linux installer (x86_64, UEFI) (safe graphics)" {
     linux /live/vmlinuz boot=live overlay-size=1G quiet loglevel=3 console=ttyS0,115200 console=tty0 nomodeset
     initrd /live/initrd.img
   }
   menuentry "Ryoku Linux installer (x86_64, UEFI) (copy to RAM, slow USB)" {
     linux /live/vmlinuz boot=live overlay-size=1G quiet loglevel=3 console=ttyS0,115200 console=tty0 toram
     initrd /live/initrd.img
   }
   ```
3. `boot/grub/loopback.cfg`: same three entries with `findiso=${iso_path}` added; keep `timeout=15` (`grub/loopback.cfg:24-26`).
4. `isolinux/isolinux.cfg`: copy `archiso_head.cfg`, `archiso_tail.cfg` verbatim; in `archiso_sys-linux.cfg` replace `LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux` -> `LINUX /live/vmlinuz`, `INITRD .../initramfs-linux.img` -> `INITRD /live/initrd.img`, `APPEND archisobasedir=... cow_spacesize=1G` -> `APPEND boot=live overlay-size=1G`, `copytoram` -> `toram`. Debian module paths: `/usr/lib/syslinux/modules/bios/vesamenu.c32`, `reboot.c32`, `poweroff.c32`.
5. Live initramfs: delete `archiso.conf` and `linux.preset`; the live root gets `live-boot` + `live-boot-initramfs-tools`, and `/etc/initramfs-tools/conf.d/ryoku-live.conf` with `COMPRESS=xz` and `COMPRESSLEVEL=9` (mirrors `archiso.conf:7-8`; Debian default is `COMPRESS=zstd`, `conf/initramfs.conf`). Hook map: `base udev` -> initramfs-tools core + udev hook; `microcode` -> amd64-microcode/intel-microcode initramfs hooks; `modconf` -> automatic (`mkinitramfs:432-433` copies `/etc/modprobe.d`); `kms` -> not needed before switch-root; `memdisk` -> live-boot `components/3050-memdisk.sh`; `archiso` -> live-boot; `archiso_loop_mnt` -> live-boot `findiso=`; `block filesystems keyboard` -> `MODULES=most` (default).
6. TUI (`installation/tui/system.go:257-260`): `/run/archiso` -> `/run/live/medium`; `findmnt -nro SOURCE /run/archiso/bootmnt` -> `findmnt -nro SOURCE /run/live/medium`. After `toram` the source of `/run/live/medium` is `tmpfs`, so the function must treat a non-block source as "nothing to filter" (archiso unmounts bootmnt after copytoram, so today the lookup simply fails).

**Complexity:** Medium.

**Issues / risks:**
- `toram` copies the whole ISO including the multi-GB offline repo (it lives inside the squashfs today, `build.sh:238`); archiso's `copytoram` copies `airootfs.sfs`, which contains the same repo. RAM need is the same order in both; `toram` also refuses when `MemFree+Cached` is below the medium size (`9990-toram-todisk.sh:23-45`).
- Ventoy normal mode presents the ISO as a device-mapper node; live-boot scans block devices for `/live/filesystem.squashfs`, so it does not depend on the ISO label (archiso does, `README.md:132-140`).
- `console-mode max` (systemd-boot) has a GRUB analogue `gfxmode=auto` + `terminal_output gfxterm` only with font/gfx modules present in Debian's signed image.

---

### Offline package closure (`installation/iso/offline-repo.sh`)

**What it does:** bakes every package a target can reach into a file:// `[offline]`
pacman repo inside the ISO (`offline-repo.sh:2-11`). Top-level list: `base.packages`,
`dev.packages`, `cachyos.packages` (cachyos variant), all `[amd] [intel] [nvidia] [vm]`
sections of `hardware.packages`, GPU-driver packages, and the Ryoku desktop set
(`:51-81`). Throwaway `pacman.conf` with `SigLevel = Never` against core/extra/multilib/[ryoku]
(+`[cachyos]`) (`:90-120`); validates names (`:138-153`); resolves (`:155-161`);
downloads into a persistent cache (`:170-171`); fetches each conflicting NVIDIA
module package separately, `nvidia-open`/`nvidia-open-dkms` required (`:181-191`);
builds the AUR set and legacy NVIDIA branches with `makepkg` as an unprivileged
user (`:206-362`); verifies archive integrity with `bsdtar -tf` (`:373-391`);
assembles and indexes with `repo-add` (`:395-432`); fails on missing required
packages (`:412-425`); verifies the exact pacstrap set resolves from ONLY the baked
repo and that no two packages own the same file (`:443-527`); prunes superseded
files (`:536-551`).

**Arch couplings:** `pacman -Sy/-Si/-Ss/-Sp/-Sw/-Qlp` (`:129-171,501`), `repo-add` (`:432,525`),
`bsdtar .PKGINFO` (`:330`), `makepkg -s` + AUR RPC + `aur.archlinux.org` clones (`:252-353`),
`*.pkg.tar.zst` naming (`:217-226,377,398`), `[multilib]` (`:104-105`), `x86_64_v3` arch (`:448`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| pacman (repo-add) | index (`:432`) | apt-utils (`apt-ftparchive`) or dpkg-dev (`dpkg-scanpackages`) or reprepro | apt-utils 3.0.3; dpkg-dev 1.22.22; reprepro 5.4.6+really5.3.2-1+deb13u1 | - | 3.3.3; 1.23.11 | 3.3.3; 1.23.11 | 3.2.0; 1.23.7ubuntu1 | - |
| pacman -Sw | download closure (`:171`) | apt-get (`install --download-only -o Dir::Cache::archives=` in a target-suite chroot, or `--print-uris`) | apt 3.0.3 | | | | | - |
| makepkg/base-devel | AUR builds (`:248-354`) | dpkg-buildpackage + build-essential (debs from the Ryoku packaging) | | | | | | packages agent |

**As-is on Debian:** NO.

**Port steps:**
1. Resolve and download in a throwaway chroot of the TARGET suite (host apt state untouched, as `:86-89` does for pacman): `mmdebstrap --variant=apt --skip=cleanup ... "$work/chroot"`, then `chroot "$work/chroot" apt-get install --download-only -y -o Dir::Cache::archives=/cache <list>` for the main set. Prior art: `debian13-stripped/build-rootfs.sh:131-220` (software store) and `:412-463` (per-variant NVIDIA stores, each resolved separately because the variants conflict, matching `offline-repo.sh:173-191`).
2. Index: `cd $DEST && apt-ftparchive packages . > Packages && gzip -9k Packages && apt-ftparchive release . > Release` (prior art `Debian13-Hyprland/scripts/10-cache.sh:323-334`). Target side: `deb [trusted=yes] file:/usr/share/ryoku/offline/repo ./` during install only (same trust model as `SigLevel = Never`, `:87-89`).
3. Integrity (`:373-391`): `dpkg-deb --info "$f" >/dev/null && dpkg-deb --contents "$f" >/dev/null` replaces `bsdtar -tf`.
4. Closure verification (`:443-511`): `apt-get install -s --no-remove <pacstrap set>` against a sources.list naming only the offline repo (prior art `debian13-stripped/build-rootfs.sh:460-463`); file-conflict scan: `dpkg-deb -c` per deb, collect paths owned by >1 package, ignore pairs related by `Replaces:`.
5. AUR set (`:248-362`): replaced by debs built from the Ryoku packaging repo (packages agent); the legacy-NVIDIA note (`:193-209`) maps to Debian's `nvidia-tesla-535-*`/`nvidia-legacy-*` packages or NVIDIA's CUDA repo (hardware agent).
6. Pruning (`:536-551`): only the newest version per package name is kept by `apt-ftparchive`'s output if the cache is pruned first (`apt-get autoclean`-style by name+version sort).

**Complexity:** High (logic rewrite; the shape carries over).

**Issues / risks:** apt has no `pacman -Sp --print-format`; dependency alternatives (`a | b`) and virtual packages resolve differently from pacman providers, so "validate each name" (`:138-153`) must use `apt-cache policy`/`apt-cache showpkg`.

---

### ISO CI (`.github/workflows/build-iso.yml`, `build-iso-cachyos.yml`, `build-iso-reusable.yml`)

**What it does:** `build-iso.yml` (tags `v*`, variant plain) and
`build-iso-cachyos.yml` (tags `cachyos-v*`) call the reusable builder
(`build-iso.yml:24-40`, `build-iso-cachyos.yml:67-83`). The reusable job runs
`installation/tests/iso-preflight.sh` on ubuntu-latest (`build-iso-reusable.yml:37-75`),
then in `docker run --privileged archlinux:latest` installs
`archiso git go base-devel cmake ninja qt6-base qt6-declarative qt6-shadertools qt6-multimedia hyprcursor xcur2png`
(`:176-199`), builds `ryoku-cursors` locally with `makepkg --nodeps` because the
public repo 403s datacenter IPs (`:203-217`), runs `iso-stage-check.sh` then
`build.sh` (`:223-224`). Afterwards: rename to
`ryoku-<date>-r<run>-<sha>-x86_64-<ref>[-cachyos].iso` (`:237-253`), mount the
squashfs and verify the payload stamp/variant/sha (`:255-317`), Trivy rootfs scan
(`:319-356`), GPG detached signature + public key export (`:377-403`),
`bin/ryoku-iso-manifest` (`:405-411`), rclone to Cloudflare R2 (`:413-454`),
artifacts and Discord (`:456-539`).

**Arch couplings:** `archlinux:latest` + `pacman -Sy archlinux-keyring` + `pacman -Su ... archiso` (`:187-199`); `makepkg` for ryoku-cursors (`:210-216`); Trivy `skip-dirs: var/cache/pacman/pkg` (`:334,355`); squashfs search glob `*airootfs*.sfs` (`:272-274`).

**Dependencies:** Debian container image `debian:trixie` with live-build or mmdebstrap, squashfs-tools, xorriso, dosfstools, mtools, isolinux, syslinux-common, grub-efi-amd64-signed, shim-signed, golang-go, cmake, ninja-build, Qt6 `-dev` packages, git, curl, devscripts/dpkg-dev (for the cursor deb).

**As-is on Debian:** NO.

**Port steps:**
1. `archlinux:latest` -> `debian:trixie` (or `ubuntu:26.04`); replace `:192-199` with `apt-get update && apt-get install -y --no-install-recommends <list above>`.
2. Replace the `makepkg` ryoku-cursors build (`:210-217`) with `dpkg-buildpackage -b -uc -us` of the cursors deb and `apt-ftparchive` index for the local repo.
3. Trivy `skip-dirs`: `var/cache/pacman/pkg` -> `var/cache/apt/archives`; squashfs glob `*airootfs*.sfs` -> `live/filesystem.squashfs` (`:272-274`).
4. Delete the dead `SOURCE_DATE_EPOCH="$(date -u +%s)"` (`:172-180`) or keep build.sh as the single source.

**Complexity:** Medium.

---

### Limine configuration (`system/boot/limine/limine.conf`, `system/boot/limine/default.conf`, `installation/backend/lib/bootloader.sh`)

**What it does:**
- `limine.conf` (deployed to `/boot/limine.conf`, the ESP root, `bootloader.sh:354-389`): `timeout: 3`, `default_entry: 1`, `remember_last_entry: yes`, `interface_branding: Ryoku Bootloader`, `interface_branding_color`/`interface_help_color: C75D2B`, `hash_mismatch_panic: no`, `term_background`/`backdrop: 060607`, `term_palette`, `term_palette_bright`, `term_foreground(_bright)`, `term_background_bright` (`limine.conf:13-45`), and a flat fallback entry `/Ryoku Linux` `protocol: efi` `path: boot():/EFI/Linux/ryoku_linux.efi` (`:51-53`). The installer strips that entry and appends its own `protocol: linux` entry with `kernel_path: boot():/vmlinuz-<kver>`, `cmdline: $CMDLINE quiet splash`, `module_path: boot():/initramfs-<kver>.img` when the hook is absent (`bootloader.sh:364-388`).
- `default.conf` (-> `/etc/default/limine`, `bootloader.sh:330-344`): `TARGET_OS_NAME="Ryoku Linux"`, `ESP_PATH="/boot"`, `KERNEL_CMDLINE[default]+="@@CMDLINE@@"` plus the boot-look suffix, `ENABLE_UKI=yes`, `CUSTOM_UKI_NAME="ryoku"`, `ENABLE_LIMINE_FALLBACK=yes`, `FIND_BOOTLOADERS=yes`, `BOOT_ORDER="*, *fallback, Snapshots"`, `MAX_SNAPSHOT_ENTRIES=10`, `SNAPSHOT_FORMAT_CHOICE=5` (`default.conf:10-48`).
- Entries after the hook runs (limine-entry-tool 1.37+): `/Ryoku Linux` becomes a directory with `//<kernel>` UKI children and `//Snapshots`; finalize strips the placeholder's boot stanza and repoints `default_entry` at `Ryoku Linux/<kernel>` where `<kernel>` is `linux` or `linux-cachyos` (`bootloader.sh:69-92,161-234`); `/etc/ryoku/default-kernel` records it (`bootloader.sh:358-363`).
- Install commands (UEFI only; preflight refuses BIOS, `preflight.sh:43-44`; TUI blocks BIOS, `tui/system.go:795`): copy `/usr/share/limine/BOOTX64.EFI` to `EFI/limine/limine_x64.efi` and `EFI/BOOT/BOOTX64.EFI`, then `efibootmgr --create --disk $RYOKU_DISK --part N --label Ryoku --loader '\EFI\limine\limine_x64.efi' --unicode` and `--bootnext`, both best-effort (`bootloader.sh:468-501`). Removes shadowing configs (`bootloader.sh:395-403`).
- Alongside topology: stage-1 static hop `/efi/EFI/ryoku/{BOOTX64.EFI,limine.conf}` with `efi_chainload` to `fslabel(RYOKUBOOT):/ryoku-limine.efi`, stage-2 `/boot/ryoku-limine.efi` + `/boot/limine.conf` on an XBOOTLDR FAT (`bootloader.sh:503-638`), `/etc/kernel/cmdline` seeded (`:705-709`), `/efi` fstab line (`:717-722`), and a pacman hook that refreshes both stage binaries on every `limine` upgrade (`:729-743`).
- Snapshot entries: hung under `TARGET_OS_NAME` by limine-snapper-sync (`default.conf:5-10,43-48`).
- Secure Boot / enrollment: none configured. `ENABLE_ENROLL_LIMINE_CONFIG` is not set; `hash_mismatch_panic: no` (`limine.conf:32`); the installer refuses SB on (`preflight.sh:46-52`).

**Arch couplings:**
- `ESP_PATH="/boot"` (`default.conf:12`) with the ESP mounted at `/mnt/boot` (`filesystem.sh:59`): kernels and initramfs live on FAT because Arch's kernel packages install to `/usr/lib/modules/<ver>/vmlinuz` and mkinitcpio copies into `/boot`. Debian `linux-image-*` packages unpack `/boot/vmlinuz-<ver>` themselves, and initramfs-tools writes `/boot/initrd.img-<ver>`.
- Kernel names `linux`/`linux-cachyos` (`bootloader.sh:163,358,648`) are Arch pkgbase names.
- `module_path: boot():/initramfs-$kver.img` / `kernel_path: boot():/vmlinuz-$kver` (`bootloader.sh:383-385,661-663`): Arch file names. Debian: `/boot/vmlinuz-<uname-r>`, `/boot/initrd.img-<uname-r>`.
- `arch-chroot` (`bootloader.sh:41,48,53,240,247,322`), `pacman -Q` (`:247`), `/usr/bin/mkinitcpio -P` (`:53,522`), `limine-mkinitcpio` (`:48`).
- `/etc/pacman.d/hooks/ryoku-limine-stage.hook` (`bootloader.sh:730-743`).
- `systemctl enable sddm.service ... rtkit-daemon.service power-profiles-daemon.service` (`bootloader.sh:41`): unit names identical on Debian (`sddm`, `NetworkManager`, `bluetooth`, `rtkit-daemon`, `power-profiles-daemon`).

**Dependencies:** limine (build), efibootmgr 18-2+b1, dosfstools, util-linux (`blkid`, `findmnt`, `lsblk`).

**As-is on Debian:** PARTIAL. The limine.conf globals and the installer's file surgery are distro-neutral; the `/boot`-on-FAT layout, kernel file names and kernel names are not.

**Port steps:**
1. Keep `limine.conf` globals verbatim (Limine is distro-neutral).
2. Choose the ESP layout (Questions). For layout "ESP at `/efi`": `filesystem.sh:59` `mount "$ESP_DEV" /mnt/boot` -> `mount "$ESP_DEV" /mnt/efi` (and `/mnt/boot` stays on `@`); `default.conf:12` `ESP_PATH="/boot"` -> `ESP_PATH="/efi"`; every `/mnt/boot/limine.conf`, `/mnt/boot/EFI/...` in `bootloader.sh` -> `/mnt/efi/...`; doctor constants `limineESPConf = "/boot/limine.conf"` etc. (`ryoku/cli/internal/doctor/reconcile_limine.go:50-53`), `bootguard.go:37`, `ryoku-boot-apply:10` follow.
3. Offline seed entry (`bootloader.sh:379-386`): `kernel_path: boot():/vmlinuz-$kver` -> the Debian file the hook will also manage, e.g. `boot():/<machine-id>/<name>/vmlinuz-<ver>` as limine-entry-tool lays it (`LimineManager.java:196-201,288-293`), or a UKI path `boot():/EFI/Linux/ryoku_<name>.efi`.
4. `chroot_has_pkg` (`bootloader.sh:245-248`): `arch-chroot /mnt pacman -Q "$1"` -> `chroot /mnt dpkg-query -W -f='${Status}' "$1" | grep -q 'install ok installed'`.
5. `/usr/bin/mkinitcpio -P` (`bootloader.sh:53,522`) -> `update-initramfs -c -k all` (or `-u`); `limine-mkinitcpio` (`:48`) -> the Debian hook entry point (see next sections).
6. Alongside stage refresh (`bootloader.sh:729-743`): write `/etc/apt/apt.conf.d/99ryoku-limine-stage` with `DPkg::Post-Invoke { "src=/usr/share/limine/BOOTX64.EFI; [ -f $src ] || exit 0; [ -f /boot/ryoku-limine.efi ] && cmp -s $src /boot/ryoku-limine.efi || cp -f $src /boot/ryoku-limine.efi; [ -f /efi/EFI/ryoku/BOOTX64.EFI ] && cmp -s $src /efi/EFI/ryoku/BOOTX64.EFI || cp -f $src /efi/EFI/ryoku/BOOTX64.EFI; true"; };`, or ship it as a `interest-noawait /usr/share/limine/BOOTX64.EFI` dpkg file trigger in the Ryoku package.
7. Kernel name mapping for `default_entry` (`bootloader.sh:161-186`, `/etc/ryoku/default-kernel`): depends on the naming decision (Questions).

**Complexity:** Medium.

**Issues / risks:**
- dpkg writing `/boot/vmlinuz-*` onto vfat (if `/boot` stays the ESP): vfat has no symlinks, hardlinks, ownership or modes; `linux-image` postinst's `/vmlinuz` symlinks go to `/` by default (`/etc/kernel-img.conf link_in_boot` unset) so they land on btrfs, but any dpkg backup hardlink of an existing `/boot` file fails on vfat. Debian kernel package names are per-version (e.g. `linux-image-6.12.107+deb13-amd64`) so `/boot` files are not normally overwritten in place. Not tested here.
- With `/boot` = ESP, initramfs-tools writes `initrd.img-<ver>` to the ESP and limine-entry-tool copies it again into `ESP/<machine-id>/<name>/` or into a UKI: two copies per kernel on a 2 GiB FAT (`reconcile_boot_space.go:1-20` already documents the space wall at one copy).
- Limine reads only FAT/ISO9660; whatever layout is chosen, the booted kernel/UKI must be on FAT.

**Questions for the human:**
- ESP layout: (a) keep ESP at `/boot` (Arch parity, no path changes in Ryoku code; dpkg writes kernels onto FAT; double copies on the ESP); (b) ESP at `/efi`, `/boot` on btrfs `@` (Debian-native, kernels inside snapshots, limine-entry-tool copies only what boots; changes ~40 hardcoded `/boot/...` paths in installer, doctor, boot guard and ryoku-boot-apply).
- Kernel entry naming: (a) one entry per Debian kernel version (`//6.12.107+deb13-amd64`), Debian-native, `default_entry` must be repointed to the newest version on every kernel install; (b) stable names `linux` (newest) + `linux-previous` (like Debian's `/vmlinuz`, `/vmlinuz.old`), keeps Ryoku's `linux`/`linux-cachyos` logic, menu shows at most two stock kernels.

---

### Limine binary (`limine`, consumed at `bootloader.sh:471,474,547,582,591`)

**What it does:** the bootloader. Ryoku copies `/usr/share/limine/BOOTX64.EFI`; the
`limine` host tool is used by limine-entry-tool (`limine enroll-config`,
`limine --version`) (`limine-common-functions:336,350`, upstream).

**Arch couplings:** Arch `limine` 12.9.3-1 builds from git with `./bootstrap; ./configure --prefix=/usr --enable-all; make` (Arch PKGBUILD, gitlab.archlinux.org packaging), makedepends `git nasm mtools llvm lld clang`.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| limine | UEFI loader (`bootloader.sh:471`) | none (no Debian/Ubuntu package; sources.debian.org search and wnpp.debian.net returned nothing) | - | - | - | - | - | >= 12 (`limine.conf:29`: "Limine 12+ wants literal RRGGBB"); upstream latest v12.9.3 (2026-10-06) |
| nasm, mtools, clang/llvm/lld | build | nasm, mtools, clang, llvm, lld | 2.16.03-1; 4.0.48-1; 1:19.0-63 | - | 3.01-1+b1; 4.0.49-1+b1; 1:21.1.8-74 | same | 3.01-1; 4.0.49-1; 1:21.1.6-71 | gcc also supported (INSTALL.md) |

**As-is on Debian:** NO (absent).

**Port steps:**
1. Source: `https://github.com/limine-bootloader/limine/releases/download/v12.9.3/limine-12.9.3.tar.xz` (+ `.sig`; Arch verifies keys `05D29860D0A0668AAEFB9D691F3C021BECA23821`, `6C222EA6B2BD216AA406516AC868F0B6DE38409D`). The release tarball already contains `configure` (no `./bootstrap`, no network).
2. Build deps: `build-essential nasm mtools clang llvm lld` (or gcc only).
3. `./configure --prefix=/usr --enable-all && make && make DESTDIR=debian/limine install` -> `/usr/bin/limine`, `/usr/share/limine/{BOOTX64.EFI,BOOTIA32.EFI,limine-bios.sys,limine-bios-cd.bin,limine-uefi-cd.bin,limine-bios-pxe.bin}`, license `COPYING` (BSD-2-Clause).
4. Alternative without a compiler toolchain for the EFI side: `limine-binary.tar.xz` from the same release carries prebuilt `BOOTX64.EFI`, `limine-bios.sys`, `limine-bios-cd.bin`, `limine-uefi-cd.bin` and `limine.c` + a 15-line Makefile for the host tool (`cc -std=c99 -D_FILE_OFFSET_BITS=64 limine.c -o limine`). The `-binary` git branches stop at `v11.x-binary` on both GitHub and Codeberg; v12 binaries exist only as the release asset.
5. Package as `limine_12.9.3-1_amd64.deb` in the Ryoku apt repo; add a dpkg trigger file `interest-noawait /usr/share/limine/BOOTX64.EFI` in the limine-entry-tool deb whose postinst `triggered)` branch runs `limine-install` (replaces `80-limine-efi-deploy.hook`).
6. BIOS reference (unused by Ryoku): `limine bios-install /dev/sdX` + `limine-bios.sys` copied to `/boot` or `/limine` (USAGE.md "BIOS/MBR").

**Complexity:** Low.

---

### limine-entry-tool + limine-mkinitcpio-hook (`release/packages/limine-mkinitcpio-hook/PKGBUILD`)

**What it does:** Ryoku vendors upstream `gitlab.com/Zesko/limine-entry-tool`
tag 1.37.1 (`PKGBUILD:10-13,38`; upstream latest 1.40.0) and ships the
`limine-entry-tool` + `limine-mkinitcpio-hook` trees from `install/arch-linux/`
plus the GraalVM native binary at `/usr/lib/limine/limine-entry-tool`, and
symlinks `limine-reset-enroll` / `limine-enroll-config` into
`/etc/boot/hooks/{pre,post}.d` (`PKGBUILD:84-102`). Build: vendored GraalVM CE
JDK 25.0.3 tarball + vendored Gradle 9.6.1 + offline plugin repo
`release/gradle-offline/repo`, `gradle clean nativeCompile` with
`NATIVE_IMAGE_OPTIONS="-march=compatibility --future-defaults=all"`
(`PKGBUILD:18-40,73-82`).

Upstream behaviour to replicate (limine-entry-tool 1.37.1, `install/arch-linux/`):
- Config load order: `/usr/share/limine-entry-tool.d/*.conf` < `/etc/limine-entry-tool.conf` < `/etc/limine-entry-tool.d/*.conf` < `/etc/default/limine`; `ESP_PATH` autodetected among `/efi /boot /boot/efi /limine` (first vfat mount) when unset (`usr/lib/limine/limine-common-functions:77-139`).
- `initialize_header`: ESP must be a mounted vfat; machine-id (generated with `uuidgen` if empty); `BINARY_SOURCE_PATH=/usr/share/limine/BOOTX64.EFI`, target `ESP/EFI/limine/limine_x64.efi`, fallback `ESP/EFI/BOOT/BOOTX64.EFI`, config `ESP/limine.conf` (`limine-common-functions:379-401`).
- Hooks: every executable in `/etc/boot/hooks/pre.d` / `post.d`, exit >= 100 fatal (`limine-common-functions:360-376`).
- `90-mkinitcpio-install.hook` triggers on `usr/lib/initcpio/*`, `usr/lib/firmware/*`, `usr/lib/modules/*/extramodules/`, `usr/src/*/dkms.conf`, `usr/lib/systemd/systemd`, `usr/bin/cryptsetup`, `usr/bin/lvm` (any op), `usr/lib/modules/*/pkgbase` (install/upgrade), and the `mkinitcpio` package; runs `limine-mkinitcpio-install` with targets on stdin (`etc/pacman.d/hooks/90-mkinitcpio-install.hook:1-31`).
- `limine-mkinitcpio-install`: maps targets to `/usr/lib/modules/<ver>/pkgbase` (non-module target = rebuild all) (`:55-75`); skips kernels whose pkgbase file `pacman -Qqo` does not own (`:244`); kernel name = pkgbase content with spaces removed (`:78-99`); UKI path `ESP/EFI/Linux/<CUSTOM_UKI_NAME or machine-id>_<name>.efi` (`:41-52,95-97`); when `ENABLE_UKI=yes` and UEFI: cmdline from `limine-entry-tool --get-cmdline <name>` unless sbctl is set up AND snapper/btrfs is in use (then no embedded cmdline so snapshot entries can pass `rootflags=`) (`:102-117`), `mkinitcpio --kernel <ver> --cmdline <file>|--no-cmdline --uki <tmp>` (`:120-134`), `limine-entry-tool --add-uki <name> <file> --comment "Kernel version: <ver>"` (`:147-151`); fallback image with `-S autodetect` when `MKINITCPIO_FALLBACK` is `yes` or the kernel name (`:196-202`); otherwise plain `--generate` initramfs + `limine-entry-tool --add-kernel <name> <initramfs> <modules>/vmlinuz` (`:136-144,208-236`); wrapped in a `flock` on `/run/lock/boot-partition.lock` and pre/post hooks (`:255-278`).
- Removal: `60-limine-mkinitcpio-remove-pre.hook` records the pkgbase names of kernels being removed into `/var/lib/limine/removed_kernels.list`; `90-...-remove-post.hook` calls `limine-entry-tool --remove-all <name> <name>-fallback` for names no longer owned (`limine-mkinitcpio-remove:15-74`).
- `80-limine-efi-deploy.hook`: on `limine`/`limine-mkinitcpio-hook` install/upgrade runs `limine-install` (copy/update `limine_x64.efi`, fallback, NVRAM registration via `efibootmgr` with dedup by partition UUID + path, `FIND_BOOTLOADERS` adds an "EFI fallback" entry, `EFI_REGISTER=no` / `--no-efi-register`) (`usr/bin/limine-install:4-27,61-147,299-414`).
- `limine-update` = `limine-install --no-efi-register` + `limine-mkinitcpio` (`usr/bin/limine-update:16-28`); `/usr/local/bin/mkinitcpio` wrapper prompts after `-P` (`usr/local/bin/mkinitcpio:3-26`).
- Enrollment: `enroll_config` restores the backup binary, `limine enroll-config <bin> <b2sum of limine.conf>` when `ENABLE_ENROLL_LIMINE_CONFIG=yes`, then `sbctl sign` if sbctl is set up (`limine-common-functions:329-357`).
- The Java binary itself only shells out to generic tools (`efibootmgr`, `findmnt`, `b2sum`, `bash`, `logger`) and reads `/etc/os-release` for the default OS name (`src/.../Utility.java:275-325,471-491`); entries carry `#<blake2b>` hashes (`LimineManager.java:325-326`).
- Upstream also ships `install/arch-linux/limine-dracut-support/` (dracut variant of the same scripts, `dracut` instead of `mkinitcpio`); Ryoku does not package it (`PKGBUILD:96-97`).

**Arch couplings:**
- pacman hooks: `etc/pacman.d/hooks/90-mkinitcpio-install.hook`, `usr/share/libalpm/hooks/{60-limine-mkinitcpio-remove-pre,80-limine-efi-deploy,90-limine-mkinitcpio-remove-post}.hook` (upstream tree copied by `PKGBUILD:96-97`).
- `/usr/lib/modules/*/pkgbase` and `pacman -Qqo` (`limine-mkinitcpio-install:55-75,244`; `limine-mkinitcpio-remove:20-29,53`).
- `/usr/bin/mkinitcpio --uki` (`limine-mkinitcpio-install:133,143`); `mkinitcpio` in `depends` (`PKGBUILD:50`).
- Ryoku masks `90-mkinitcpio-install.hook`/`60-mkinitcpio-remove.hook` and `80-limine-efi-deploy.hook` during install (`installation/backend/lib/chroot.sh:193,203`).
- Build: `makepkg`, `source_x86_64` GraalVM tarball, Arch gradle avoided on purpose (`PKGBUILD:18-24`).
- Ryoku callers: `limine-mkinitcpio` (`bootloader.sh:48`, `ryoku-boot-apply:79-80`, `reconcile_hardware.go:363-368`), `limine-update` (`bootloader.sh:49,120`, doctor), `/usr/lib/modules/*/pkgbase` (`reconcile_limine_images.go:46`, `reconcile_limine.go:970-978`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| bash grep tar | scripts (`PKGBUILD:45-48`) | bash grep tar | essential | | | | | - |
| limine | loader (`:49`) | limine (built) | - | - | - | - | - | 12 |
| mkinitcpio | image + UKI build (`:50`) | initramfs-tools + systemd-ukify + systemd-boot-efi (stub `/usr/lib/systemd/boot/efi/linuxx64.efi.stub`) + python3-pefile | 0.148.4; ukify 257.13-1~deb13u1; pefile 2024.8.26-2.1 | - | 0.151; 262-1 | 0.151; 262.1-1 | 0.151ubuntu1; 259.9-0ubuntu0.1 | - |
| efibootmgr | NVRAM (`:51`) | efibootmgr | 18-2+b1 | - | 18-4.1+b1 | same | 18-4ubuntu1 | - |
| (util-linux, coreutils) | flock/findmnt/mountpoint/uuidgen/b2sum | util-linux, uuid-runtime, coreutils | 2.41.5 | - | 2.42.4 | 2.42.4 | 2.41.3 | - |
| sbctl (opt) | signing (`:55`) | none | - | - | - | - | - | see Secure Boot |
| GraalVM CE JDK 25, Gradle 9.6.1 | native build (`:36-40,73-82`) | not in Debian (openjdk-25-jdk-headless exists, 25.0.3+9-2~deb13u1, but no `native-image`; Debian gradle is 4.4.1-22) | - | - | - | - | - | vendor both, as the PKGBUILD already does |

**As-is on Debian:** NO. The Java core and `limine-install` are distro-neutral; the hook layer is pacman-only.

**Port steps:**
1. Build the native binary on a Debian (trixie) host exactly as `PKGBUILD:64-82`: unpack `graalvm-community-jdk-25i1-25.0.3_linux-x64_bin.tar.gz`, `gradle-9.6.1-bin.zip`, run `gradle clean nativeCompile -I release/gradle-offline/offline.init.gradle -Dryoku.offline.repo=file://.../repo`. Building on trixie links the binary against glibc 2.41; a binary built in the Arch container may require a newer glibc than trixie has.
2. deb layout: `install/arch-linux/limine-entry-tool/{etc,usr}` minus `usr/share/libalpm`; `/usr/lib/limine/limine-entry-tool` (native); the two `/etc/boot/hooks` symlinks (`PKGBUILD:100-101`); `conffiles`: `/etc/limine-entry-tool.conf`. Depends: `bash, limine (>= 12), efibootmgr, initramfs-tools | dracut, systemd-ukify, systemd-boot-efi, uuid-runtime`.
3. Replace the pacman hook layer with Debian hook points (scripts below). Order matters: `/etc/kernel/postinst.d/` runs in lexical order (`dkms` < `initramfs-tools` < `zz-*`); `update-initramfs` runs `run-parts --arg=<version> --arg=<initrd> /etc/initramfs/post-update.d/` after every image write (`update-initramfs:159-161`), and the `update-initramfs` dpkg trigger (`initramfs-tools.triggers: interest-await update-initramfs`) is what firmware, cryptsetup, lvm2, dkms and udev packages activate. That one post-update hook therefore covers all seven Path triggers of `90-mkinitcpio-install.hook` plus kernel installs.
   - `/etc/initramfs/post-update.d/zz-limine` (replaces `limine-mkinitcpio-install`):
     ```bash
     #!/bin/bash
     ver=$1 initrd=$2
     source /usr/lib/limine/limine-common-functions || exit 0
     export HOOK_CALLER=zz-limine HOOK_CMDLINE="$*"
     initialize_header || exit 0
     dpkg-query -S "/boot/vmlinuz-$ver" >/dev/null 2>&1 || exit 0   # was: pacman -Qqo pkgbase
     name=$(/usr/lib/limine/kernel-name "$ver")                       # naming decision
     mutex_lock zz-limine
     run_boot_hooks pre || { mutex_unlock; exit 2; }
     tmp=$(mktemp -d /tmp/limine-deb.XXXXXX)
     if [[ ${ENABLE_UKI:-no} == yes ]] && is_uefi; then
       args=(--linux="/boot/vmlinuz-$ver" --initrd="$initrd" --uname="$ver" --os-release=@/etc/os-release)
       if ! { is_sb_installed && is_snapper_installed; }; then
         limine-entry-tool --get-cmdline "$name" --no-mutex --no-hooks | tail -n1 >"$tmp/cmdline"
         args+=(--cmdline="@$tmp/cmdline")
       fi
       ukify build "${args[@]}" --output="$tmp/$name.efi" &&
         limine-entry-tool --add-uki "$name" "$tmp/$name.efi" --comment "Kernel version: $ver" --no-mutex --no-hooks
     else
       limine-entry-tool --add-kernel "$name" "$initrd" "/boot/vmlinuz-$ver" \
         --comment "Kernel version: $ver" --no-mutex --no-hooks
     fi
     rm -rf "$tmp"
     run_boot_hooks post
     mutex_unlock
     ```
   - `/etc/kernel/postrm.d/zz-limine` (replaces both remove hooks; Debian passes the version, so no pre/post list is needed): source the functions, `initialize_header`, `mutex_lock`, `run_boot_hooks pre`, `limine-entry-tool --remove-all "$name" "$name-fallback" --quiet --no-mutex --no-hooks`, `run_boot_hooks post`, `mutex_unlock`.
   - `/usr/bin/limine-mkinitcpio` -> `/usr/bin/limine-initramfs`: `update-initramfs -u -k all` (each write fires the post-update hook). Keep a `limine-mkinitcpio` compatibility symlink or change the three Ryoku callers.
   - `/usr/bin/limine-update`: `limine-install --no-efi-register` + `limine-initramfs` (same shape as upstream `limine-update:16-28`).
   - dpkg trigger `interest-noawait /usr/share/limine/BOOTX64.EFI` -> `limine-install` (replaces `80-limine-efi-deploy.hook`).
   - Drop `/usr/local/bin/mkinitcpio` wrapper; no Debian equivalent is needed.
4. Fallback image (`MKINITCPIO_FALLBACK`): initramfs-tools has no per-invocation `-S autodetect`; a fallback requires a second run with `MODULES=most` via `mkinitramfs -c ... -o <file> <ver>` and a custom conf dir. Ryoku does not set `MKINITCPIO_FALLBACK` (`default.conf`), so nothing to port.
5. Installer chroot: the `chroot.sh:193-203` masks become: `/etc/initramfs-tools/update-initramfs.conf update_initramfs=no` during package install (initramfs-tools' own deferral switch, `update-initramfs:7`), plus an env guard (`[ -n "$RYOKU_INSTALL_CHROOT" ] && exit 0`) in `zz-limine` and in `limine-install`'s trigger, removed before the bootloader step.

**Complexity:** High (hook redesign + native-image build).

**Issues / risks:**
- Debian kernels are versioned packages and several versions coexist (`linux-image-6.12.106+deb13-amd64`, `...107...`); Arch has one kernel per pkgbase. limine-entry-tool keys entries and UKI file names by name, so the naming scheme decides whether old versions keep entries.
- `ukify` needs `systemd-boot-efi` for the stub; Arch's `mkinitcpio --uki` uses the same systemd stub (shipped in Arch's `systemd`).
- Pinned 1.37.1 is three releases behind upstream 1.40.0; the installer's file surgery depends on 1.37 serialization quirks (`bootloader.sh:60-68,204-212`, `ryoku-windows-entry:148-158`).

---

### limine-snapper-sync (`release/packages/limine-snapper-sync/PKGBUILD`, `installation/backend/lib/snapshots.sh`)

**What it does:** vendored `gitlab.com/Zesko/limine-snapper-sync` 1.31.0
(`PKGBUILD:111-112,127`; upstream latest 1.32.1), same GraalVM/Gradle build
(`PKGBUILD:117-171`), installs `install/arch-linux/{etc,usr}` + the native binary
(`PKGBUILD:173-186`). It hangs a `//Snapshots` subtree under `TARGET_OS_NAME`
(`default.conf:5-10`), keeps per-snapshot kernel copies so a snapshot boots the
kernel that matches its modules, and restores snapshots (`limine-snapper-restore`).
Upstream integration points: `limine-snapper-sync.service` (`ExecStart=limine-snapper-watcher`,
inotify on `/.snapshots`, `WantedBy=multi-user.target`); snapper plugin
`/usr/lib/snapper/plugins/10-limine-snapper-sync` (create/delete/modify-snapshot-post,
set-default-snapshot-pre); `snapper-cleanup.service.d/limine-snapper-override.conf`
(`ExecStopPost=limine-snapper-sync --no-force-save`); pacman hook
`10-limine-snapper-lock.hook` (PreTransaction on every package, waits on the
boot-partition flock); the watcher removes a stale `/var/lib/pacman/db.lck` after
a restore (`limine-snapper-watcher:74-103`). State lives in
`/var/cache/boot/<machine-id>/lss/` (`ConfigReader.java:301`).

Installer side (`snapshots.sh`): writes `/etc/snapper/configs/root` by hand
(NUMBER_LIMIT 10, no timeline) (`:35-64`), registers it in `/etc/conf.d/snapper`
(`:67-73`), `chmod 750 /.snapshots` (`:76-77`), enables `snapper-cleanup.timer`
and, if present, `limine-snapper-sync.service` (`:83-98`), prunes `/.snapshots`
from updatedb (`:102-117`). `MAX_SNAPSHOT_ENTRIES=10` matches NUMBER_LIMIT
(`default.conf:43-46`). snap-pac provides pre/post snapshots around pacman
(`base.packages:37-39`).

**Arch couplings:**
- `usr/share/libalpm/hooks/10-limine-snapper-lock.hook` + `usr/share/libalpm/scripts/limine-snapper-lock` (upstream).
- `cleanup_pacman_lock` uses `pacman-conf DBPath` (`limine-snapper-watcher:75-86`); harmless when pacman is absent (no lock file found).
- `/etc/conf.d/snapper` (`snapshots.sh:67`): Debian snapper reads `/etc/default/snapper` (snapper filelist).
- snap-pac (pacman hooks) masked during install (`chroot.sh:193`); doctor runs commands with `SNAP_PAC_SKIP=y`.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| snapper | snapshots (`PKGBUILD:136`) | snapper | 0.10.6-1.2 | - | 0.10.6-1.3+b1 | 0.10.6-1.3+b1 | 0.10.6-1.3 | generic plugins (`/usr/lib/snapper/plugins`, actions create/modify/delete-snapshot-post, set-default-snapshot-pre) exist in 0.10.6 (`snapper/Hooks.cc:46-173`); added after 0.10.4 (upstream `package/snapper.changes` 2022-12-22). Arch has 0.13.2 |
| snap-pac | pre/post around pacman (`base.packages:39`) | snapper's own `/etc/apt/apt.conf.d/80snapper` | in snapper | | | | | disable during install with `DISABLE_APT_SNAPSHOT=yes` in `/etc/default/snapper` |
| btrfs-progs | (`PKGBUILD:137`) | btrfs-progs | 6.14-1 | 7.1-1~bpo13+1 | 7.1-1 | 7.1-1 | 6.17.1-1build1 | - |
| libnotify | notifications (`PKGBUILD:138`) | libnotify-bin | 0.8.6-1 | - | 0.8.8-1+b1 | same | 0.8.8-1 | - |
| inotify-tools (opt) | watcher (`PKGBUILD:141`) | inotify-tools | 4.23.9.0-2+b1 | - | 4.25.9.0-1+b1 | same | 4.25.9.0-1 | without it the watcher exits and the snapper plugin path is used (`limine-snapper-watcher:111-114`) |
| rsync, b3sum, xxhash (opt) | restore/hash (`PKGBUILD:142-144`) | rsync, b3sum, xxhash | 3.4.1; 1.8.1-2; 0.8.3-2 | | | | | - |

**As-is on Debian:** PARTIAL. Java core, service, plugin and drop-in are distro-neutral; the pacman lock hook and snapper registration path are not.

**Port steps:**
1. Native build on trixie as for limine-entry-tool (`PKGBUILD:153-171`).
2. deb layout: `install/arch-linux/{etc,usr}` minus `usr/share/libalpm`; move `limine-snapper-lock` to `/usr/lib/limine/limine-snapper-lock`; add `/etc/apt/apt.conf.d/10limine-snapper-lock`: `DPkg::Pre-Invoke { "[ -x /usr/lib/limine/limine-snapper-lock ] && /usr/lib/limine/limine-snapper-lock || true"; };`. Depends: `bash, limine (>= 8), snapper (>= 0.10.5), btrfs-progs, libnotify-bin`; Recommends: `inotify-tools, rsync, b3sum, xxhash`. `postinst`: `deb-systemd-helper enable limine-snapper-sync.service`.
3. `snapshots.sh:67`: `write_file /mnt/etc/conf.d/snapper` -> edit `/mnt/etc/default/snapper` (`SNAPPER_CONFIGS="root"`; the file exists from the snapper package, so `sed -i 's/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS="root"/'`).
4. snap-pac replacement: install `snapper` (ships `80snapper`); remove the snap-pac mask logic.

**Complexity:** Medium.

**Issues / risks:**
- Debian's `80snapper` creates a pre/post pair on every `apt`/`dpkg` run including the installer's chroot runs; it must be off during install (`DISABLE_APT_SNAPSHOT=yes`) like the snap-pac mask today (`chroot.sh:180-193`).
- Snapshot boot needs the kernel copy on FAT per snapshot; with Debian's 2-3 retained kernel versions and `MODULES=most` initrds (no autodetect) each copy is larger than Arch's; `reconcile_boot_space.go` assumes 2 GiB fits two kernels.
- Booting a read-only snapper snapshot without an overlay: upstream ships an overlayfs initramfs hook only for mkinitcpio/dracut (`install/arch-linux/limine-mkinitcpio-hook/usr/lib/initcpio/hooks/btrfs-overlayfs`, `limine-dracut-support/usr/lib/dracut/modules.d/91btrfs-snapshot-overlay`); Ryoku's HOOKS do not include it (`mkinitcpio/ryoku.conf:22`), so parity needs nothing; an initramfs-tools version does not exist upstream.

---

### Existing-OS entries (`system/boot/limine/ryoku-windows-entry`, `system/boot/limine/45-ryoku-windows`)

**What it does:** scans every vfat/GPT-ESP partition for
`EFI/Microsoft/Boot/bootmgfw.efi`, writes a fenced `/Windows` entry
(`boot():` when Windows shares Limine's ESP, `uuid(<partuuid>)` cross-drive), and a
"Ryoku/Linux (existing)" chainload from `/etc/ryoku/limine-existing-esp`
(`ryoku-windows-entry:1-31,46-89,97-134,185-211,240-270`). Finds the live config in
Limine's search order (`:215-226`). `45-ryoku-windows` is a limine-entry-tool
`post.d` hook that re-runs `sync` after every regeneration (`45-ryoku-windows:1-7`),
installed by ryoku-desktop to `/etc/boot/hooks/post.d/` (`release/packages/ryoku-desktop/PKGBUILD:728-731`).

**Arch couplings:** none; uses `lsblk`, `findmnt`, `mount`, optional `bootctl` (`:76,141-146,220-224`).

**Dependencies:** util-linux (lsblk, findmnt, mount), systemd-boot (optional `bootctl`).

**As-is on Debian:** YES, provided the limine-entry-tool port keeps `run_boot_hooks` and `/etc/boot/hooks/post.d`.

**Port steps:** ship both files in the Ryoku desktop deb at the same paths; the post.d hook fires from the `zz-limine` scripts above (they call `run_boot_hooks post`). If ESP moves to `/efi`, `live_conf` already searches `/efi/limine.conf` (`:217`).

**Complexity:** Low.

---

### Initramfs configuration (`system/boot/mkinitcpio/ryoku.conf`, `system/boot/mkinitcpio/install/ryoku-gpu-trim`)

**What it does:** `HOOKS=(base udev plymouth keyboard autodetect ryoku-gpu-trim microcode modconf kms keymap consolefont block encrypt resume filesystems fsck)`
(`ryoku.conf:22`), written to `/etc/mkinitcpio.conf.d/ryoku.conf`
(`installation/backend/lib/chroot.sh:137-162`); `encrypt` stripped without LUKS
(`chroot.sh:149`); `ryoku-gpu-trim` dropped from HOOKS if the file is missing
(`chroot.sh:156-159`); the hook itself is shipped by ryoku-desktop to
`/usr/lib/initcpio/install/ryoku-gpu-trim` (`ryoku-desktop/PKGBUILD:737-738`) or seeded
by the installer (`deploy.sh:254-268`). No `MODULES`, `FILES` or `COMPRESSION` in
Ryoku's drop-in (mkinitcpio default compression zstd). Other drop-ins:
`/etc/mkinitcpio.conf.d/nvidia.conf` `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`
when the module built (`system/hardware/drivers/nvidia.sh:222-225`);
`/etc/mkinitcpio.conf.d/ryoku-vmd.conf` `MODULES+=(vmd)` when the live kernel loaded
`vmd` (`bootloader.sh:301-312`). `ryoku-gpu-trim` removes `nouveau` from
autodetect's allowlist when nouveau is blacklisted (`modprobe --showconfig`) and
`modprobe -S $KERNELVERSION -qn nvidia` succeeds, keeping ~100 MiB of GSP firmware
out of every image (`ryoku-gpu-trim:1-44`); the doctor re-adds the hook on older
boxes (`ryoku/cli/internal/doctor/reconcile_initramfs.go:24-120`).

**Arch couplings:** mkinitcpio HOOKS/`MODULES=()` syntax and `/etc/mkinitcpio.conf.d/` (`chroot.sh:161-162`, `nvidia.sh:223`, `bootloader.sh:308-311`); install-hook API `build()`, `_autodetect_cache`, `add_checked_modules` (`ryoku-gpu-trim:20-29`); `/usr/lib/initcpio/install/` path; `encrypt` hook + `cryptdevice=` cmdline (`bootloader.sh:259`).

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| mkinitcpio | image build (`base.packages:22`) | initramfs-tools (Debian default) or dracut (+ dracut-core) | 0.148.4; dracut 106-6 | - | 0.151; 112-7 | 0.151; 112-7 | 0.151ubuntu1; 110-11ubuntu0.1 | - |
| cryptsetup (encrypt hook) | LUKS unlock | cryptsetup-initramfs | 2:2.7.5-2 | - | 2:2.8.8-1 | 2:2.8.8-1 | 2:2.8.4-1ubuntu4 | - |
| kbd (keymap/consolefont) | LUKS prompt layout | console-setup + keyboard-configuration | 1.242~deb13u1 | - | 1.249 | 1.249 | 1.237ubuntu3.1 | - |
| amd-ucode/intel-ucode (microcode hook) | early ucode | amd64-microcode, intel-microcode | see Live package set | | | | | - |

**As-is on Debian:** NO.

**Port steps (initramfs-tools, line by line):**

| mkinitcpio | initramfs-tools | dracut |
|---|---|---|
| `base` | built in (busybox/klibc init) | built in (systemd initrd) |
| `udev` | systemd's udev initramfs hook (`debian/extra/initramfs-tools/hooks/udev`) | `systemd`, `udev-rules` modules |
| `plymouth` | plymouth package hook `/usr/share/initramfs-tools/hooks/plymouth` + `scripts/init-premount/plymouth` (starts only with `splash` on the cmdline) | `plymouth` module |
| `keyboard` | `MODULES=most` includes input drivers | default |
| `autodetect` | `/etc/initramfs-tools/conf.d/ryoku.conf`: `MODULES=dep` | `hostonly="yes"` (default on Debian dracut) |
| `ryoku-gpu-trim` | new `/etc/initramfs-tools/hooks/zz-ryoku-gpu-trim` (below) | `omit_drivers+=" nouveau "` in `/etc/dracut.conf.d/ryoku.conf` (omitted drivers take no firmware) |
| `microcode` | amd64-microcode / intel-microcode hooks prepend early cpio automatically | `early_microcode="yes"` (default) |
| `modconf` | automatic: `mkinitramfs:432-433` copies `/etc/modprobe.d/*.conf` and `/lib/modprobe.d/*.conf` | automatic (`kernel-modules`) |
| `kms` | plymouth hook copies `kernel/drivers/gpu/drm` with `MODULES=most`, or only bound DRM drivers with `MODULES=dep` (plymouth.hook, "add drm modules"); NVIDIA: `/etc/initramfs-tools/modules` lines `nvidia nvidia_modeset nvidia_uvm nvidia_drm` | `add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "` |
| `keymap` + `consolefont` | `KEYMAP=y` in `/etc/initramfs-tools/conf.d/ryoku.conf` (default `n`, `conf/initramfs.conf`) + console-setup's hook (font from `/etc/default/console-setup`) | `i18n` module (reads `/etc/vconsole.conf`) |
| `block` | default | default |
| `encrypt` + `cryptdevice=UUID=<luks>:root` | cryptsetup-initramfs; `/etc/crypttab` `root UUID=<luks> none luks,discard,initramfs` (Ryoku already writes `root UUID=... none luks`, `chroot.sh:170-178`); drop `cryptdevice=` from the cmdline; keep `root=/dev/mapper/root` | `crypt` module + `rd.luks.name=<luks-uuid>=root` (or crypttab) |
| `resume` | `scripts/local-premount/resume` honors `resume=` + `resume_offset=`; `/etc/initramfs-tools/conf.d/resume`: `RESUME=none` when no swapfile so it does not auto-pick a swap device | `resume` module |
| `filesystems` | btrfs-progs ships an initramfs hook; `MODULES` handles btrfs | `btrfs` module |
| `fsck` | `hooks/fsck` (initramfs-tools core) | `fs-lib` |
| `MODULES=(nvidia ...)` drop-in (`nvidia.sh:223-225`) | `/etc/initramfs-tools/modules` (one per line) | `add_drivers+=` |
| `MODULES+=(vmd)` drop-in (`bootloader.sh:309-311`) | append `vmd` to `/etc/initramfs-tools/modules` (with `MODULES=most` vmd is already included) | `add_drivers+=" vmd "` |
| compression (default zstd) | `COMPRESS=zstd` (Debian default, `conf/initramfs.conf`) | `compress="zstd"` |
| `mkinitcpio -P` | `update-initramfs -u -k all` | `dracut --regenerate-all --force` |

`/etc/initramfs-tools/hooks/zz-ryoku-gpu-trim` (behaviour of `ryoku-gpu-trim:20-44`; initramfs-tools runs `depmod -a -b $DESTDIR` after all hooks, `mkinitramfs:441-454`, so deleting files from `$DESTDIR` is safe):
```sh
#!/bin/sh
PREREQ="plymouth"
prereqs() { echo "$PREREQ"; }
case "$1" in prereqs) prereqs; exit 0;; esac
modprobe --showconfig 2>/dev/null | grep -qE '^blacklist[[:space:]]+nouveau[[:space:]]*$' || exit 0
modprobe -S "${version}" -qn nvidia 2>/dev/null || exit 0
rm -rf "${DESTDIR}/usr/lib/modules/${version}/kernel/drivers/gpu/drm/nouveau" \
       "${DESTDIR}/lib/modules/${version}/kernel/drivers/gpu/drm/nouveau"
find "${DESTDIR}/usr/lib/firmware/nvidia" "${DESTDIR}/lib/firmware/nvidia" \
     -path '*/gsp/*' -delete 2>/dev/null || true
```
Installer edits: `chroot.sh:137-162` writes `/etc/initramfs-tools/conf.d/ryoku.conf` (`MODULES=dep`, `KEYMAP=y`) and the hook; `chroot.sh:149` (strip `encrypt`) becomes "install cryptsetup-initramfs only with LUKS"; `nvidia.sh:223-225` and `bootloader.sh:308-311` write `/etc/initramfs-tools/modules`; `reconcile_initramfs.go:30-31` constants change to the new paths.

**Complexity:** Medium.

**Issues / risks:**
- initramfs-tools pulls firmware for every included module through `dracut-install --firmwaredirs` (`hook-functions:113-131`), so nouveau's GSP blobs (in `firmware-misc-nonfree`) land in the image exactly as on Arch; with `MODULES=most` the plymouth hook copies the whole `drivers/gpu/drm` tree.
- `MODULES=dep` inspects the RUNNING system's `/sys`; inside the installer chroot that is the live ISO's hardware state (nouveau bound, no NVIDIA module), same caveat as mkinitcpio's autodetect in `arch-chroot`.
- dracut and initramfs-tools conflict as packages; Debian's plymouth only ships the initramfs-tools hook (plymouth filelist), dracut uses its own `plymouth` module.

**Questions for the human:**
- Initramfs generator: (a) initramfs-tools (Debian/Ubuntu default, busybox init like mkinitcpio's base, plymouth hook shipped by Debian); (b) dracut (systemd initrd; `rd.luks.*` cmdline; `omit_drivers` replaces the trim hook in one line; upstream limine-entry-tool already has a dracut variant `install/arch-linux/limine-dracut-support/`).

---

### Plymouth theme (`system/boot/plymouth/ryoku/`)

**What it does:** `ModuleName=script`, `ImageDir`/`ScriptFile` under
`/usr/share/plymouth/themes/ryoku`, `Font=Cantarell 11` (`ryoku.plymouth:1-11`);
the script draws a centred `logo.png` on pure black (`ryoku.script:5-12`), a
password entry with lock icon and up to 21 bullets (`:119-198`), a fake-then-real
progress bar shown only after a password prompt in boot/resume mode (`:14-115,145-158,200-231`),
and a top-left text message via `Image.Text` (`:244-259`). Assets: `logo.png`
928x160, `entry.png` 440x64, `lock.png` 84x96, `bullet.png` 28x28,
`progress_bar.png`/`progress_box.png` 300x10. Shipped by ryoku-desktop
(`ryoku-desktop/PKGBUILD:742-744`), made default by the installer
(`bootloader.sh:314-326`) and by `ryoku-boot-apply:19-21`.

**Arch couplings:** none in the theme. Arch's `plymouth` mkinitcpio hook embeds the default theme.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| plymouth | splash (`base.packages:35`) | plymouth (script.so, `plymouth-set-default-theme`, initramfs hook) | 24.004.60-5 | - | 26.134.222-1 | 26.134.222-1 | 24.004.60+git20250831.4a3c171d-0ubuntu8.1 | script plugin API (`ryoku.script`), stable across 24.x-26.x |
| (in plymouth) | `Image.Text` (`ryoku.script:249`) | plymouth-label (label-pango.so) | 24.004.60-5 | - | 26.134.222-1 | same | same | Debian hook copies `label-pango.so` for non-text themes (plymouth.hook "PLUGINS") |
| cantarell-fonts | `Font=Cantarell 11` (`ryoku.plymouth:10-11`) | fonts-cantarell | 0.303.1-4 | - | 0.311-3 | 0.311-3 | 0.303.1-4 | - |

**As-is on Debian:** YES for the theme files; PARTIAL for initramfs integration (font).

**Port steps:**
1. Ship `system/boot/plymouth/ryoku/` at `/usr/share/plymouth/themes/ryoku/` in the desktop deb (same path).
2. Depends: `plymouth, plymouth-label, fonts-cantarell`.
3. Set default: `plymouth-set-default-theme ryoku` (Debian `/usr/sbin/plymouth-set-default-theme`, writes `/etc/plymouth/plymouthd.conf`), then `update-initramfs -u -k all`; or `plymouth-set-default-theme -R ryoku` which rebuilds.
4. Font in initramfs: Debian's hook copies Cantarell only for the `spinner` and `bgrt` themes and otherwise links `Plymouth.ttf` to the `fc-match` default (plymouth.hook font section). Add `/etc/initramfs-tools/hooks/ryoku-plymouth-font` copying `/usr/share/fonts/opentype/cantarell/Cantarell-VF.otf` (or Regular) into `$DESTDIR` and re-running `fc-cache -s -y "$DESTDIR"`. Only the `Image.Text` message line uses it.
5. Keep `splash` on the cmdline (`default.conf:31`); Debian's init-premount script only starts plymouthd with it.

**Complexity:** Low.

**Issues / risks:** with `MODULES=dep` and an NVIDIA GPU, the splash depends on the nvidia modules being listed in `/etc/initramfs-tools/modules` (early KMS); otherwise plymouth falls back to the EFI framebuffer (Debian 6.12/7.2 use `CONFIG_FB_EFI=y`, no simpledrm per `debian/config`), which the script comment assumes is simpledrm (`ryoku.script:3-4`), only a colour-seam concern.

---

### ryoku-boot-apply (`system/boot/ryoku-boot-apply`)

**What it does:** on package upgrade: sets the Plymouth default (`:19-21`), deletes a
legacy ESP wallpaper (`:23-24`), syncs only the visual globals of
`/usr/share/ryoku/boot/limine.conf` into `/boot/limine.conf` with a `.ryoku-bak`
backup (`:28-54`), syncs the fixed `KERNEL_CMDLINE[default]+=" quiet splash ..."`
line from `/usr/share/ryoku/boot/default.conf` into `/etc/default/limine`
(`:62-73`), and rebuilds images via `limine-mkinitcpio` or `mkinitcpio -P` when
the theme hash or cmdline changed (`:77-85`, stamp `/var/lib/ryoku/boot-theme.stamp`).
Skips non-systemd chroots (`:15`). Called from the ryoku-desktop pacman scriptlet
(`release/packages/ryoku-desktop/ryoku-desktop.install:220-223`).

**Arch couplings:** `limine-mkinitcpio` / `mkinitcpio -P` (`:79-82`); `esp=/boot` (`:10`); pacman `.install` scriptlet caller.

**Dependencies:** plymouth, limine-entry-tool port, initramfs-tools.

**As-is on Debian:** PARTIAL.

**Port steps:**
1. `:79-83` -> `if command -v limine-initramfs >/dev/null; then limine-initramfs || true; else update-initramfs -u -k all || true; fi`.
2. `:10` `esp=/boot` -> the chosen ESP path.
3. Caller: ryoku-desktop deb `postinst configure)` calls `ryoku-boot-apply`, or a dpkg file trigger `interest-noawait /usr/share/plymouth/themes/ryoku` + `/usr/share/ryoku/boot` in the same package.

**Complexity:** Low.

---

### Kernel command line (`system/boot/limine/default.conf`, `installation/backend/lib/bootloader.sh`)

**What it does:** installed system:

| Parameter | Set at | Ryoku's reason | Debian status |
|---|---|---|---|
| `root=UUID=<fs>` / `root=/dev/mapper/root` | `bootloader.sh:259,263` | root fs | same |
| `rootflags=subvol=@ rw` | `bootloader.sh:259,263` | btrfs root subvolume | same |
| `cryptdevice=UUID=<luks>:root` | `bootloader.sh:259` | Arch `encrypt` hook | not read by initramfs-tools or dracut; use crypttab (`chroot.sh:170-178`) or dracut `rd.luks.name=<uuid>=root` |
| `nvidia_drm.modeset=1` | `bootloader.sh:265` | NVIDIA KMS (also modprobe.d, `nvidia.sh:217`) | same |
| `resume=<dev> resume_offset=<n>` | `bootloader.sh:274-289` | hibernate to btrfs swapfile | same; disabled under SB lockdown (see Secure Boot) |
| `quiet splash` | `default.conf:31` | hand screen to Plymouth | same |
| `loglevel=0`, `systemd.show_status=false`, `vt.global_cursor_default=0` | `default.conf:31` | clean splash (`default.conf:18-23`) | same |
| `rd.udev.log_level=0` | `default.conf:31` | silence udev in initrd | honored by dracut's systemd initrd; initramfs-tools starts udevd itself with `SYSTEMD_LOG_LEVEL=notice` under `quiet` (systemd `debian/extra/initramfs-tools/scripts/init-top/udev`) |
| `initramfs_async=0` | `default.conf:24-31` | Ryoku: "kernel 7.1 unpacks the initramfs asynchronously, which races /init" | parameter exists since Linux 5.13; valid on 6.12 and 7.x |

Live ISO: see "Live boot menus".

**Arch couplings:** `cryptdevice=`.

**As-is on Debian:** PARTIAL.

**Port steps:** `bootloader.sh:258-259`: `cmdline="root=/dev/mapper/root rootflags=subvol=@ rw cryptdevice=UUID=${luks_uuid}:root"` -> `cmdline="root=/dev/mapper/root rootflags=subvol=@ rw"` (initramfs-tools) or `... rw rd.luks.name=${luks_uuid}=root` (dracut); keep the rest.

**Complexity:** Low.

---

### Kernels: stock and CachyOS (`docs/kernels.md`, `system/packages/cachyos.packages`, `installation/backend/lib/cachyos.sh`)

**What it does:**
- Stock: `linux`, `linux-headers`, `linux-firmware`, `dkms` in the base set (`system/packages/base.packages:12-21`). Arch `linux` is 7.2.11.arch1-1 (archlinux.org, 2026-10-17).
- CachyOS, two code paths that disagree:
  - Hub opt-in (doc): adds only `[cachyos-v3]` and installs `linux-cachyos` + headers via the `cachyos-kernel` ryostore bundle and `ryoku-pkg-cachyos`; "we do not add the CachyOS core and extra rebuilds" (`docs/kernels.md:53-58,89-107`); stock kernel stays default (`docs/kernels.md:3-4,43-47`).
  - CachyOS ISO variant (code): bakes the whole layer from `cachyos.packages` (`linux-cachyos`, `-headers`, keyring, three mirrorlists, `cachyos-settings`, `ananicy-cpp`, `cachyos-ananicy-rules`, `scx-scheds`, `proton-cachyos-slr`, `cachyos.packages:14-47`) into the offline repo (`offline-repo.sh:55`), boots `linux-cachyos` by default (`bootloader.sh:163,356-358`), and on v3 CPUs inserts `[cachyos-v3]`, `[cachyos-core-v3]`, `[cachyos-extra-v3]`, `[cachyos]` above `[core]` (`cachyos.sh:61-81`), i.e. the userland rebuilds the doc says are not added. `cachyos.packages:1-4` says "Installed by pacstrap on every target ... a Ryoku install IS a CachyOS install", while `pacstrap.sh:71-75` reads it only for `RYOKU_VARIANT=cachyos` and `base.packages:17-19` says the CachyOS kernel is never in the base.
- linux-cachyos upstream: `CachyOS/linux-cachyos/linux-cachyos/PKGBUILD` 7.2.11: source is the pre-patched tarball `https://github.com/CachyOS/linux/releases/download/cachyos-7.2.11-1/cachyos-7.2.11-1.tar.gz` + `config` + `kernel-patches/7.2/sched/0001-bore-cachy.patch` (default `_cpusched=cachyos`), clang ThinLTO (`_use_llvm_lto=thin`), `HZ=1000`, `_preempt=full`, `_tickrate=full`, AutoFDO/Propeller off by default, makedepends include `rust rust-bindgen rust-src pahole libelf`.

Kernel versions:

| Kernel | Version |
|---|---|
| Arch `linux` | 7.2.11.arch1-1 |
| Arch/CachyOS `linux-cachyos` | 7.2.11 (PKGBUILD) |
| Debian trixie `linux-image-amd64` | 6.12.107-1 |
| trixie-backports | 7.2.6-1~bpo13+1 |
| forky / sid | 7.2.11-1 |
| Ubuntu 26.04 `linux-image-generic` (and `-hwe-26.04`) | 7.0.0-39.39 |

Kernel features Ryoku touches (Debian configs from `debian/config/{config,amd64/config,kernelarch-x86/config}` at 6.12.107-1 and 7.2.11-1):

| Feature | Ryoku use | trixie 6.12 | 7.2 (bpo/forky/sid) | Ubuntu 7.0 |
|---|---|---|---|---|
| `CONFIG_SCHED_CLASS_EXT` (sched_ext) | `scx-scheds` (`cachyos.packages:34-36`), `docs/kernels.md:13-14` | not set | `=y` | not checked (Ubuntu config not retrievable here) |
| `CONFIG_NTSYNC` | none in Ryoku code; consumed by Proton when present (`proton-cachyos-slr`, `cachyos.packages:47`) | absent | `=m` | not checked |
| `CONFIG_ASUS_ARMOURY` (`/sys/class/firmware-attributes`) | `system/hardware/gpu/ryoku-gpu-mux:17-64` prefers it, falls back to `asus-nb-wmi` | absent | `=m` | not checked |
| `CONFIG_X86_AMD_PSTATE` | `docs/power.md:7-9,252` | `=y` | `=y` | - |
| `initramfs_async=` | `default.conf:24-31` | yes | yes | yes |
| `CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT` | (see Secure Boot) | `=y` | `=y` | Ubuntu also locks down under SB |
| `CONFIG_HZ` | none | 250 | 250 | - |
| `CONFIG_FB_EFI` / simpledrm | Plymouth comment (`ryoku.script:3-4`) | efifb, no simpledrm | same | - |

Arch kernels ship `/usr/lib/modules/<ver>/pkgbase` and `/usr/lib/modules/<ver>/vmlinuz`; Debian kernels ship neither (`/boot/vmlinuz-<ver>`; no pkgbase file). Ryoku reads `pkgbase` in the doctor (`reconcile_limine_images.go:42-60`, `reconcile_limine.go:970-978`) and the limine hook (above).

**Arch couplings:** `cachyos.sh:20-27,33-41` (`pacman.conf` Architecture `x86_64_v3`, `[multilib]`), `cachyos.sh:110-117` (`pacman-key --populate cachyos`); `system/extras/ryoku-pkg-cachyos` (repo insertion, key `F3B607488DB35A47`, `docs/kernels.md:93-97`); ryostore bundle `requires: ["cachyos"]` (`docs/kernels.md:89-92,112-121`).

**Dependencies (CachyOS kernel build as .deb):**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| linux-cachyos | kernel (`cachyos.packages:14`) | none (no CachyOS apt repo; CachyOS/linux-cachyos-deb is archived) | - | - | - | - | - | 7.2.11 (PKGBUILD) |
| clang llvm lld | ThinLTO (PKGBUILD `_use_llvm_lto=thin`) | clang, llvm, lld | 1:19.0-63 | - | 1:21.1.8-74 | 1:21.1.8-74 | 1:21.1.6-71 | kernel 7.2 needs clang >= 15 (kernel `Documentation/process/changes.rst`) |
| pahole | BTF | dwarves | 1.30-1 | - | 1.32-1 | 1.32-1 | 1.31-2ubuntu1 | - |
| libelf | objtool | libelf-dev | 0.192-4 | 0.196-1~bpo13+2 | 0.196-1 | 0.196-1 | 0.194-4 | - |
| openssl | module signing | libssl-dev | 3.5.7 | - | 3.6.5-1 | 3.6.5-1 | 3.5.5 | - |
| rust, rust-bindgen, rust-src | `CONFIG_RUST` drivers | rustc, bindgen, rust-src | 1.85.1; 0.71.1-6; 1.85.1 | 1.96.1 | 1.96.1; 0.72.1 | 1.97.1 | 1.93.1; 0.72.1 | kernel minimum rustc/bindgen per `changes.rst`; trixie rustc 1.85 is below what 7.x requires only if the config enables Rust drivers (not verified) |
| bc, cpio, kmod, flex, bison, perl, python, xz, zstd | build | bc, cpio, kmod, flex, bison, perl, python3, xz-utils, zstd, dpkg-dev, rsync | trixie versions above | | | | | - |
| scx-scheds | sched_ext schedulers (`:36`) | none | - | - | - | - | - | build `github.com/sched-ext/scx` (Rust/C) as a deb |
| ananicy-cpp, cachyos-ananicy-rules | (`:31-32`) | none | - | - | - | - | - | build from gitlab.com/ananicy-cpp/ananicy-cpp (CMake) + rules repo |
| cachyos-settings | sysctl/udev tuning (`:27`) | none | - | - | - | - | - | package the `CachyOS/CachyOS-Settings` tree as a deb |
| proton-cachyos-slr | Proton (`:47`) | none | - | - | - | - | - | download CachyOS proton release tarball into the Steam compat dir |

**As-is on Debian:** PARTIAL. A stock kernel exists for every base; nothing CachyOS exists.

**Port steps:**
1. Stock kernel: `linux-image-amd64` + `linux-headers-amd64` + `dkms` (Ubuntu: `linux-generic`). For trixie, 7.2 comes from `trixie-backports` (`apt -t trixie-backports install linux-image-amd64 linux-headers-amd64`), which brings sched_ext/ntsync/asus-armoury.
2. CachyOS kernel as .deb (mirrors the PKGBUILD's prepare/build):
   ```sh
   v=7.2.11 rel=1
   curl -LO https://github.com/CachyOS/linux/releases/download/cachyos-$v-$rel/cachyos-$v-$rel.tar.gz{,.asc}
   gpg --verify cachyos-$v-$rel.tar.gz.asc   # keys E18447AC260021D31F3FF6C4C8A2A4774B8B63C4, E8B9AA39F054E30E8290D492C3C4820857F654FE
   tar xf cachyos-$v-$rel.tar.gz && cd cachyos-$v-$rel
   curl -LO https://raw.githubusercontent.com/cachyos/kernel-patches/master/7.2/sched/0001-bore-cachy.patch && patch -Np1 < 0001-bore-cachy.patch
   curl -Lo .config https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos/config
   scripts/config -e CACHY -e SCHED_BORE -e LTO_CLANG_THIN -d HZ_300 -e HZ_1000 --set-val HZ 1000 \
                  -e GENERIC_CPU --set-val X86_64_VERSION 3          # v3 as docs/kernels.md:98-104
   scripts/config --set-str LOCALVERSION -cachyos
   make LLVM=1 LLVM_IAS=1 olddefconfig
   make LLVM=1 LLVM_IAS=1 -j"$(nproc)" bindeb-pkg KDEB_PKGVERSION=$v-$rel
   ```
   Output: `linux-image-$v-cachyos_*.deb`, `linux-headers-$v-cachyos_*.deb`. Prior art for a CI-built custom kernel deb channel: `/home/me/src/hyprdebian-kernel` (`plan.sh`/`build.sh`, `docker run debian:trixie`, `KDEB_PKGVERSION=`, published as GitHub Releases), described in machine state.
   DKMS with a clang-built kernel: the PKGBUILD applies `kernel-patches/7.2/misc/dkms-clang.patch`; on Debian, DKMS builds for this kernel need `clang`/`lld` installed and `LLVM=1` honored by dkms (dkms 3.2.2 reads the kernel's `CONFIG_CC_IS_CLANG`).
3. Reference third-party Debian kernels (not CachyOS): XanMod (`deb.xanmod.org`, `linux-xanmod-x64v3`), Liquorix (`liquorix.net`, `linux-image-liquorix-amd64`); community CachyOS-for-deb builders found on GitHub (e.g. `fabianwimberger/linux-cachyos-deb`, `Deadly-Signal/cachy-kernel-debian`), none official.
4. Repository wiring (`cachyos.sh`, `ryoku-pkg-cachyos`): replaced by the Ryoku apt repo carrying the kernel debs (no `[cachyos*]` repos exist for apt).
5. `/etc/ryoku/default-kernel` + `default_entry` logic: the kernel name for the CachyOS deb follows the naming decision (its uname suffix `-cachyos` distinguishes it).

**Complexity:** High (CachyOS kernel + four userland components to package and maintain).

**Issues / risks:**
- Doc vs code: `docs/kernels.md:53-58` says only `[cachyos-v3]` is added; `cachyos.sh:79` adds `[cachyos-core-v3]` and `[cachyos-extra-v3]` (the userland rebuilds) for the ISO variant. `cachyos.packages:1-4` vs `pacstrap.sh:71-75`/`base.packages:17-19` disagree on whether every install gets the layer.
- `limine-mkinitcpio-hook`'s CachyOS fallback note (`README.md:46-48`) relies on both kernels being regenerated by name.
- The CachyOS kernel built with clang ThinLTO takes ~1h45m per build on CI hardware (hyprdebian-kernel measurement in machine state, gcc build).
- Ubuntu 26.04's stock kernel (7.0) and trixie's (6.12) differ by two major series from Arch's 7.2; trixie 6.12 lacks sched_ext, so `scx-scheds` cannot run on the trixie stock kernel.

**Questions for the human:**
- Kernel source per base: (a) Debian/Ubuntu stock (trixie 6.12 without sched_ext/ntsync/asus-armoury; trixie-bpo/forky 7.2 with them; Ubuntu 7.0); (b) trixie-backports kernel by default; (c) Ryoku-built CachyOS deb as an opt-in (keeps the Hub toggle; needs a build/publish pipeline and signing for Secure Boot).
- CachyOS ISO variant on Debian: port it (kernel + cachyos-settings + ananicy-cpp + scx + proton tarball, all self-built) or keep only the kernel opt-in described in `docs/kernels.md`.

---

### Secure Boot (`installation/backend/lib/preflight.sh`, `installation/tui/system.go`, `installation/tui/main.go`)

**What it does today:** no Secure Boot support. The TUI reads the `SecureBoot`
efivar and blocks Review (`tui/system.go:802,846-860`, `tui/main.go:1951-1960,2928-2941`);
the backend dies before touching the disk unless `RYOKU_ALLOW_SECUREBOOT=1`
(`preflight.sh:10-20,46-52`); docs: "Limine ships unsigned" (`README.md:132-135,143`,
`docs/installation-hardware.md:54-71`). No sbctl, MOK or shim anywhere in the
installer; sbctl appears only as an optdepend of limine-mkinitcpio-hook
(`PKGBUILD:55`) and in i18n strings for the NVIDIA-skip message. The live ISO
itself boots an unsigned systemd-boot (`profiledef.sh:19`), so it does not boot
with Secure Boot enforcing.

**Arch couplings:** Arch kernels do not enable `LOCK_DOWN_IN_EFI_SECURE_BOOT`; Debian's do (`=y` in 6.12.107 and 7.2.11 configs) with `CONFIG_MODULE_SIG=y`.

**Dependencies:**

| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |
|---|---|---|---|---|---|---|---|---|
| (none) | shim chain | shim-signed | 1.51~1+deb13u1+16.1-2~deb13u1 | - | 1.51+16.1-2 | 1.51+16.1-2 | 1.59+15.8-0ubuntu2 | - |
| (none) | signed GRUB | grub-efi-amd64-signed | 1+2.12+9+deb13u2 | - | 1+2.14+4 | 1+2.14+4 | 1.215+2.14-2ubuntu1 | - |
| (none) | MOK enroll | mokutil | 0.7.2-1 | - | 0.7.2-2+b1 | same | 0.7.2-2 | - |
| sbctl (opt) | own keys + signing (`PKGBUILD:55`) | none in Debian/Ubuntu | - | - | - | - | - | upstream 0.18 (Go >= 1.24, `go.mod`); trixie golang-go 2:1.24~2 builds it |
| sbsigntools | signing | sbsigntool | 0.9.4-3.2+deb13u1 | - | 0.9.5-2 | 0.9.5-2 | 0.9.4-3.1ubuntu9 | - |
| efitools | key enrollment | efitools | 1.9.2-3.5 | - | 1.9.2-6 | 1.9.2-6 | 1.9.2-5 | - |
| (systemd) | UKI signing | systemd-ukify (`--secureboot-private-key/--secureboot-certificate`) | 257.13-1~deb13u1 | - | 262-1 | 262.1-1 | 259.9-0ubuntu0.1 | - |

**As-is on Debian:** PARTIAL (the refusal gates port unchanged; Debian adds the shim path and lockdown).

**Port steps (per path):**
1. Keep today's behaviour (SB must be off): port the gates unchanged. Debian live ISO built per Option B step 8 boots under SB (shim + signed GRUB + signed `linux-image-amd64`), then the TUI's refusal applies as today.
2. Debian-native SB (GRUB): `shim-signed`, `grub-efi-amd64-signed`, signed `linux-image-amd64`; DKMS: Debian's dkms generates `/var/lib/dkms/mok.key`/`mok.pub` and signs modules; enroll with `mokutil --import /var/lib/dkms/mok.pub` (MokManager prompt at next boot, needs `mmx64.efi` on the ESP). Snapshot boot entries would come from `grub-btrfs` instead of limine-snapper-sync.
3. Limine with own keys: build sbctl 0.18 (`git clone https://github.com/Foxboron/sbctl -b 0.18; make sbctl` -> `go build -ldflags "-X github.com/foxboron/sbctl.Version=0.18" ./cmd/sbctl`; man pages need `asciidoc-base`); `sbctl create-keys; sbctl enroll-keys -m` (firmware in Setup Mode, `-m` keeps Microsoft keys for option ROMs); limine-entry-tool then signs `limine_x64.efi` (`sb_sign`, `limine-common-functions:281-294`) and enrolls the config hash when `ENABLE_ENROLL_LIMINE_CONFIG=yes` (`:343-357`); UKIs signed by `ukify --secureboot-private-key=/var/lib/sbctl/keys/db/db.key --secureboot-certificate=/var/lib/sbctl/keys/db/db.pem` (or `sbctl sign`). With an enrolled config, Limine forces `hash_mismatch_panic: yes`, requires `#hash` on every path and disables the editor (limine `USAGE.md` "Secure Boot").
4. Limine behind shim with MOK: rename Limine to `grubx64.efi` beside `shimx64.efi`, sign Limine with a MOK key enrolled by `mokutil`; kernel modules signed with the same MOK key are trusted via the `.machine` keyring. Whether Limine's `protocol: efi` chainload of a MOK-signed UKI passes verification depends on shim's handling of third-stage `LoadImage`; not verified here.

**Complexity:** High.

**Issues / risks:**
- Debian/Ubuntu kernels with SB on enter lockdown (`CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT=y`): unsigned modules are refused (NVIDIA/xpadneo DKMS) and hibernation is unavailable. Ryoku's hibernation wiring (`bootloader.sh:267-289`, `system/boot/README.md:57-67`) is dead on any Debian SB-on machine. On Arch SB-on (own keys) neither happens.
- Path 3 (own keys, no shim): the kernel trusts module signatures from builtin and `.machine` (MOK, populated by shim) keyrings; db keys land in `.platform`, which is not used for module verification, so DKMS modules signed with an sbctl db key are still refused under lockdown. Path 3 therefore needs either shim+MOK for modules, or a self-built kernel with the signing key built in.
- Debian's signed GRUB only loads modules embedded in the signed image under SB; a GRUB theme replicating the Limine look must use only embedded modules (`gfxterm`, `png`, `font` are in Debian's monolithic list in `debian/build-efi-images`).

**Questions for the human:**
- Secure Boot target: (a) none (status quo, refuse SB); (b) Debian shim + signed GRUB + MOK (works out of the box on Microsoft-keyed firmware; replaces Limine and limine-snapper-sync; branding must be redone as a GRUB theme); (c) Limine + own keys (sbctl built from source; firmware Setup Mode per machine; DKMS modules need a signing story beyond db keys); (d) Limine behind shim + MOK (unverified chain, needs testing on hardware).

---

## Bootloader choice on Debian: Limine costs (facts)

- Not packaged in Debian or Ubuntu; Ryoku must build and ship `limine` 12.x (release tarball, `./configure --enable-all; make`).
- Its management layer (limine-entry-tool, limine-snapper-sync) is a GraalVM native-image Java tool whose distro integration exists only for pacman (`install/arch-linux/`); the Debian hook layer (kernel postrm.d, initramfs post-update.d, dpkg triggers, apt Pre-Invoke) has to be written and maintained by Ryoku, rebased on every upstream release (pinned 1.37.1/1.31.0 vs upstream 1.40.0/1.32.1).
- Build toolchain not in Debian: GraalVM CE 25 + Gradle 9.6.1, both vendored (Debian gradle 4.4.1).
- Unsigned: no out-of-the-box Secure Boot on Microsoft-keyed firmware; Debian kernels lock down under SB (DKMS + hibernation impact) regardless of loader.
- live-build cannot put Limine (or systemd-boot) on the live ISO EFI path; a custom xorriso pipeline can (`limine-bios-cd.bin`, `limine-uefi-cd.bin`, `limine bios-install image.iso`).
- Reads FAT only: kernels/UKIs must be copied to the ESP (Debian installs kernels to `/boot`).
- GRUB alternative on Debian: packaged, signed, `update-grub` via `/etc/kernel/postinst.d/zz-update-grub`, snapshot entries via `grub-btrfs`; Ryoku's branding (`limine.conf` palette, "Ryoku Bootloader") would be reimplemented as a GRUB theme, and the installer's Limine file surgery (`bootloader.sh:132-234,503-743`), `ryoku-windows-entry`, and the doctor's limine reconcilers would be replaced.

---

## Cross-cutting findings

- **TUI / installer agent:** `installation/tui/system.go:257-260` hardcodes `/run/archiso/bootmnt` -> `/run/live/medium` (tmpfs source after `toram`). `installation/tests/install-vm.py:93` expects the archiso serial autologin prompt.
- **Installer agent:** `filesystem.sh:59` mounts the ESP at `/boot`; the ESP-layout decision changes `bootloader.sh`, `filesystem.sh`, doctor constants and `bootguard.go:37`. `chroot.sh:193-203` pacman-hook masks become `update_initramfs=no` + `DISABLE_APT_SNAPSHOT=yes` + an env guard in the Limine hook. `snapshots.sh:67` `/etc/conf.d/snapper` -> `/etc/default/snapper`. `bootloader.sh:258-259` drop `cryptdevice=`. `chroot.sh:137-162`, `nvidia.sh:222-228`, `bootloader.sh:301-312` move to `/etc/initramfs-tools/{conf.d,modules,hooks}`.
- **CLI/doctor agent:** `reconcile_hardware.go:363-368` (`limine-mkinitcpio` / `mkinitcpio -P`), `reconcile_limine_images.go:46` and `reconcile_limine.go:970-978` (`/usr/lib/modules/*/pkgbase`: absent on Debian), `reconcile_limine_images.go:172-184` (`/boot/initramfs-*.img`, `/boot/vmlinuz-<name>`: Debian names are `initrd.img-<ver>`, `vmlinuz-<ver>`), `reconcile_limine.go:50-53,694` (`/boot/...` constants, `ryoku-pkg-aur-add limine-mkinitcpio-hook`), `reconcile_initramfs.go:30-31` (`/etc/mkinitcpio.conf.d/ryoku.conf`, `/usr/lib/initcpio/install/ryoku-gpu-trim`), doctor's `SNAP_PAC_SKIP=y` (Debian's 80snapper reads `DISABLE_APT_SNAPSHOT` from `/etc/default/snapper`, not the environment), `ryoku/cli/internal/keyboard/cmd.go:184-250` tells users to run `sudo mkinitcpio -P` (-> `update-initramfs -u`).
- **Packages agent:** debs needed in the Ryoku apt repo: `limine`, `limine-entry-tool` (Debian hook layer), `limine-snapper-sync`, JetBrainsMono Nerd Font, `ryoku-cursors`, optionally `sbctl`, CachyOS kernel/scx/ananicy-cpp/cachyos-settings. ryoku-desktop's install paths `/usr/lib/initcpio/install/ryoku-gpu-trim` (`PKGBUILD:737-738`) -> `/usr/share/initramfs-tools/hooks/ryoku-gpu-trim` (packaged hooks go in `/usr/share/initramfs-tools/hooks`); `.install` scriptlet `_boot_theme` (`ryoku-desktop.install:220-223`) -> deb postinst/trigger. Ryoku.Blobs must be compiled against the target suite's Qt (trixie Qt 6.8), not the build host's.
- **Hardware agent:** under SB on Debian, unsigned DKMS modules (NVIDIA) are refused by lockdown, matching the TUI's existing NVIDIA-skip message; the initramfs nouveau trim needs the initramfs-tools hook above; `/etc/initramfs-tools/modules` replaces `/etc/mkinitcpio.conf.d/nvidia.conf`; trixie 6.12 lacks `asus-armoury` (the mux script falls back to `asus-nb-wmi`).
- **Power agent:** hibernation (`resume=`/`resume_offset=`) is blocked by kernel lockdown whenever SB is on with Debian/Ubuntu kernels.
- **Release/CI agent:** ISO workflows move to a `debian:trixie` container; Trivy `skip-dirs` and squashfs glob change; `SOURCE_DATE_EPOCH` set in CI is overridden by build.sh.
- **Reproducibility:** Debian equivalents all honor `SOURCE_DATE_EPOCH`: mmdebstrap (`mmdebstrap:5563,8356`), mksquashfs 4.6.1 (`mksquashfs.c:6125`), mkinitramfs clamps mtimes (`mkinitramfs:480-484`) and drops `-T0` threading (`:252-256`), mkfs.fat (`mkfs.fat.c:1077`), xorriso, live-build (`configuration.sh:48-57`). Package freezing: `snapshot.debian.org/archive/debian/<timestamp>/` (Ubuntu: `snapshot.ubuntu.com`) replaces the Arch Linux Archive (`build.sh:144-149`).
- `system/boot/limine/limine.conf:10-11` points at `ryoku/cli/doctor.go` (`limineBranding`), which does not exist; the constant lives in `ryoku/cli/internal/doctor/reconcile_limine.go:30-32`.

## Debian package list (this section)

Live ISO build host: `live-build` or `mmdebstrap`, `squashfs-tools`, `xorriso`, `dosfstools`, `mtools`, `isolinux`, `syslinux-common`, `grub-efi-amd64-signed`, `shim-signed`, `grub-common`, `golang-go`, `cmake`, `ninja-build`, `qt6-base-dev`, `qt6-declarative-dev`, `qt6-shadertools-dev`, `qt6-multimedia-dev`, `git`, `curl`, `libarchive-tools`, `apt-utils`, `dpkg-dev`.

Live image: `systemd`, `systemd-sysv`, `udev`, `dbus`, `linux-image-amd64`, `firmware-linux-free`, `firmware-misc-nonfree`, `firmware-amd-graphics`, `firmware-iwlwifi`, `firmware-realtek`, `firmware-sof-signed`, `firmware-nvidia-gsp`, `amd64-microcode`, `intel-microcode`, `initramfs-tools`, `live-boot`, `live-boot-initramfs-tools`, `arch-install-scripts`, `mmdebstrap`, `debootstrap`, `parted`, `gdisk`, `btrfs-progs`, `dosfstools`, `cryptsetup`, `e2fsprogs`, `ntfs-3g`, `efibootmgr`, `netselect-apt`, `network-manager`, `iwd`, `wpasupplicant`, `wireless-regdb`, `kbd`, `console-data`, `console-setup-linux`, `keyboard-configuration`, `cage`, `foot`, `xwayland`, `git`, `curl`, `jq`, `sudo`, `less`, `vim`, `openssl`, `pciutils`, `mdadm`, `lvm2`, `systemd-timesyncd`, `debian-archive-keyring`, `util-linux`, `uuid-runtime`, `libarchive-tools`; Ryoku-built: `limine`, JetBrainsMono Nerd Font deb, `ryoku-cursors`.

Installed boot chain: `efibootmgr`, `initramfs-tools` (or `dracut`, `dracut-core`), `cryptsetup-initramfs`, `console-setup`, `systemd-ukify`, `systemd-boot-efi`, `python3-pefile`, `plymouth`, `plymouth-label`, `fonts-cantarell`, `snapper`, `btrfs-progs`, `libnotify-bin`, `inotify-tools`, `rsync`, `b3sum`, `xxhash`, `linux-image-amd64`, `linux-headers-amd64`, `dkms`, `amd64-microcode`, `intel-microcode`; Ryoku-built: `limine`, `limine-entry-tool`, `limine-snapper-sync`.

Secure Boot (path-dependent): `shim-signed`, `grub-efi-amd64-signed`, `mokutil`, `sbsigntool`, `efitools`; Ryoku-built: `sbctl`.

Kernel build (CachyOS opt-in): `build-essential`, `bc`, `bison`, `flex`, `cpio`, `kmod`, `libelf-dev`, `libssl-dev`, `dwarves`, `perl`, `python3`, `rsync`, `xz-utils`, `zstd`, `dpkg-dev`, `clang`, `llvm`, `lld`, `rustc`, `bindgen`, `rust-src`.

Limine/limine tools build: `build-essential`, `nasm`, `mtools`, `clang`, `llvm`, `lld` (Limine); vendored GraalVM CE JDK 25 + Gradle 9.6.1 (limine-entry-tool, limine-snapper-sync).

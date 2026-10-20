# 13 — Limine under Secure Boot, on a ZFS root (VM test, 2026-10-19)

Question for D-02: can stock Limine replace GRUB on the Debian base while
keeping Debian's shim + MOK Secure Boot chain, and can it boot a ZFS root and
ZFS snapshots?

**Answer: yes to both, with three conditions** (SBAT section, config-hash
enrollment, re-sign on every menu change) and one upstream ZFS bug to route
around.

## Setup

| Piece         | Version / source                                                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| VM            | libvirt domain `limine-sb`, q35, OVMF `OVMF_CODE_4M.secboot.fd`, SMM on                                                                |
| Firmware keys | `OVMF_VARS_4M.ms.fd` (Microsoft PK/KEK/db, as on a retail PC)                                                                          |
| Root          | debian13-stripped ISO (Sep 24), unattended single-disk ZFS install: `rpool/ROOT/hyprdebian`, kernel 6.12.111-stripped with ZFS builtin |
| shim          | Debian trixie `shim-signed` 16.1 (Microsoft-signed) as `EFI/BOOT/BOOTX64.EFI`, plus `mmx64.efi`                                        |
| Limine        | 12.9.4 upstream `limine-binary.tar.xz` (sha256 9880cc04…d6a0), installed as `EFI/BOOT/grubx64.efi`                                     |
| Signing key   | throwaway test key `CN=limine-sb-test MOK`, enrolled through MokManager "Enroll key from disk"                                         |
| UKI           | `ukify` (systemd 257, trixie) over the same kernel + initrd                                                                            |

Kernel and initrd stay at the ESP root, exactly where debian13-stripped's
esp-sync already puts them. Limine never reads ZFS: it loads the kernel from
FAT, and the kernel (ZFS builtin) imports the pool.

## Results

| #   | Test                                                                                       | Result                                                                                                                                                                 |
| --- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Limine, linux protocol, ZFS root, SB off                                                   | **Boots.** 0 failed units.                                                                                                                                             |
| 2   | Limine, linux protocol, ZFS snapshot `root=ZFS=rpool/ROOT/hyprdebian@t1`, SB off           | **Boots** a clone `rpool/ROOT/hyprdebian_t1`; marker written after the snapshot is absent.                                                                             |
| 3   | SB on, stock Limine signed with an enrolled MOK                                            | **Refused by shim**: `Verification failed: (0x1A) Security Violation`. Cause: Limine ships no `.sbat` section; shim rejects any binary without one, whoever signed it. |
| 4   | Same, after adding `.sbat` (see recipe)                                                    | **Shim loads Limine.**                                                                                                                                                 |
| 5   | SB on, no config hash enrolled, linux protocol, unsigned kernel                            | **Boots, insecurely.** Limine treats SB as inactive and tells the kernel so: dmesg `Secure boot disabled`. Anyone who can write the ESP can boot any kernel.           |
| 6   | SB on, `protocol: efi` chainload of a MOK-signed UKI (Ryoku's own boot path)               | **Boots.** dmesg `Secure boot enabled`, the MOK cert is loaded into the kernel's integrity keyring. Shim's LoadImage hook honours MOK for images Limine chainloads.    |
| 7   | SB on, `protocol: efi` chainload of an **unsigned** UKI                                    | **Refused**: `PANIC: efi: LoadImage failure (0x...1a)`.                                                                                                                |
| 8   | SB on, config hash enrolled + re-signed, linux protocol with `#blake2b` hashes             | **Boots**, and now dmesg says `Secure boot enabled`. Menu editor and blank-entry keys are gone.                                                                        |
| 9   | Same, entry without a hash                                                                 | **Refused**: `Secure Boot is active and URI 'boot():/vmlinuz-…' has no associated hash!`                                                                               |
| 10  | Same, one entry appended to `limine.conf` without re-enrolling (what a snapshot sync does) | **Refused**: `!!! CHECKSUM MISMATCH FOR CONFIG FILE !!!`                                                                                                               |
| 11  | Re-enroll the edited config's hash + re-sign Limine                                        | **Boots**, new entry listed. The update cycle works.                                                                                                                   |
| 12  | Boot the same ZFS snapshot a second time (clone mode)                                      | **Drops to the initramfs shell.** Upstream OpenZFS bug, below. Not Limine, not Secure Boot.                                                                            |

## What this means for D-02

- **Limine + Secure Boot via Debian's shim and MOK works.** It is the same chain
  as Debian13-Hyprland, with Limine in GRUB's slot.
- **The config hash must be enrolled.** Without it, Limine treats Secure Boot as
  off and any ESP writer can boot an unsigned kernel (test 5). With it, the
  chain is closed (tests 7, 9, 10).
- **Every menu change costs a re-enroll + re-sign** (tests 10, 11). So the
  snapshot-entry tool must run `limine enroll-config` and `sbsign` after each
  rewrite, which means the per-install MOK private key has to be readable by
  root at runtime. Debian13-Hyprland already keeps it at `/var/lib/dkms/mok.key`
  for dkms, so this adds no new exposure.
- **UKIs are the simplest kernel path**: `protocol: efi` entries need no hash in
  the config, the firmware/shim check the signature, and the kernel sees Secure
  Boot itself. That is already Ryoku's layout (`EFI/Linux/*.efi`).
  Linux-protocol entries also work but need a `#blake2b` per file.
- **ZFS root and ZFS snapshots boot through stock Limine.** No fork is needed.

## Recipe: SBAT for Limine (packaging step, no source patch)

```bash
printf 'sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md\nlimine,1,Limine,limine,12.9.4,https://github.com/limine-bootloader/limine\n' > sbat.csv
# place .sbat at the image's SizeOfImage (0x65000 for 12.9.4 x86_64), NOT after .data's raw end:
objcopy --add-section .sbat=sbat.csv --set-section-flags .sbat=contents,alloc,load,readonly,data \
  --change-section-address .sbat=0x65000 BOOTX64.EFI limine-sbat.efi
limine enroll-config limine-sbat.efi "$(b2sum limine.conf | cut -d' ' -f1)"
sbsign --key mok.key --cert mok.pem --output grubx64.efi limine-sbat.efi
```

Trap hit on the way: placing `.sbat` right after `.data`'s raw data overlaps
`.data`'s virtual size (its BSS), and objcopy then shrinks SizeOfImage. Shim
answers `Section 3 has zero size / Malformed section header`, even with Secure
Boot off. Read SizeOfImage from the PE header and put `.sbat` there; derive it
at build time rather than hard-coding 0x65000.

## Upstream bug: second boot of the same ZFS snapshot

OpenZFS's `contrib/initramfs/scripts/zfs`, `destroy_fs()`, assigns `_destroy_fs`
but runs `zfs destroy ${destroy_fs}`, which is always empty. Clone mode
re-creates `<root>_<snap>` on each snapshot boot and destroys the old clone
first, so the second boot of any snapshot dies with
`Destroying '' … missing dataset argument`. Present in the **zfs-2.4.4**
release, **fixed on master**. Until a release carries it, the snapshot tool
should delete a stale `<root>_<snap>` clone itself, or the entry should use
`rollback`.

## Not validated

- Real hardware. OVMF only; retail firmware quirks with shim → Limine untested.
- A Debian-signed kernel through Limine. The test used debian13-stripped's
  unsigned kernel; the UKI path signs the whole image, so this mostly matters
  for linux-protocol entries.
- Kernel lockdown. debian13-stripped's kernel is built from upstream source
  without Debian's "lock down in Secure Boot" patch
  (`LOCK_DOWN_KERNEL_FORCE_NONE`), so `/sys/kernel/security/lockdown` stayed
  `[none]` on every path. A signed `lockdown=integrity` in the UKI cmdline would
  cover it.
- The btrfs/snapper/limine-snapper-sync side. Nothing here exercised it.
- Running `enroll-config` + `sbsign` inside the installed system. Done on the
  host; the guest has neither the limine tool nor sbsigntool packaged yet.
- Pool export: the Sep 24 ISO's engine left `rpool` imported (fixed on
  debian13-stripped master by b235709); the first boot imported it anyway.

# 04: Packaging, the signed [ryoku] repo, release channels, CI and the release toolchain

Scope: every recipe under `release/packages/` (34 package directories plus `README.md`; the brief's "35" counts one too many: `ls release/packages` holds 34 dirs), the repo builder and importers in `release/repo/`, `release/gradle-offline/`, `release/media/`, `keys/`, every workflow in `.github/workflows/`, `bin/ryoku-release-*`, `bin/ryoku-r2-config`, `bin/ryoku-iso-manifest`, `.githooks/`, `VERSION`, `CODENAME`, `CONTRIBUTING.md`, and the repo and channel parts of `docs/updates.md` and `docs/development.md`. Source pinned at `98a0368253d9628be72b853985878a5db90e1547` (`VERSION` = `0.75.5-beta.20`, `CODENAME` = `Onogoro`). Debian/Ubuntu versions come from `tools/pkgver` (madison) unless marked otherwise. In tables, versions are trimmed to the upstream part (epoch and Debian revision dropped) and `-` means not present. Column order is always trixie | trixie-bpo | forky | sid | resolute.

## Summary

| Component | Path | As-is on Debian | Complexity | Blocking issues |
|---|---|---|---|---|
| ryoku-keyring | `release/packages/ryoku-keyring/` | NO | Low | pacman keyring format + `pacman-key --populate` scriptlet; the key is the creator's |
| ryoku-shell | `release/packages/ryoku-shell/` | PARTIAL | Medium | Go 1.26 (trixie main has 1.24); `uv` absent in trixie and resolute; `quickshell` absent in trixie main and resolute |
| ryoku-hub | `release/packages/ryoku-hub/` | PARTIAL | Low | Go >= 1.26.4 |
| ryoku (CLI) | `release/packages/ryoku/` | PARTIAL | Low here (High for the CLI itself, other doc) | `depends=('pacman' 'pacman-contrib' 'snapper')` |
| ryoku-blobs | `release/packages/ryoku-blobs/` | PARTIAL | Low | installs to `/usr/lib/qt6/qml`; Debian QML dir is multiarch |
| ryoku-rashin | `release/packages/ryoku-rashin/` | PARTIAL | Low | Go 1.26, `uv`, `prowl-agent` |
| ryogami | `release/packages/ryogami/` | PARTIAL | Low | `quickshell` availability |
| ryoku-palette-bridge | `release/packages/ryoku-palette-bridge/` | YES | Low | none |
| ryoku-oh-my-zsh | `release/packages/ryoku-oh-my-zsh/` | YES | Low | none (Arch/CachyOS provides become moot) |
| ryoku-desktop | `release/packages/ryoku-desktop/` | NO | High | 2 libalpm hooks, mkinitcpio hook, Limine files, `/etc` files become conffiles, QML dir, ~9 depends absent from Debian, `wheel` polkit rules, symlinks into `/usr/lib/qt6/qml` |
| ryoku-desktop-hyprland | `release/packages/ryoku-desktop-hyprland/` | PARTIAL | Medium | Hyprland stack only in trixie-bpo/forky/sid (resolute 0.53.3); QML dir |
| ryoku-desktop-niri | `release/packages/ryoku-desktop-niri/` | NO | Medium | `niri` not in Debian or Ubuntu (any suite) |
| hypr-dynamic-cursors | `release/packages/hypr-dynamic-cursors/` | PARTIAL | Medium | unpinned git source + network-time commit resolution |
| ryoku-hypr-plugins | `release/packages/ryoku-hypr-plugins/` | PARTIAL | Medium | same; Debian ships hyprbars/hyprfocus at a different path |
| hyprglass | `release/packages/hyprglass/` | PARTIAL | Medium | same |
| imgborders | `release/packages/imgborders/` | PARTIAL | Low | vendored git bundle already offline |
| ryoku-keysounds | `release/packages/ryoku-keysounds/` | PARTIAL | Medium | second upstream (mechvibes) source |
| hyprland-preview-share-picker | `release/packages/hyprland-preview-share-picker/` | PARTIAL | Medium | cargo vendoring, git submodule |
| xwayland-satellite | `release/packages/xwayland-satellite/` | PARTIAL | Low | cargo vendoring; pin is now obsolete (upstream v0.8.3) |
| gpk | `release/packages/gpk/` | PARTIAL | Low | `depends=('pacman')`; self-updater writes a package-owned file |
| prowl-agent | `release/packages/prowl-agent/` | PARTIAL | Medium | Go >= 1.26.4, modules fetched at build (no vendor tree), `-X main.managedBy=pacman` |
| ryomotion | `release/packages/ryomotion/` | PARTIAL | High | npm + Electron + Node tarball fetched at build; `gpu-screen-recorder` absent in trixie and resolute |
| ryoku-cursors | `release/packages/ryoku-cursors/` | YES | Low | must Conflict/Replace Debian `bibata-cursor-theme` |
| ryoku-cursor-material | `release/packages/ryoku-cursor-material/` | YES | Low | none |
| otf-space-grotesk | `release/packages/otf-space-grotesk/` | YES | Low | none |
| ttf-maple-mono-nf | `release/packages/ttf-maple-mono-nf/` | YES | Low | none |
| blesh | `release/packages/blesh/` | YES | Low | Debian `ble.sh` exists in forky/sid/resolute at the same path |
| broadcom-bt-firmware | `release/packages/broadcom-bt-firmware/` | YES | Low | upstream asset is itself a `.deb` (files under `/lib`) |
| game-devices-udev | `release/packages/game-devices-udev/` | YES | Low | `arch-meson` |
| dualsensectl | `release/packages/dualsensectl/` | YES | Low | Debian has it in forky/sid/resolute |
| asusctl | `release/packages/asusctl/` | PARTIAL | Medium | cargo vendoring |
| xpadneo-dkms | `release/packages/xpadneo-dkms/` | YES | Low | Debian has it in forky/sid |
| limine-mkinitcpio-hook | `release/packages/limine-mkinitcpio-hook/` | NO | High | `mkinitcpio` and `limine` absent; upstream ships only `install/arch-linux`; GraalVM + Gradle + online Maven deps |
| limine-snapper-sync | `release/packages/limine-snapper-sync/` | NO | High | `limine` absent; upstream ships only `install/arch-linux` |
| ryotunes (imported, no recipe here) | `release/repo/import-ryotunes.sh` | NO | High | upstream publishes only a `.pkg.tar.zst`; a deb needs Rust + Tauri + pnpm (pnpm not in Debian) |
| repo builder | `release/repo/build-repo.sh` | NO | High | makepkg, repo-add, bsdtar `.PKGINFO`, pacman db layout |
| ryotunes refresh | `release/repo/refresh-ryotunes.sh` | NO | Medium | edits `ryoku.db` with `repo-add`, `vercmp` |
| build toolchain list | `release/repo/build-toolchain.packages` | NO | Low | Arch names |
| gradle offline repo | `release/gradle-offline/` | PARTIAL | Medium | only the plugin is vendored, not jackson or the metadata zip |
| release key | `keys/ryoku-release-key.pub.asc` | NO (must replace) | Low | creator's key |
| Publish workflow | `.github/workflows/publish-repo.yml` | NO | High | `archlinux:latest`, makepkg, pacman, pacman-key, CachyOS leg |
| Release bookkeeping workflows | `stable-release.yml`, `unstable-version-bump.yml`, `release-channel-versions.yml`, `release-notes.yml` | YES | Low | none (ubuntu-latest, git only) |
| Release ledger | `.github/workflows/release-ledger.yml` | PARTIAL | Low | `archlinux:latest` only to get rclone + jq |
| ISO workflows | `build-iso.yml`, `build-iso-reusable.yml`, `build-iso-cachyos.yml` | NO | High | mkarchiso in `archlinux:latest`; CachyOS variant |
| Other 33 workflows | `.github/workflows/*` | 22 NEUTRAL / 11 ARCH-COUPLED / 5 CREATOR-ONLY (overlaps counted in §3) | Low-Medium | see §3 |
| Release scripts | `bin/ryoku-release-{version,bump,notes,ledger}`, `bin/ryoku-iso-manifest` | YES | Low | Debian version string rules (§2.6) |
| Git hooks | `.githooks/*` | PARTIAL | Low-Medium | pre-push PKGBUILD gate is pacman-only and silently passes off Arch |

---

## 1. Packaging model: facts every recipe below depends on

### 1.1 How Arch builds today

- Every monorepo recipe has `source=()` and reaches the checkout through `_repo="$startdir/../../.."` (e.g. `release/packages/ryoku-shell/PKGBUILD:20-22`); `makepkg` runs in place inside a full checkout (`release/packages/README.md:43-50`).
- Versions: the monorepo packages read `pkgver=${RYOKU_PKGVER:-0.1.0}`; `build-repo.sh` exports `RYOKU_PKGVER` from `bin/ryoku-release-version --pkgver` (`release/repo/build-repo.sh:83-84`), which prints `<core>.r<commit count>.g<short sha>` with any `-alpha/-beta` suffix stripped (`bin/ryoku-release-version:30-45`). Fixed-version packages (gpk, keyring, fonts, cursors, firmware, xwayland-satellite, picker, prowl-agent, ryomotion, limine stack, asusctl, dualsensectl, xpadneo, blesh, game-devices-udev, ryoku-cursor-material) keep their own `pkgver`.
- `makepkg --force --clean --nodeps --noconfirm --sign --key "$KEY_ID"` (`release/repo/build-repo.sh:103-114`): no dependency resolution at build time, so every makedepends must be pre-installed on the host from `release/repo/build-toolchain.packages`.
- Builds are NOT offline: VCS sources (`git+https://...`), release tarballs, the Node 22 tarball, npm registry, Electron download, Gradle distribution, GraalVM and Maven Central are all fetched by makepkg (§1.5).

### 1.2 Source-package shape on Debian (decision, see Questions)

Two shapes reproduce the Arch behaviour:

- **A. One source package for the monorepo** (`Source: ryoku`, `Format: 3.0 (native)`), producing every monorepo binary package (ryoku-shell, ryoku-hub, ryoku, ryoku-blobs, ryoku-rashin, ryogami, ryoku-palette-bridge, ryoku-desktop, ryoku-desktop-hyprland, ryoku-desktop-niri). The Arch exact pins (`"ryoku-shell=$pkgver"`, `release/packages/ryoku-desktop/PKGBUILD:25-31`) become `ryoku-shell (= ${binary:Version})`. The tracked tree is 301 MB (`git ls-files | du`), 239 MB of it `ryoku/assets`, so one native tarball per build is ~300 MB uncompressed. A native source cannot carry component tarballs, so the upstream-sourced recipes that use `RYOKU_PKGVER` (the four Hyprland plugins, ryoku-keysounds' mechvibes, ryoku-oh-my-zsh) stay separate sources.
- **B. One source package per PKGBUILD** (mirrors Arch). Each monorepo source needs the whole checkout (the recipes read across the tree: `ryoku-desktop` reads `system/`, `ryoku/apps/`, `ryoku/lockscreen/`; `ryoku-rashin` indexes the whole repo at build, `release/packages/ryoku-rashin/PKGBUILD:39-41`), so the 300 MB tree is duplicated per source. Exact cross-source pins are written with a substvar set in `debian/rules`: `dh_gencontrol -- -Vryoku:Version=$(RYOKU_PKGVER)` and `Depends: ryoku-shell (= ${ryoku:Version})`.

### 1.3 Version strings

- `RYOKU_PKGVER` values (`0.75.5.r12345.g98a0368`) are valid Debian upstream versions and sort the same way under `dpkg --compare-versions` (numeric runs compare numerically, `.r`/`.g` compare equal as literals).
- Native source: version has no Debian revision (`0.75.5.r12345.g98a0368`). Non-native fixed-version packages: `<upstream>-0ryoku1`; a Debian `<upstream>-1` sorts above `-0ryoku1`, which reproduces the intent at `release/packages/xwayland-satellite/PKGBUILD:9-11` ("a later official release sorts above it") only when no APT pin overrides it (§2.5).
- ryotunes carries `epoch=1` (`release/repo/import-ryotunes.sh:15-22`); Debian form `1:1.2.1-1`.
- pacman's `-debug` companions (`release/repo/build-repo.sh:136-151`) correspond to dh's `-dbgsym` `.ddeb` files; `DEB_BUILD_OPTIONS=noddebs` suppresses them.

### 1.4 Arch-to-Debian path and mechanism map (applies to every recipe)

| Arch | Debian/Ubuntu | Where it bites (cite) |
|---|---|---|
| `/usr/lib/qt6/qml/<Module>` | `/usr/lib/x86_64-linux-gnu/qt6/qml/<Module>` (Qt's `QT_INSTALL_QML`) | `ryoku-blobs/PKGBUILD:33-37`, `ryoku-desktop/PKGBUILD:324-349`, `ryoku-desktop-hyprland/PKGBUILD:87-88`; hardcoded readers: `ryoku/shell/ipc/daemon.go:411`, `installation/tests/container-install.sh:184-185`, `bin/ryoku-dev-lint-qml:28`, comments `ryoku/shell/environment.d/ryoku-session.conf:11`, `ryoku/hyprland/modules/env.lua:67`, `ryoku/shell/deploy.sh:523` |
| 18 git symlinks into `/usr/lib/qt6/qml/Qt5Compat/GraphicalEffects/*.qml` | target must become `/usr/lib/x86_64-linux-gnu/qt6/qml/Qt5Compat/GraphicalEffects/*.qml` | `ryoku/lockscreen/qylock/quickshell-lockscreen/imports/QtGraphicalEffects/*.qml` (all 18 symlinks in the repo point at `/usr/lib/qt6`), copied verbatim by `ryoku-desktop/PKGBUILD:447`; dangling on Debian |
| `/usr/share/libalpm/hooks/*.hook` | dpkg maintainer scripts or dpkg file triggers | `ryoku-desktop/PKGBUILD:696-699` |
| `.install` scriptlets (`pre_install`, `post_upgrade`, ...) | `preinst`/`postinst`/`prerm`/`postrm` (first install = `postinst configure` with empty `$2`) | ryoku-desktop, ryoku-keyring, asusctl, game-devices-udev |
| `/usr/share/pacman/keyrings/` + `pacman-key --populate` | `/usr/share/keyrings/<name>.pgp` referenced by `Signed-By:`; no scriptlet | `ryoku-keyring/PKGBUILD:18-22`, `ryoku-keyring/ryoku-keyring.install:1-9` |
| `/usr/lib/initcpio/install/*` (mkinitcpio) | `/usr/share/initramfs-tools/hooks/*` (different API, rewrite) or dracut module | `ryoku-desktop/PKGBUILD:737-738` |
| `/usr/share/licenses/<pkg>/` | `debian/copyright` -> `/usr/share/doc/<pkg>/copyright` | most upstream recipes |
| Files under `/etc` in a package | automatic conffiles (dh_installdeb): kept on `remove`, deleted only on `purge`, prompt on upgrade when locally modified | `/etc/ryoku-release` (`ryoku-desktop/PKGBUILD:259-266`), `/etc/modules-load.d/ryoku-i2c.conf` (`:579-580`), `/etc/modules-load.d/99-ryoku-uinput.conf` (`:614-615`), `/etc/systemd/logind.conf.d/10-ryoku-lid.conf` (`:694-695`), `/etc/boot/hooks/post.d/45-ryoku-windows` (`:730-731`), limine stack `/etc/*` |
| `pacman --overwrite` adoption of unowned seeded files (`docs/updates.md:424-435`) | dpkg overwrites unowned non-conffile paths silently; an unowned file at a new conffile path triggers dpkg's interactive conffile prompt | same `/etc` files as above |
| udev rules reload | Debian `udev.triggers` only watches `hwdb.d` (`interest-noawait /usr/lib/udev/hwdb.d`, systemd 257.13-1~deb13u1 `debian/udev.triggers`), so packages shipping rules call `udevadm control --reload-rules` themselves | asusctl, game-devices-udev, ryoku-desktop |
| `update-desktop-database` / `gtk-update-icon-cache` in scriptlets | `desktop-file-utils` declares `interest-noawait /usr/share/applications` (Debian 0.28-1 `debian/triggers`); icon cache is refreshed by `gtk-update-icon-cache`'s trigger (verify for the chosen suite) | `ryoku-desktop/ryoku-desktop.install:12-19` |
| `systemctl --global enable` with marker files | `dh_installsystemduser` (`deb-systemd-helper --user`), which enables user units once and remembers a later `disable` | `ryoku-desktop/ryoku-desktop.install:178-208` |
| `/usr/lib/tmpfiles.d/*.conf` | same path; `dh_installtmpfiles` (compat >= 13) runs `systemd-tmpfiles --create` | `ryoku/PKGBUILD:36-37` |
| `wheel` group in polkit rules | Debian/Ubuntu admin group is `sudo`; `wheel` does not exist by default | 11 rules: `system/hardware/power/47-ryoku-power.rules:13` and the other 10 listed in Cross-cutting |
| `RUSTUP_TOOLCHAIN=stable` | ignored (no rustup); toolchain is `rustc`/`cargo` from the archive | xwayland-satellite, picker |
| `arch-meson` | `dh $@ --buildsystem=meson` (Debian prefix + multiarch libdir) | game-devices-udev, dualsensectl |
| `options=('!lto')`, `('!strip')`, `('!debug')` | `DEB_BUILD_MAINT_OPTIONS=optimize=-lto`, `override_dh_strip:`, `override_dh_dwz:` (dh_dwz fails on some Go binaries) | prowl-agent, ryomotion, gpk, limine stack |

### 1.5 Vendoring and offline builds

`sbuild` (Debian's clean-room builder) has no network by default; `pbuilder` likewise (`USENETWORK=no`). `dpkg-buildpackage` itself does not cut the network. Every recipe that fetches at build time needs one of: vendored sources inside the Debian source package (or component tarballs), or a build that is allowed network.

| Recipe | What it fetches at build today (cite) | Offline Debian technique |
|---|---|---|
| ryoku-shell, ryoku-hub, ryoku, ryoku-rashin | nothing: `-mod=vendor`, vendor trees present (`ryoku/shell/ipc`, `ryoku/hub/backend`, `ryoku/cli`, `ryoku/rashin/backend` all have `vendor/modules.txt`) | `GOFLAGS=-mod=vendor GOTOOLCHAIN=local GOCACHE=$(CURDIR)/debian/.gocache HOME=$(CURDIR)/debian/.home` in `debian/rules` (sbuild gives a non-existent `$HOME`) |
| ryogami | nothing (`ryoku/shell/ryogami/daemon/vendor` present) | same |
| ryoku-desktop-hyprland/-niri | nothing: `go build` in `ryoku/wm/<wm>` picks up `ryoku/wm/vendor` automatically | same |
| ryoku-desktop | Go helpers in `ryoku/apps/ryovm/{fetch,mon,remote}`, `ryoku/apps/ryostore/backend` have no requirements | same |
| ryoku-palette-bridge | none (no requirements) | same |
| build-repo.sh's `ryoku-manifest` | none (`ryoku/cli/vendor`) | same |
| prowl-agent | whole module graph, `GOFLAGS=-mod=mod` (`prowl-agent/PKGBUILD:36-46`); upstream `go.mod` requires `github.com/mattn/go-sqlite3 v1.14.45`, `github.com/asg017/sqlite-vec-go-bindings v0.1.6` | `go mod vendor` at packaging time (C sources of both cgo packages live in their package dirs, so vendoring carries them); ship `vendor/` as a component tarball `prowl-agent_<v>.orig-vendor.tar.xz` |
| hypr-dynamic-cursors, ryoku-hypr-plugins, hyprglass | unpinned git clone of default branch, then `git checkout` by `hyprpm.toml` at build (`hypr-dynamic-cursors/PKGBUILD:30,45-60`) | resolve the commit before the build (read the target suite's `hyprland-dev` version, grep `hyprpm.toml`), export that commit as the `.orig.tar.xz` |
| imgborders | nothing: `git clone` of the committed `imgborders.bundle` (`imgborders/PKGBUILD:38-39,55`) | keep the bundle in the source; Build-Depends `git` |
| ryoku-keysounds | mechvibes git at pinned commit (`ryoku-keysounds/PKGBUILD:32`) | component tarball `orig-mechvibes` |
| ryoku-oh-my-zsh | ohmyzsh git at commit `4b657407...` (`ryoku-oh-my-zsh/PKGBUILD:24-25`) | GitHub archive of that commit as `.orig` |
| ryoku-cursor-material | `rtgiskard/bibata_cursor` git at commit `f4ccfe8...` (`ryoku-cursor-material/PKGBUILD:35-42`) | component tarball |
| xwayland-satellite, picker, asusctl | `cargo fetch --locked` (`xwayland-satellite/PKGBUILD:35`, `hyprland-preview-share-picker/PKGBUILD:24`, asusctl builds `--locked` with network) | `cargo vendor` -> component tarball + `.cargo/config.toml` `[source.crates-io] replace-with = "vendored-sources"`, build with `--offline --frozen`. `dh-cargo` targets Debian-packaged crates and does not fit vendored builds |
| picker submodule | `hyprland-protocols` git (`hyprland-preview-share-picker/PKGBUILD:13-23`) | component tarball at the gitlink commit recorded in the picker commit |
| ryomotion | Node 22.22.1 tarball, `npm ci` (registry), Electron zip into `ELECTRON_CACHE`, electron-builder helpers (`ryomotion/PKGBUILD:33-58`) | component tarball of the Node binary; a networked prep step runs `npm ci --cache <dir>` and tars the npm cache and the Electron zip as components; build runs `npm ci --offline --cache` with `ELECTRON_CACHE` pointed at the unpacked component |
| limine-mkinitcpio-hook, limine-snapper-sync | upstream git tag, Gradle 9.6.1 zip, GraalVM CE JDK 25 tarball, Maven Central (jackson) and the GraalVM reachability-metadata zip; only the plugin is vendored (`release/gradle-offline/offline.init.gradle:6-9`, `limine-mkinitcpio-hook/PKGBUILD:26-35`) | component tarballs for Gradle and GraalVM; extend `release/gradle-offline/refresh.sh` to vendor every resolved artifact so `gradle --offline` works |
| fonts, cursors, firmware, gpk, blesh, xpadneo, dualsensectl, game-devices-udev, asusctl tarball | release asset by URL + checksum | `.orig.tar.*` (zip assets: repack or `Files-Excluded`/uscan `repack`) |

---

## 2. The [ryoku] repository

### 2.1 Layout today

One Cloudflare R2 bucket, served under one mount; `repo.ryoku.dev/stable/<key>` is bucket object `<key>` (the `stable` path segment is the mount, not the channel) (`.github/workflows/publish-repo.yml:3-11`, `ryoku/cli/internal/sys/release.go:15-28`, `docs/updates.md:280-291`):

| Bucket path | Meaning | Written by |
|---|---|---|
| `x86_64/` | stable channel (the URL every installed box has) | byte copy of a release directory on tag publish (`publish-repo.yml:367-373`) |
| `releases/<tag>/x86_64/` | one frozen release, never overwritten | tag publish; refused when it exists unless `force_release` (`publish-repo.yml:162-171`) |
| `releases/index.json` | release ledger (newest first, ISO images per variant) | `bin/ryoku-release-ledger` (`publish-repo.yml:413-427`) |
| `channels/testing/x86_64/` | testing channel | every push to `unstable-dev` (`publish-repo.yml:126-131`) |
| bucket root: `*.iso`, `*.iso.sig`, `*.iso.sha256`, `*.iso.json`, `*.iso.js`, `latest.json`, `latest.js`, `latest-cachyos.*`, `ryoku-release-key.pub.asc` | ISO downloads, served as `iso.ryoku.dev/stable/` | `build-iso-reusable.yml:417-454` |

Each `x86_64/` directory holds (`release/repo/build-repo.sh:2-13,206-253`): `*.pkg.tar.zst` + detached `*.sig` per package, `ryoku.db`/`ryoku.db.sig`/`ryoku.files`/`ryoku.files.sig` materialized as real files (R2 has no symlinks, `:219-228`), the versioned `ryoku.db.tar.gz` etc., `release.json` (`{"schema":1,"release","name","channel","version","commit","date"}`, `:233-239`), and `manifest.json` (every package of the release by lane, built by `ryoku/cli/cmd/ryoku-manifest`, `:241-253`).

### 2.2 Build rules today (`release/repo/build-repo.sh`)

1. Preflight: not root, `makepkg`, `repo-add`, `gpg`, secret key present (`:48-56`).
2. Wipe `<out>/x86_64` and rebuild the db from exactly this run's packages, never `repo-add --new` (`:62-67`).
3. **Immutable filenames**: before building, each recipe's `makepkg --packagelist` names are fetched from the mirror (`RYOKU_REPO_MIRROR`, default `https://repo.ryoku.dev/stable/x86_64`, `:125`); if every main package already exists there, the published bytes are adopted and re-signed instead of rebuilt (`:136-172`). After building, any filename the mirror already serves is replaced by the served bytes (`:175-197`). Reason: makepkg is not reproducible and a changed file under a live name broke clients with "Maximum file size exceeded" (issue #21, `:116-124`). This also makes a stable release a promotion of the testing bytes.
4. Retry each build 3x with backoff for flaky VCS hosts (`:99-114`).
5. Import ryotunes from its GitHub release (`:199-204`), verify every package has a `.sig` (`:206-211`).
6. `repo-add -s -k "$KEY_ID" ryoku.db.tar.gz *.pkg.tar.zst` (`:213-217`); materialize symlinks (`:219-228`); write `release.json` and `manifest.json` (`:233-253`).

Env knobs: `RYOKU_REPO_OUT`, `RYOKU_REPO_KEY` (default fingerprint `EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3`, `:37`), `RYOKU_REPO_NAME`, `RYOKU_REPO_ARCH`, `RYOKU_PACKAGES_DIR`, `RYOKU_REPO_MIRROR`, `RYOKU_PKGVER`, `RYOKU_RELEASE`, `RYOKU_CHANNEL` (`:25-30,83-97,125`).

### 2.3 Signing today

- Key: ed25519, fingerprint `EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3`, UID `Ryoku Releases <releases@ryoku.dev>`, created 2026-06-20, expires 2031-06-19 (`gpg --show-keys keys/ryoku-release-key.pub.asc`; same bytes as `release/packages/ryoku-keyring/ryoku.gpg`). README copy: `release/packages/ryoku-keyring/README.md:22-23`.
- CI: private key from secret `GPG_PRIVATE_KEY`, written to a 0600 file in `$RUNNER_TEMP`, imported into an ephemeral `GNUPGHOME` with `allow-loopback-pinentry` + `pinentry-mode loopback` (passphraseless), consumed by `build-repo.sh` as an unprivileged `builder` user, file deleted (`publish-repo.yml:200-247`). ISO signing uses the same secret plus optional `GPG_PASSPHRASE` (`build-iso-reusable.yml:377-403`).
- Every package gets a detached `.sig`; the db is signed (`repo-add -s`). `SigLevel = Required` on clients (`installation/backend/lib/deploy.sh:62-77`).
- `ryoku-keyring` ships `ryoku.gpg`, `ryoku-trusted` (`EB6D...D6E3:4:`), empty `ryoku-revoked` into `/usr/share/pacman/keyrings/` (`ryoku-keyring/PKGBUILD:15-22`); `post_install`/`post_upgrade` run `pacman-key --populate ryoku` (`ryoku-keyring.install:1-9`). The installer seeds the same three files, populates, then deletes the seeds so the package can own them without a file conflict (`installation/backend/lib/deploy.sh:92-115`).

### 2.4 Channels and how a client picks one today

- The channel IS the `Server` line of the `[ryoku]` stanza in `/etc/pacman.conf`; there is no other state (`ryoku/cli/internal/sys/release.go:26-27`). `ChannelServer`: stable `RepoBase/$arch`, testing `RepoBase/channels/testing/$arch`, tag `RepoBase/releases/<tag>/$arch` (`release.go:53-65`); `ChannelOfServer` maps back and returns "" for foreign mirrors (`release.go:67-90`); release tags must match `^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$` (`release.go:47`).
- Installer writes `[ryoku] SigLevel = Required, Server = https://repo.ryoku.dev/stable/$arch` (`installation/backend/lib/deploy.sh:62-77`).
- `ryoku track stable|testing|v<tag>` rewrites the line and force-refreshes dbs; `ryoku rollback --to v<tag>` is track onto a frozen release; targets are repo-qualified `ryoku/<pkg>` so pacman prefers [ryoku] over `extra` and downgrades (`docs/updates.md:101-104,319-339`).
- `ryoku status` reads `release.json` from `ChannelURL` (`release.go:92-96`, `docs/updates.md:336-337`); `/etc/ryoku-release` names the installed release (`release.go:39-41`, `ryoku-desktop/PKGBUILD:254-266`).
- Branch model: `unstable-dev` -> testing on every push; `main` advances only by fast-forward and publishes nothing; a release is a `v*` tag cut by the Stable Release workflow (`docs/updates.md:307-317`).

### 2.5 Debian equivalent

#### 2.5.1 What maps 1:1

| Arch concept | Debian concept |
|---|---|
| `ryoku.db` + `ryoku.db.sig` | `dists/<suite>/InRelease` (inline-signed, so db and signature can never come from different builds, which removes the "invalid or corrupted database" class described at `publish-repo.yml:349-357`), plus `Release` + `Release.gpg` for old clients, and `main/binary-amd64/Packages{,.xz}` |
| per-package `.sig` | none: apt verifies `.deb` files only through the SHA256 in the signed `Packages` index (apt does not check `.deb` signatures; `debsigs`/`dpkg-sig` exist but apt ignores them) |
| `ryoku.files` | `Contents-amd64` (optional, `apt-ftparchive contents`) |
| `SigLevel = Required` | `Signed-By:` in the deb822 source; apt in trixie verifies with `sqv` (Sequoia) by default, which accepts ed25519 |
| `[ryoku]` repo-qualified targets (`ryoku/<pkg>`) | APT pinning by origin: `/etc/apt/preferences.d/ryoku.pref` with `Package: *`, `Pin: release o=Ryoku` (Origin field written into `Release`), `Pin-Priority: 1001` (priority > 1000 lets apt downgrade, which `ryoku rollback` needs) |
| "filenames are immutable once live" (`build-repo.sh:116-124`) | identical requirement: a `.deb` path in `pool/` whose bytes change under a published `Packages` makes apt fail with a hash mismatch; keep the adopt-published logic (fetch the served `.deb` for an unchanged `Package_Version_Arch`, verify, reuse) |
| `release.json`, `manifest.json` beside the db | keep them at the channel root (apt ignores unknown files); `ChannelURL` in `release.go:92-96` changes to that root |

#### 2.5.2 Tool options for building the index

| Option | Commands | State between CI runs | Frozen releases + stable pointer | Notes |
|---|---|---|---|---|
| **apt-ftparchive** (`apt-utils`: trixie 3.0.3, forky/sid 3.3.3, resolute 3.2.0) | `apt-ftparchive packages pool > dists/ryoku/main/binary-amd64/Packages`; `xz -k`; `apt-ftparchive -o APT::FTPArchive::Release::Origin=Ryoku -o ...::Label=Ryoku -o ...::Suite=<channel> -o ...::Codename=ryoku -o ...::Architectures=amd64 -o ...::Components=main release dists/ryoku > dists/ryoku/Release`; `gpg --clearsign -o InRelease Release`; `gpg -abs -o Release.gpg Release` | none (stateless, rebuilt from the directory like `build-repo.sh` does today) | a release directory is a complete repo root; the stable pointer is a byte copy, exactly today's model | closest to the current wipe-and-reindex design; no `by-hash` generation |
| **reprepro** (5.4.6+really5.3.2 in every suite, i.e. 5.3.2 code) | `conf/distributions` stanza per suite with `SignWith: <fpr>`; `reprepro includedeb <suite> *.deb`; `reprepro export` | `db/` and `pool/` must persist (or be rebuilt from the bucket each run) | one stanza per tag; copying a suite: `reprepro copymatched <tag> testing '*'` | 5.3.2 keeps one version per package per suite |
| **aptly** (1.6.1 trixie, 1.6.2 bpo/forky/sid/resolute) | `aptly repo add`, `aptly snapshot create <tag> from repo ryoku`, `aptly publish snapshot -distribution=<tag> <tag> s3:ryoku:`, `aptly publish switch stable s3:ryoku: <tag>` | `rootDir` (db + pool) must persist | native: immutable snapshots + atomic `publish switch` for the pointer | native S3 publishing (`S3PublishEndpoints` with custom endpoint for R2) and `-acquire-by-hash` |
| **dpkg-scanpackages flat repo** (prior art, `debian13-stripped/tools/build-debs.sh:793-795`) | `dpkg-scanpackages pool > Packages`, client `deb [trusted=yes] file:... ./` | none | n/a | unsigned; prior art uses it only for a local build repo |

#### 2.5.3 Hosting options

| Option | Fit | Constraint |
|---|---|---|
| S3-compatible bucket (R2 today) via `rclone` | identical to today; `bin/ryoku-r2-config:7-21` reusable with the human's endpoint/keys | upload order must become pool first, then `Packages`/`by-hash`, then `InRelease`/`Release`/`Release.gpg` last (the analogue of packages-first-db-last, `publish-repo.yml:349-363`) |
| GitHub Pages | static hosting with directory layout | Pages sites have a 1 GB published-size limit and git-backed files a 100 MB per-file limit; the Electron app `ryomotion` and the monorepo `ryoku-desktop` deb are the largest candidates (measure) |
| GitHub Releases, one flat repo per release tag | `deb [signed-by=...] https://github.com/<org>/<repo>/releases/download/<tag> ./` with `Packages`, `Release`, `InRelease` uploaded as assets; frozen releases map naturally onto tags | flat repos only (no `dists/`); apt follows the 302 to `objects.githubusercontent.com`; the mutable stable/testing pointers need moving tags |
| Own server (nginx) | any of the tools above in place | operations burden on the human |

#### 2.5.4 Suites, components and channel switching

Two designs reproduce "the channel is one line in one file":

- **D1. One repo root per channel (today's layout).** `<host>/stable/`, `<host>/channels/testing/`, `<host>/releases/<tag>/`, each a full repo with `dists/ryoku/` and its own `pool/`. Client switches channel by rewriting `URIs:`. `ChannelServer`/`ChannelOfServer` (`release.go:53-90`) keep their structure, only the file they edit changes. Pools are duplicated per channel, as the `x86_64/` dirs are today.
- **D2. One root, suite per channel.** `Suites: stable | testing | v0.75.5-beta.20`, one shared `pool/`. Blocker: `ryoku-desktop` is channel-specific (it embeds `CHANNEL=` in `/etc/ryoku-release`, and publish deliberately never adopts testing's copy for stable, `publish-repo.yml:178-191`), so the same `ryoku-desktop_<ver>_amd64.deb` name would need two different byte contents in one pool. D2 requires either a per-channel version suffix for ryoku-desktop or moving `CHANNEL=` out of the package.

Component: `main` only. Architectures: `amd64` (+ `all`).

#### 2.5.5 Client sources (deb822) and pin

`/etc/apt/sources.list.d/ryoku.sources` (D1, stable):

```
Types: deb
URIs: https://<repo-host>/stable/
Suites: ryoku
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/ryoku-archive-keyring.pgp
```

`/etc/apt/preferences.d/ryoku.pref`:

```
Package: *
Pin: release o=Ryoku
Pin-Priority: 1001
```

This file must be written by the installer and by `ryoku track`, not shipped in a package: a packaged sources file is a conffile, and every `ryoku track` rewrite would turn it into a locally-modified conffile that prompts on the next keyring upgrade.

#### 2.5.6 The signed-by keyring package

`ryoku-archive-keyring` (renamed from `ryoku-keyring`; `Provides: ryoku-keyring` keeps the old name resolvable):

```
Source: ryoku-archive-keyring
Section: misc
Priority: optional
Build-Depends: debhelper-compat (= 13)
Package: ryoku-archive-keyring
Architecture: all
Depends: ${misc:Depends}
Provides: ryoku-keyring
Description: Ryoku release signing key for the [ryoku] apt repository
```

`debian/install`: `ryoku-archive-keyring.pgp usr/share/keyrings/`. No maintainer scripts (no populate step). The installer can drop the same file before the first `apt-get update`; dpkg then adopts the unowned non-`/etc` file silently (unlike pacman, `deploy.sh:114` deletes seeds to avoid a conflict). Rotation: ship old+new keys concatenated in the one `.pgp` file for one release cycle, then drop the old key (the equivalent of `ryoku-revoked`, `ryoku-keyring/README.md:15-20`).

#### 2.5.7 Equivalent of build-repo.sh (stateless apt-ftparchive variant, D1)

1. `rm -rf out/<channel>` ; `mkdir -p out/<channel>/pool/main out/<channel>/dists/ryoku/main/binary-amd64`.
2. For each source package: if every `Package_Version_Arch.deb` its `debian/control` + version would produce already exists on the mirror (the analogue of `makepkg --packagelist`: `dpkg-architecture` + the computed version give the filenames), fetch it and verify with `dpkg-deb --info`; else build (`dpkg-buildpackage -b -uc -us` or `sbuild`), with the same 3x retry.
3. Byte-adoption pass for any built filename already served (same logic as `build-repo.sh:179-197`, `cmp` + replace).
4. Import ryotunes as a `.deb` (only if the human's ryotunes fork publishes one; §Q).
5. `apt-ftparchive packages`, `release`, sign `InRelease` + `Release.gpg`.
6. `release.json`, `manifest.json` at `out/<channel>/` (unchanged generator).
7. Verify step (the analogue of `publish-repo.yml:375-411`): for every `Filename:` in the served `Packages`, the bucket holds the object at `Size:`.

---

## 3. CI workflows

### 3.1 Release and publish workflows (core of this scope)

#### publish-repo.yml
- **Trigger:** push to `unstable-dev`, push of `v*` tags, `workflow_dispatch` with `force_release` (`.github/workflows/publish-repo.yml:24-36`). Concurrency per channel, testing runs cancel each other, stable never (`:50-52`).
- **Jobs:** `build` in `archlinux:latest` (`:63-71`): secrets check (`:77-95`), `pacman -Sy git` (`:99-100`), full-history checkout (`:102-108`), channel resolution (tag -> stable/`releases/<tag>`, `unstable-dev` -> testing/`channels/testing` with version `bin/ryoku-release-version --channel unstable-dev`, anything else refused) (`:110-137`), `pacman -Syu` of `build-toolchain.packages` + rclone (`:139-148`), snapshot published packages into `.published-mirror` from the bucket (stable: release dir, stable pointer, testing minus `ryoku-desktop-*`) (`:150-192`), `bin/ryoku-dev-verify-pkgbuild-deps` (`:194-198`), build+sign as `builder` with the key in an ephemeral GNUPGHOME (`:200-247`), upload artifact (`:249-257`). `container-install` matrix `[arch, cachyos]` (`:265-310`): `pacman-key --init/--populate archlinux [cachyos]`, fallback `pacman-key --recv-keys F3B607488DB35A47` (`:284-299`), then `installation/tests/container-install.sh` with `RYOKU_PREBUILT_REPO=1`. `publish` in `archlinux:latest` (`:312-450`): `pacman -Syu rclone jq libarchive github-cli` (`:326-328`), rclone upload packages first, db last, then `rclone sync` prune (`:341-373`), verify every db entry exists at size with `.sig` (`:375-411`), ledger (`:413-427`), dispatch `build-iso.yml` + `build-iso-cachyos.yml` with `repo_url=https://repo.ryoku.dev/stable/$PREFIX/x86_64` (`:429-450`). `notify-failure` Discord (`:458-482`).
- **Arch-specific:** `archlinux:latest` x2 + `cachyos/cachyos:latest`, every `pacman`/`pacman-key` line, `makepkg`/`repo-add` via `build-repo.sh`, bsdtar parsing of pacman `desc` files in verify (`:389-405`), the CachyOS gate leg, the PKGBUILD dep gate.
- **Debian replacement:**
  1. `build`: `container: image: debian:trixie` (or `debian:forky` / `ubuntu:26.04` per target base). `apt-get update && apt-get install -y --no-install-recommends git ca-certificates` before checkout.
  2. Toolchain: `release/repo/build-toolchain.packages` rewritten to Debian names (list in §3.4) plus `devscripts equivs dpkg-dev debhelper apt-utils gnupg rclone`; on trixie add `trixie-backports` to `/etc/apt/sources.list.d/` and install `golang-1.26-go` (or `golang-go/trixie-backports`, 1.27) and, if crate MSRVs require it, `rustc/trixie-backports` (1.96.1).
  3. Per source: `mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control`, then `dpkg-buildpackage -b -uc -us` as a non-root user (`dpkg-buildpackage` does not refuse root like makepkg, but `fakeroot` + non-root keeps parity). `sbuild --chroot-mode=unshare` needs user namespaces, which the default Docker seccomp profile inside a job container blocks; run it on the bare `ubuntu-latest` host or with `docker run --privileged`.
  4. Replace `bin/ryoku-dev-verify-pkgbuild-deps` with a Debian check: `dose-distcheck` over the built `Packages` plus the target suite's `Packages` (runtime `Depends`), `dpkg-checkbuilddeps` for `Build-Depends`.
  5. Snapshot step: fetch served `.deb`s instead of `.pkg.tar.zst` (same rclone filters; exclude `ryoku-desktop_*`).
  6. Gate: matrix `[trixie, forky, resolute]` with `debian:trixie`/`debian:forky`/`ubuntu:26.04`; a Debian `container-install.sh` writes the deb822 source with `Signed-By:` the CI public key, runs `apt-get update && apt-get install -y ryoku-desktop`, ownership checks with `dpkg -S`/`dpkg -L`/`dpkg-query -W`. The CachyOS leg and the `oh-my-zsh-git` provides guard (`container-install.sh:83-92`) have no Debian counterpart.
  7. `publish`: `debian:trixie` container or bare `ubuntu-latest` (`apt-get install rclone jq libarchive-tools gh`); upload order pool -> `Packages*` -> `InRelease`/`Release*`; verify by parsing `Packages` (`Filename:`/`Size:`) instead of pacman `desc`.
  8. Dispatch the Debian ISO workflow with `repo_url=https://<repo-host>/releases/<tag>/`.

#### stable-release.yml
- **Trigger/what:** dispatch on `main` with `bump_type` none|patch|minor|major and `release_stage` keep|alpha|beta|stable (`.github/workflows/stable-release.yml:3-25,38`); computes version (`bump none` tags `VERSION` as is, `:61-74`), refuses existing tag (`:77-80`), commits `release: <tag>` + annotated tag (`:97-110`), dispatches `publish-repo.yml` on the tag because a `GITHUB_TOKEN` tag push does not trigger workflows (`:112-126`), dispatches `release-notes.yml` (`:128-142`).
- **Runner:** ubuntu-latest, git only. **Arch coupling:** none. NEUTRAL. Bot identity `github-actions[bot]` (`:52-53`).

#### unstable-version-bump.yml
- **Trigger/what:** push to `unstable-dev` (`:10-12`); unless the push hand-edited `VERSION`, `bin/ryoku-release-bump roll keep` (patch+1, carry to minor after 9, `bin/ryoku-release-bump:24-30`), commit `release: bump unstable to <v>`, rebase, push (`:32-65`). The recent history (`98a036825 release: bump unstable to 0.75.5-beta.20`) is this bot.
- NEUTRAL (ubuntu-latest, git).

#### release-channel-versions.yml
- **Trigger/what:** PR/push to `main`/`unstable-dev` touching `VERSION` or the release scripts, dispatch (`:3-20`); validates version shapes with regexes (`:44-52`); on `unstable-dev` pushes force-moves tag `unstable-dev-latest` (`:68-95`).
- NEUTRAL. The regex `^v[0-9]+\.[0-9]+\.[0-9]+.*\.dev\.[0-9]+\+g...` (`:50`) is Debian-safe as a display string; the Debian package version uses `--pkgver` form instead (§1.3).

#### release-notes.yml
- **Trigger/what:** push `unstable-dev` or `v*`, dispatch (`:15-33`); stable: `bin/ryoku-release-notes <prev-tag> <tag>`, title from `CODENAME`, intro from `release/names.md` on a new line (`:87-117`), `gh release create/edit`, Discord embed with brand images from `raw.githubusercontent.com/$GITHUB_REPOSITORY/main/ryoku/assets/brand` (`:119-168`); unstable: rolling `unstable` pre-release recreated every bump (`:169-181`).
- NEUTRAL (ubuntu-latest). CREATOR-ONLY part: `DISCORD_WEBHOOK_URL` (`:48`), footer text "Ryoku Arch : For the sake of power and beauty." (`:128`). Media URLs derive from `GITHUB_REPOSITORY` (`bin/ryoku-release-notes:29-30,67-68`, `release/media/README.md:5-9`), so they re-point automatically on a fork.

#### release-ledger.yml
- **Trigger/what:** dispatch only (`:9-10`); in `archlinux:latest` installs git, rclone, jq with pacman (`:20-30`), runs `bin/ryoku-r2-config` and `bin/ryoku-release-ledger "Ryoku:$R2_BUCKET"` (`:31-49`).
- ARCH-COUPLED only by container choice. Debian: `container: image: debian:trixie`, `apt-get install -y git rclone jq ca-certificates` (or bare ubuntu-latest). `bin/ryoku-release-ledger` itself reads `releases/<tag>/x86_64/release.json` (`bin/ryoku-release-ledger:92-101`) and writes `repo: releases/<tag>/x86_64` (`:99-100`); in layout D1 the path drops `x86_64/`.

#### refresh-ryotunes.yml (+ `release/repo/refresh-ryotunes.sh`, `release/repo/import-ryotunes.sh`)
- **Trigger/what:** hourly cron `17 * * * *`, dispatch, after a successful publish (`.github/workflows/refresh-ryotunes.yml:5-11`); matrix stable/testing sharing the publish concurrency lock (`:22-30`); `archlinux:latest`, `pacman -Syu git curl jq libarchive gnupg rclone diffutils` (`:31-35`); runs `refresh-ryotunes.sh`.
- `refresh-ryotunes.sh`: maps channel to bucket path (`refresh-ryotunes.sh:9-13`), downloads and gpg-verifies `ryoku.db` (`:25-27`), reads the installed ryotunes version from db `desc` (`:28-36`), `RYOKU_IMPORT_RESOLVE_ONLY=1 import-ryotunes.sh` and `vercmp` (`:38-42`), imports and signs, `repo-add --sign`, uploads package then db aliases, re-verifies (`:44-81`).
- `import-ryotunes.sh`: GitHub `releases/latest` of `ryoku-dev/ryotunes` (`:46,75-81`), strict asset match `ryotunes-<ver>-<rel>-x86_64.pkg.tar.zst` (`:83-95`), sha256 sidecar parsing (`:119-134`), `.PKGINFO` identity and epoch=1 check (`:136-147`), sign (`:149-161`).
- **Arch-specific:** container, pacman, `repo-add`, `vercmp`, `.PKGINFO`, `.pkg.tar.zst` asset contract.
- **Debian replacement:** the upstream release today has assets `ryotunes-1.2.1-1-x86_64.pkg.tar.zst`, `.sha256`, `ryotunes-1.2.1.tar.gz`, `.sha256` (no `.deb`; `gh api repos/ryoku-dev/ryotunes/releases/latest`). Steps: (1) the ryotunes repo's release job additionally builds a `.deb` (its `packaging/arch/PKGBUILD` builds with `cargo` + `pnpm` + `nodejs`; Debian build-deps `cargo rustc libwebkit2gtk-4.1-dev libayatana-appindicator3-dev libssl-dev libmpv-dev appmenu-gtk3-module xdotool nodejs`, pnpm not in Debian so fetched via corepack or a vendored tarball); (2) importer matches `ryotunes_<ver>-<rel>_amd64.deb`, checks `dpkg-deb -f Package Version Architecture` (`Version: 1:<ver>-<rel>`) instead of `.PKGINFO`; (3) refresh adds the deb to the channel's pool and regenerates `Packages`/`InRelease` (apt-ftparchive) or `aptly repo add` + `publish update`; `vercmp` -> `dpkg --compare-versions`; container `debian:trixie` with `apt-get install git curl jq libarchive-tools gnupg rclone diffutils dpkg-dev apt-utils`.

#### build-iso.yml / build-iso-cachyos.yml / build-iso-reusable.yml
- **Trigger:** plain: dispatch (`release_stage`, `repo_url`) or `v*` tag (`.github/workflows/build-iso.yml:7-26`); cachyos: dispatch or `cachyos-v*` tag (`build-iso-cachyos.yml:10-29`); both call the reusable one (`build-iso.yml:33-40`).
- **Reusable:** `preflight` on ubuntu-latest with setup-go (from `installation/tui/go.mod`) and apt shellcheck, runs `installation/tests/iso-preflight.sh` (`build-iso-reusable.yml:37-75`); `build` frees disk (`:145-153`), runs `docker run --privileged archlinux:latest` with `pacman -Sy archlinux-keyring`, `pacman -Su archiso git go base-devel cmake ninja qt6-base qt6-declarative qt6-shadertools qt6-multimedia hyprcursor xcur2png` (`:176-199`), builds `ryoku-cursors` locally with makepkg + `repo-add` into `/tmp/ryoku-localrepo` because Cloudflare 403s runner IPs (`:203-217`), `iso-stage-check.sh` reproducibility gate (`:218-223`), `installation/iso/build.sh` (mkarchiso) (`:224`); renames to `ryoku-<date>-r<run>-<sha>-x86_64-<ref>[-cachyos].iso` (`:237-253`); mounts ISO + `airootfs.sfs`, checks `/usr/share/ryoku/.payload` commit and variant (`:255-317`); Trivy SARIF + blocking scan skipping `var/cache/pacman/pkg` (`:319-356`); gpg detached signature + exported pubkey (`:377-403`); `bin/ryoku-iso-manifest` (`:405-411`); rclone via the upstream install script (`:413-415`), upload to bucket root with `latest*.json` no-cache (`:417-454`); Discord notify (`:467-539`).
- **Arch-specific:** `archlinux:latest`, archiso/mkarchiso, pacman, makepkg, repo-add, `airootfs` squashfs naming, `var/cache/pacman/pkg` skip, the whole CachyOS variant.
- **Debian replacement:** Debian `live-build` (trixie 1:20250505, forky/sid 1:20250814; Ubuntu's `live-build` is 3.0~a57, unusable for resolute) or the prior-art mmdebstrap + mksquashfs + grub-mkrescue pipeline (`/home/me/src/debian13-stripped/build-iso.sh:3-13,33-34,67-69`, `/home/me/src/Debian13-Hyprland/tools/build-iso.sh`), run in `docker run --privileged debian:trixie` (or directly on the runner); squashfs name `live/filesystem.squashfs` (live-boot) replaces `*airootfs*.sfs` in the Trivy mount step (`:272-283`); Trivy `skip-dirs` `var/cache/pacman/pkg` -> `var/cache/apt/archives`; the local cursors build becomes `dpkg-buildpackage` of ryoku-cursors into a local apt repo (or the repo is fetched from the bucket directly as publish already does). `build-iso-cachyos.yml` has no Debian analogue (it bakes `linux-cachyos`, CachyOS settings and schedulers, `build-iso-cachyos.yml:3-9`). ISO internals are owned by the installation/ISO report.

### 3.2 All other workflows (detail in the per-workflow table)

All 38 remaining workflows were read. 35 already run on `ubuntu-latest` without a container and install tools with `apt-get`; the Arch coupling sits in the scripts they test or the files they parse.

| Workflow | Trigger | What it does (cite) | Arch coupling (cite) | Class | Debian change |
|---|---|---|---|---|---|
| ai-slop.yml | PR, push main, dispatch | `bin/ryoku-dev-scan-slop --range` (`:71`) | none | NEUTRAL | none |
| bluetooth-audio.yml | PR/push on wireplumber paths | apt `jq`, `pipewire-bin wireplumber`; `tests/bt-audio-codec.sh`, `tests/bluetooth-audio-policy.sh` (`:48-61`) | none | NEUTRAL | none |
| cobalt-setup.yml | PR/push `system/containers/**` | `tests/cobalt-setup.sh` (`:43`) | none | NEUTRAL | none |
| codeql.yml | push/PR main, weekly | CodeQL actions + JS/TS (`:27-31`) | none | NEUTRAL | none |
| commit-notifications.yml | push main/unstable-dev | Discord commit batches, state in `refs/notify/commits/<branch>` (`:34,59-65,100-108`) | none | CREATOR-ONLY | set `DISCORD_COMMIT_WEBHOOK_URL` or leave (self-skips, `:51-54`) |
| controllers.yml | PR/push input/package paths | `tests/controllers.sh` (`:67`) | reads `system/packages/{base,aur}.packages` (`tests/controllers.sh:27-28`), `pacman -Si` probe (`:74`), path triggers on 4 `release/packages/*` dirs (`.github/workflows/controllers.yml:29-32`) | ARCH-COUPLED | probe with `apt-cache show` inside `debian:trixie`; retarget paths |
| cursor-recolor.yml | PR/push main | `tests/cursor-recolor.sh` (`:38`) against `release/packages/ryoku-cursor-material/ryoku-cursor-material-recolor` (`:13`) | path only | NEUTRAL | retarget path if packaging tree moves |
| delivery-check.yml | push unstable-dev/main, PR | `bin/ryoku-dev-verify-delivery` (`:33`), main lag warning (`:39-41`) | delivery sources are `release/packages/*/PKGBUILD` (`bin/ryoku-dev-verify-delivery:25`) | ARCH-COUPLED | add `debian/*.install`, `debian/rules`, `debian/*.links` to `sources=` |
| discord-notifications.yml | issues, `pull_request_target`, dispatch | Discord embeds (`:86-180,227-334`) | none | CREATOR-ONLY | set `DISCORD_WEBHOOK_URL` or leave |
| docs-sync.yml | PR/push `**/*.md` | relative-link check (`:36-63`) | none | NEUTRAL | none |
| game-mode.yml | PR/push | `tests/game-tune.sh`, `tests/game-mode.sh` (`:56-60`) | none | NEUTRAL | none |
| go-unit-tests.yml | PR/push Go paths | build/vet/test 7 modules (`:46-197`) | none | NEUTRAL | none |
| gpu-tooling.yml | PR/push | `tests/gpu-pin-policy.sh`, `gpu-mux.sh`, `gpu-lib32.sh` (`:49-57`) | `gpu-lib32.sh` asserts `[multilib]` lib32 packages (`tests/gpu-lib32.sh:2-14`) | ARCH-COUPLED | `dpkg --add-architecture i386` + `mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386 libvulkan1:i386` |
| i18n.yml | push `beta-18`/`unstable-dev`, dispatch | `ryoku/i18n/tools/sync.py` extract/sync, commits catalog (`:69-101`) | none (OpenRouter `RYOKU_I18N_KEY` optional, keyless fallback `:61,74-75`) | NEUTRAL | none |
| inclusive-language.yml | PR/push text | `go install woke@v0.19.0` (`:63`), scan (`:135`) | none | NEUTRAL | none |
| install-backend-tests.yml | PR/push installer/boot/packaging paths | 18 unit tests, 4 loop-device tests, TUI `go test`, KVM chainload (`:140-345`) | tests source the Arch backend (pacstrap, mkinitcpio, limine, pacman hooks; per-test list in the installation report); apt `limine` at `:327` does not exist in any Debian/Ubuntu suite (only runs on KVM runners `:310-315`); path triggers `release/packages/*/PKGBUILD`, `release/gradle-offline/**` (`:46-48`) | ARCH-COUPLED | rewrite tests with the Debian backend; build limine or drop the job |
| install-chroot-safety.yml | PR/push backend | `tests/install-chroot-safety.sh` (`:35`) | none in test | NEUTRAL | none |
| install-mirrors.yml | PR/push backend | `tests/install-mirrors.sh` (`:35`) | reflector + Arch mirror-status JSON + pacman.conf (`tests/install-mirrors.sh:3-6`) | ARCH-COUPLED | rewrite for `deb.debian.org`/netselect-apt + InRelease probe (prior art `/home/me/src/debian13-stripped/installer/engine.sh:359-365`) |
| install-test.yml | dispatch, weekly, after Build ISO | container tier `archlinux:latest`/`cachyos/cachyos:latest` (`:34,39`); VM tier `docker run archlinux:latest` repo build (`:135-145`) + QEMU install (`:48-165`) | full Arch | ARCH-COUPLED | `debian:trixie`/`debian:forky`/`ubuntu:26.04` matrix; Debian container-install; VM tier against the live-build ISO |
| localsend-receive.yml | PR/push | `tests/localsend-receive.sh` (`:35`) | none | NEUTRAL | none |
| monitor-profiles.yml | PR/push | apt `jq lua5.4`, two tests (`:41-49`) | none | NEUTRAL | none |
| nvidia-guard.yml | PR/push | `tests/nvidia-guard.sh`, `tests/nvidia-driver-selection.sh` (`:41-45`) | guard runs from a pacman hook; stubs `pacman`, `pacman-conf`, `limine-mkinitcpio`, CachyOS kernel (`tests/nvidia-guard.sh:6,19-35`, `tests/nvidia-driver-selection.sh:21-42`) | ARCH-COUPLED | hook moves to `/etc/kernel/postinst.d/` or dkms; stubs `dpkg-query`, `update-initramfs` |
| project-auto-add.yml | issues/PR opened | add to Projects board (`:56`) | none | CREATOR-ONLY | `PROJECTS_TOKEN` + `vars.PROJECT_URL` or leave |
| project-roadmap-export.yml | cron 3h, dispatch, `repository_dispatch` | GraphQL board export (`:59-195`) | none | CREATOR-ONLY | org-owned board required (`:61`) |
| project-triage.yml | issues/PR | GitHub Models triage (`:143-155`) | none | CREATOR-ONLY | as above |
| pr-shell-script-alert.yml | PR | advisory annotation (`:38-139`) | none | NEUTRAL | none |
| qmllint.yml | PR/push `**/*.qml` | apt `qt6-declarative-dev`, `/usr/lib/qt6/bin/qmllint` (`:57,67`) | none: Debian ships qmllint at the same path via `qt6-declarative-dev-tools` | NEUTRAL | none |
| ryoku-recovery.yml | PR/push | `tests/ryoku-recovery.sh` (`:36`) | none | NEUTRAL | none |
| sddm-wayland.yml | PR/push | Go test + `tests/sddm-wayland.sh` (`:43-46`) | greps Arch names `qt5-wayland`, `qt6-5compat` in `base.packages` and the ryoku-desktop PKGBUILD (`tests/sddm-wayland.sh:11-15`) | ARCH-COUPLED | grep `qtwayland5`, `qml6-module-qt5compat-graphicaleffects` in `debian/control` |
| shellcheck.yml | PR/push shell | apt shellcheck (`:64-74`), scan (`:154`) | none | NEUTRAL | none (also covers `debian/*.postinst` if they are bash) |
| shell-ipc-parity.yml | PR/push | `bin/ryoku-dev-audit-shell-binds --check` (`:38`) | none | NEUTRAL | none |
| shell-tool-availability.yml | PR/push package lists | `tests/shell-tool-availability.sh` (`:38`) | Arch names + PKGBUILD layout (`tests/shell-tool-availability.sh:9-15,28-29,69-106`) | ARCH-COUPLED | read `debian/control` and Debian package lists; rename map entries (`zbar`->`zbar-tools`, `libqalculate`->`qalc`, `tesseract`->`tesseract-ocr`) |
| shell-unit-tests.yml | PR/push JS | `tests/shell-unit-tests.sh` (`:48`) | none | NEUTRAL | none |
| snapshot-cleanup.yml | PR/push | apt `snapper btrfs-progs`, loop-btrfs test (`:41-45`) | none | NEUTRAL | none |
| stash-install.yml | PR/push | apt `libarchive-tools`, `tests/stash-install.sh` (`:34-38`) | script routes `.pkg.tar.*` to `pkexec pacman -U`, extracts `.deb` into `~/.local` (`ryoku/shell/scripts/stash-install.sh:4-5,40-58,158-159`) | ARCH-COUPLED | route `.deb` to `pkexec apt-get install ./file.deb`; stub `apt-get` |
| trivy.yml | push/PR main, weekly | Trivy fs (`:28-72`) | skip-dirs name archiso dirs `installation/iso/{out,work,staging}` (`:39,58,71`) | NEUTRAL | update skip-dirs to the live-build dirs |
| wayland-session-settle.yml | PR/push | `tests/wayland-session-settle.sh` (`:40`) | none | NEUTRAL | none |

Totals for these 38: NEUTRAL 22, ARCH-COUPLED 11 (controllers, delivery-check, gpu-tooling, install-backend-tests, install-mirrors, install-test, nvidia-guard, refresh-ryotunes, sddm-wayland, shell-tool-availability, stash-install), CREATOR-ONLY 5. All five CREATOR-ONLY workflows self-skip when their secret/var is missing (`commit-notifications.yml:51-54`, `discord-notifications.yml:54-57`, `project-auto-add.yml:40-50`, `project-roadmap-export.yml:46-53`, `project-triage.yml:47-54`).

Arch-irrelevant/neutral overall (no change for a Debian port): ai-slop, bluetooth-audio, cobalt-setup, codeql, cursor-recolor (path only), docs-sync, game-mode, go-unit-tests, i18n, inclusive-language, install-chroot-safety, localsend-receive, monitor-profiles, pr-shell-script-alert, qmllint, ryoku-recovery, shell-ipc-parity, shell-unit-tests, snapshot-cleanup, shellcheck, trivy (skip-dirs only), wayland-session-settle, stable-release, unstable-version-bump, release-channel-versions, release-notes.

### 3.3 Git hooks and CONTRIBUTING

Hooks only run after `git config core.hooksPath .githooks`; nothing in the repo sets it (no `hooksPath` string anywhere), while `CONTRIBUTING.md:118` and `docs/development.md:134` say every commit passes them.

| Hook | Gate (cite) | Tools | Arch coupling | Debian change |
|---|---|---|---|---|
| commit-msg | `[global\|installation\|system\|ryoku\|docs\|test\|tooling\|release]` prefix, <= 72 chars, no trailing period, no em-dash, no AI attribution, `Note: New\|Fixed\|Removed:` format (`.githooks/commit-msg:26-69`) | none | none | none |
| pre-commit | em-dash scan, `bash -n` on staged scripts, filler comments, delivery, wm isolation (`.githooks/pre-commit:23-66`) | `bin/ryoku-dev-scan-slop`, `bin/ryoku-dev-verify-delivery`, `bin/ryoku-dev-verify-wm-isolation` | delivery verifier knows only PKGBUILDs (`bin/ryoku-dev-verify-delivery:25`); message "ship it from a PKGBUILD" (`.githooks/pre-commit:62`) | add Debian delivery files to `sources=`; extensionless `debian/control`/`rules`/`changelog` are not matched by the em-dash file regex (`.githooks/pre-commit:23`) |
| pre-push | no force-push to main (`:30-42`), shellcheck if installed (`:47-67`), subjects <= 72 (`:74-91`), PKGBUILD deps when `release/packages/**/PKGBUILD` changes (`:99-111`), wm vendor drift (`:117-129`) | `bin/ryoku-dev-verify-pkgbuild-deps`, `bin/ryoku-dev-verify-wm-vendor` | `ryoku-dev-verify-pkgbuild-deps` exits 0 with a notice when `pacman` is absent (`bin/ryoku-dev-verify-pkgbuild-deps:32-35`), reads `/var/lib/pacman/sync/*.db` (`:43-49`), sources PKGBUILDs (`:60-68`), `pacman -Si` (`:76`), hardcodes `ryotunes` internal (`:63-64`): on a Debian box this gate checks nothing today | replace with `dose-distcheck`/`dpkg-checkbuilddeps` (dose-distcheck in trixie 7.0.0), trigger on `debian/control` changes |
| post-commit | delivery report (`.githooks/post-commit:6`) | `bin/ryoku-dev-verify-delivery` | as pre-commit | as pre-commit |

`CONTRIBUTING.md` Arch couplings: dev loop "a running Ryoku machine, or Arch running Hyprland or niri" (`CONTRIBUTING.md:40`); package sets `base/dev/hardware/aur`, "Prefer the official repositories over the AUR" (`:55-57`); releases via Stable Release with `bump_type: none` (`:147-149`); creator issue/discussion links (`:168-171`).

### 3.4 Debian build toolchain list (replacement for `release/repo/build-toolchain.packages`)

| Arch line (`build-toolchain.packages`) | Debian | trixie | trixie-bpo | forky | sid | resolute |
|---|---|---|---|---|---|---|
| base-devel (`:17`) | build-essential, fakeroot, dpkg-dev, debhelper | 12.12 / - / 1.22.22 / 13.24.2 | - / - / - / 14.5 | 12.12 / 1.23.11 / 14.5 | 12.12 / 1.23.11 / 14.5 | 12.12ubuntu2 / 1.23.7 / 13.31 |
| git (`:18`) | git | 2.47.3 | - | 2.53.0 | 2.55.0 | 2.53.0 |
| go (`:25`) | golang-1.26-go (or golang-go) | - (golang-go 1.24) | 1.26.9 (golang-go 1.27) | 1.26.9 | 1.26.9 | 1.26.8 |
| rust (`:26`) | rustc, cargo | 1.85.1 | 1.96.1 | 1.96.1 | 1.97.1 | 1.93.1 |
| clang, llvm (`:27-28`) | clang, llvm, libclang-dev | 19 | - | 21.1.8 | 21.1.8 | 21.1.6 |
| cmake (`:29`) | cmake | 3.31.6 | 4.3.4 | 4.3.4 | 4.3.4 | 4.2.3 |
| ninja (`:30`) | ninja-build | 1.12.1 | - | 1.13.2 | 1.13.2 | 1.13.2 |
| meson (`:31`) | meson | 1.7.0 | - | 1.12.1 | 1.12.1 | 1.10.1 |
| gradle (`:32`) | not needed (recipes use the pinned 9.6.1 zip) | | | | | |
| libusb (`:33`) | libusb-1.0-0-dev | 1.0.28 | - | 1.0.30 | 1.0.30 | 1.0.29 |
| qt6-base (`:36`) | qt6-base-dev | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 |
| qt6-declarative (`:37`) | qt6-declarative-dev | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 |
| qt6-shadertools (`:38`) | qt6-shadertools-dev, qt6-shader-baker | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 |
| qt6-multimedia (`:39`) | qt6-multimedia-dev | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 |
| hyprland (`:45`) | hyprland-dev | - | 0.55.2 | 0.56.2 | 0.56.2 | 0.53.3 |
| hyprcursor (`:46`) | libhyprcursor-dev, hyprcursor-util | - | 0.1.13 | 0.1.13 | 0.1.13 | 0.1.13 |
| libcanberra (`:47`) | libcanberra-dev | 0.30 | - | 0.30 | 0.30 | 0.30 |
| pango, cairo, pixman (`:48-50`) | libpango1.0-dev, libcairo2-dev, libpixman-1-dev | 1.56.3 / 1.18.4 / 0.44.0 | - | 1.58.2 / 1.18.4 / 0.46.4 | same | 1.57.0 / 1.18.4 / 0.46.4 |
| libdrm, libinput, libxkbcommon (`:51-53`) | libdrm-dev, libinput-dev, libxkbcommon-dev | 2.4.124 / 1.28.1 / 1.7.0 | - / - / 1.13.1 | 2.4.134 / 1.31.3 / 1.13.1 | same | 2.4.131 / 1.31.1 / 1.13.1 |
| wayland, wayland-protocols (`:54-55`) | libwayland-dev, libwayland-bin, wayland-protocols | 1.23.1 / 1.44 | - / 1.47 | 1.26.0 / 1.49 | same | 1.24.0 / 1.47 |
| ffmpeg (`:56`) | libavcodec-dev, libavformat-dev, libavutil-dev, libswscale-dev, ffmpeg | 7.1.5 | - | 9.0.2 | 9.0.2 | 8.0.1 |
| pkgconf (`:57`) | pkgconf | 1.8.1 | - | 2.5.1 | 2.5.1 | 2.5.1 |
| gtk4, gtk4-layer-shell (`:58-59`) | libgtk-4-dev, libgtk4-layer-shell-dev | 4.18.6 / 1.0.4 | - | 4.24.1 / 1.3.0 | same | 4.22.4 / 1.3.0 |
| fish, jq (`:64-65`) | fish, jq | 4.0.2 / 1.7.1 | - | 4.9.3 / 1.8.2 | same | 4.2.1 / 1.8.1 |
| librsvg, xorg-xcursorgen, xcur2png (`:66-68`) | librsvg2-bin, x11-apps (xcursorgen), xcur2png | 2.60.0 / 7.7+11 / 0.7.1 | - | 2.63.2 / 7.7+11 / 0.7.1 | same | 2.61.3 / 7.7+11 / 0.7.1 |
| python (`:69`) | python3 | 3.13.5 | - | 3.14.7 | 3.14.7 | 3.14.3 |
| pnpm, nodejs (`:75-76`) | pnpm (not in Debian/Ubuntu), nodejs | - / 20.19.2 | - | - / 24.21.0 | - / 24.22.0 | - / 22.22.1 |
| gnupg (`:79`) | gnupg | 2.4.7 | - | 2.4.9 | 2.4.9 | 2.4.8 |
| webkit2gtk-4.1, mpv, libappindicator-gtk3 (`:82-84`) | libwebkit2gtk-4.1-dev, libmpv-dev, libayatana-appindicator3-dev | 2.52.6 / 0.40.0 / 0.5.94 | - | 2.52.6 / 0.41.0 / 0.5.94 | 2.54.1 / 0.41.0 / 0.5.94 | 2.52.6 / 0.41.0 / 0.5.94 |
| (new, Debian-only) | devscripts, equivs, apt-utils, lintian, unzip, libxcb1-dev, libxcb-cursor-dev, libudev-dev, libdbus-1-dev, libhidapi-dev | present in all suites (versions in the per-package sections) | | | | |
| rclone (publish only, `publish-repo.yml:148`) | rclone | 1.60.1 | - | - | 1.69.3 | 1.60.1 |

`build-toolchain.packages:71-84` still justifies pnpm/nodejs/webkit2gtk/libappindicator by "ryotunes' PKGBUILD", but `release/packages/` has no ryotunes recipe any more (ryotunes is imported, `build-repo.sh:199-204`).

---

## 4. Per-package sections

Notation in Dependencies tables: "same" = identical Debian name; versions trimmed.

### ryoku-keyring (`release/packages/ryoku-keyring/`)
**What it does:** ships the release public key `ryoku.gpg`, `ryoku-trusted`, empty `ryoku-revoked` into `/usr/share/pacman/keyrings/` (`PKGBUILD:15-22`); `pacman-key --populate ryoku` on install/upgrade (`ryoku-keyring.install:1-9`). `pkgver=20260620` (key date, `PKGBUILD:8`), `arch=('any')`.
**Arch couplings:**
- `/usr/share/pacman/keyrings/` (`PKGBUILD:19-21`).
- `pacman-key` in the scriptlet (`ryoku-keyring.install:2-3`).
- Fingerprint is the creator's (`ryoku-trusted:1`, `README.md:22-23`).
**Dependencies:** none (no makedepends/depends).
**As-is on Debian:** NO, pacman keyring format.
**Port steps:**
1. Generate a new ed25519 signing key (`gpg --quick-gen-key '<Name> <email>' ed25519 sign 5y`), export binary public key to `ryoku-archive-keyring.pgp`; replace `keys/ryoku-release-key.pub.asc`.
2. Create source `ryoku-archive-keyring` (control in §2.5.6), `debian/install`: `ryoku-archive-keyring.pgp usr/share/keyrings/`; delete the `.install` scriptlet (no populate step).
3. Rename consumers: `ryoku-desktop` Depends `ryoku-keyring` (`ryoku-desktop/PKGBUILD:30`) -> `ryoku-archive-keyring`; installer seeding (`installation/backend/lib/deploy.sh:98-115`) -> copy the `.pgp` into `/mnt/usr/share/keyrings/`.
**Complexity:** Low.
**Issues / risks:** Debian `Signed-By` binds the key to the one source, so a compromised key cannot sign other repos (pacman's populated keys are trusted for every repo). Only one active key can be listed per source unless the keyring file contains both during rotation.

### ryoku-shell (`release/packages/ryoku-shell/`)
**What it does:** builds `ryoku-shell` (Go, `CGO_ENABLED=0 -trimpath -mod=vendor`, `PKGBUILD:24-28`) and `ryoku-livewall` (C, `ryoku/shell/livewall/build.sh`: wayland-scanner on `wlr-layer-shell.xml`, `viewporter.xml`, `xdg-shell.xml`, links `wayland-client libavformat libavcodec libavutil libswscale`, `build.sh:23-37`); installs `/usr/bin/ryoku-shell`, `/usr/bin/ryoku-livewall`, every `ryoku/shell/scripts/ryoku-*` and `*.sh` to `/usr/bin` (`PKGBUILD:44-60`), `/usr/bin/ryostage` (`:51-52`), `/usr/share/ryoku/reload-cover/` (`:61-62`).
**Arch couplings:** none in the recipe beyond package names; runtime Go code reads `/usr/lib/qt6/qml/Ryoku/Blobs/qmldir` (`ryoku/shell/ipc/daemon.go:411`).
**Dependencies:**
| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version (why) |
|---|---|---|---|---|---|---|---|---|
| go (make) | build (`PKGBUILD:19,28`) | golang-1.26-go | - | 1.26.9 | 1.26.9 | 1.26.9 | 1.26.8 | 1.26 (`ryoku/shell/ipc/go.mod` `go 1.26`, `toolchain go1.26.5`) |
| wayland, wayland-protocols (make) | livewall (`:19`, `build.sh:23`) | libwayland-dev, libwayland-bin, wayland-protocols | 1.23.1 / 1.44 | - / 1.47 | 1.26.0 / 1.49 | same | 1.24.0 / 1.47 | stable viewporter + xdg-shell (any listed) |
| ffmpeg (make) | livewall (`build.sh:37`) | libavcodec-dev, libavformat-dev, libavutil-dev, libswscale-dev | 7.1.5 | - | 9.0.2 | 9.0.2 | 8.0.1 | none stated |
| quickshell | surfaces (`:18`) | quickshell | - | 0.3.0 | 0.3.2 | 0.3.2 | - | Arch ships 0.3.2 (owned by the shell report) |
| ffmpeg | runtime CLI + libs (`:18`) | ffmpeg | 7.1.5 | - | 9.0.2 | 9.0.2 | 8.0.1 | |
| wayland | runtime (`:18`) | libwayland-client0 (shlibs) | 1.23.1 | - | 1.26.0 | 1.26.0 | 1.24.0 | |
| jq | scripts (`:18`) | jq | 1.7.1 | - | 1.8.2 | 1.8.2 | 1.8.1 | |
| uv | ryostage venv (`:16-18`) | uv | - | - | 0.9.17 | 0.9.17 | - | Arch 0.13.1 |
**As-is on Debian:** PARTIAL: builds unchanged with Go 1.26; `uv` and `quickshell` are missing in some suites.
**Port steps:**
1. `debian/control`: `Build-Depends: debhelper-compat (= 13), golang-1.26-go | golang-go (>= 2:1.26~), libwayland-dev, libwayland-bin, wayland-protocols, libavcodec-dev, libavformat-dev, libavutil-dev, libswscale-dev, pkgconf`; `Package: ryoku-shell`, `Architecture: amd64`, `Depends: ${shlibs:Depends}, ${misc:Depends}, quickshell, ffmpeg, jq, uv`.
2. `debian/rules`: `override_dh_auto_build: cd ryoku/shell/ipc && PATH=/usr/lib/go-1.26/bin:$$PATH GOFLAGS=-mod=vendor GOTOOLCHAIN=local CGO_ENABLED=0 GOCACHE=$(CURDIR)/debian/.gocache go build -trimpath -o $(CURDIR)/debian/build/ryoku-shell .` and `ryoku/shell/livewall/build.sh debian/build/ryoku-livewall`; `override_dh_auto_install`: `install -Dm755` both, the two script globs, `ryostage`, and `cp -a ryoku/shell/quickshell/reload-cover/.` to `usr/share/ryoku/reload-cover/`; `override_dh_dwz:` (empty) for the Go binary.
3. Package `uv` for trixie/resolute (upstream `astral-sh/uv` 0.13.1 prebuilt `uv-x86_64-unknown-linux-gnu.tar.gz` repack like gpk, or backport Debian's 0.9.17 source).
4. Patch `ryoku/shell/ipc/daemon.go:411` to the multiarch QML path (or probe both).
**Complexity:** Medium (only because of uv/quickshell availability).
**Issues / risks:** Debian `uv` 0.9.17 vs Arch 0.13.1: ryostage's onnxruntime/Python 3.13 venv flow (`PKGBUILD:16-17`) was validated against Arch's uv; behaviour difference untested.

### ryoku-hub (`release/packages/ryoku-hub/`)
**What it does:** builds `/usr/bin/ryoku-hub` from `ryoku/hub/backend` (`CGO_ENABLED=0 -mod=vendor`, `PKGBUILD:23-30`).
**Arch couplings:** none.
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| go (make) | build (`PKGBUILD:18`) | golang-1.26-go | - | 1.26.9 | 1.26.9 | 1.26.9 | 1.26.8 | 1.26.4 (`ryoku/hub/backend/go.mod` `go 1.26.4`, `toolchain go1.26.5`) |
**As-is on Debian:** PARTIAL: needs Go >= 1.26.4 (trixie-bpo or newer suites).
**Port steps:** `Build-Depends: debhelper-compat (= 13), golang-1.26-go`; `Package: ryoku-hub`, `Architecture: amd64`, `Depends: ${misc:Depends}`; rules as ryoku-shell with `cd ryoku/hub/backend`. With `GOTOOLCHAIN=local` a 1.26.0-1.26.3 compiler refuses the module; all listed suites carry >= 1.26.8.
**Complexity:** Low.
**Issues / risks:** `release/packages/README.md:57` says ryoku-hub needs network for `github.com/BurntSushi/toml`; the recipe and the committed `ryoku/hub/backend/vendor/` say it builds offline (`PKGBUILD:7-9,25`). The README is stale.

### ryoku (`release/packages/ryoku/`)
**What it does:** builds `/usr/bin/ryoku` from `ryoku/cli` (`PKGBUILD:24-27`); installs `/usr/lib/systemd/system/ryoku-boot-guard.service` and `/usr/lib/tmpfiles.d/ryoku.conf` (`:34-37`).
**Arch couplings:**
- `depends=('pacman' 'pacman-contrib' 'snapper')` (`PKGBUILD:16`); `optdepends` yay, lua (`:17-18`).
- The CLI orchestrates pacman/yay/snapper (`PKGBUILD:4-5`), reads `/etc/pacman.conf` (`ryoku/cli/internal/sys/release.go:35-37,98-120`), `RepoBase` (`release.go:28`); CLI port is owned by the CLI report.
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| go (make) | build | golang-go (>= 1.23) | 1.24 | 1.27 | 1.27 | 1.27 | 1.26 | 1.23 (`ryoku/cli/go.mod`) |
| pacman | CLI backend | apt (CLI must be ported) | | | | | | |
| pacman-contrib | paccache/checkupdates | apt (`apt list --upgradable`) | | | | | | |
| snapper | snapshots | snapper | 0.10.6 | - | 0.10.6 | 0.10.6 | 0.10.6 | |
| lua (opt) | `luac` pre-check | lua5.4 (Suggests) | | | | | | |
**As-is on Debian:** PARTIAL: the binary builds on trixie's Go 1.24; the depends and the CLI logic are Arch-only.
**Port steps:**
1. `Build-Depends: debhelper-compat (= 13), golang-go (>= 2:1.23~)`; `Package: ryoku`, `Architecture: amd64`, `Depends: ${misc:Depends}, apt, snapper`, `Suggests: lua5.4`.
2. `debian/ryoku.install` or rules: binary, `ryoku/cli/systemd/ryoku-boot-guard.service` -> `usr/lib/systemd/system/` (do NOT let `dh_installsystemd` enable it: the doctor enables it, `PKGBUILD:31-33`; use `dh_installsystemd --no-enable --no-start`), `ryoku.tmpfiles.conf` -> `usr/lib/tmpfiles.d/ryoku.conf` (dh_installtmpfiles creates the entries in postinst).
**Complexity:** Low for packaging.
**Issues / risks:** the CLI's channel logic edits `/etc/pacman.conf`; on Debian it edits `/etc/apt/sources.list.d/ryoku.sources` (§2.5.4) and runs apt with the pin from §2.5.5.

### ryoku-blobs (`release/packages/ryoku-blobs/`)
**What it does:** builds the `Ryoku.Blobs` QML plugin via `ryoku/shell/plugin/build.sh` (CMake >= 3.28, C++20, `find_package(Qt6 6.5 REQUIRED COMPONENTS Quick ShaderTools Multimedia)`, `qt_add_shaders`, `INSTALL_RPATH $ORIGIN`; `ryoku/shell/plugin/CMakeLists.txt:10-49`) and installs `$build/qml/Ryoku/Blobs/` to `/usr/lib/qt6/qml/Ryoku/Blobs` (`PKGBUILD:26-38`).
**Arch couplings:** QML dir `/usr/lib/qt6/qml` (`PKGBUILD:33-37`); `build.sh:20` error text names pacman.
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| cmake, ninja | build | cmake, ninja-build | 3.31.6 / 1.12.1 | 4.3.4 / - | 4.3.4 / 1.13.2 | same | 4.2.3 / 1.13.2 | cmake 3.28 (`CMakeLists.txt:10`) |
| qt6-base, qt6-declarative | build/run | qt6-base-dev, qt6-declarative-dev | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | Qt 6.5 (`CMakeLists.txt:18`) |
| qt6-shadertools | `qt_add_shaders` | qt6-shadertools-dev, qt6-shader-baker | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| qt6-multimedia | CameraFeed | qt6-multimedia-dev, libqt6multimedia6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
**As-is on Debian:** PARTIAL: builds; install path wrong for Debian.
**Port steps:**
1. `Build-Depends: debhelper-compat (= 13), cmake (>= 3.28), ninja-build, qt6-base-dev, qt6-declarative-dev, qt6-shadertools-dev, qt6-shader-baker, qt6-multimedia-dev`; `Package: ryoku-blobs`, `Architecture: amd64`, `Depends: ${shlibs:Depends}, ${misc:Depends}, qml6-module-qtquick, qml6-module-qtmultimedia`.
2. `override_dh_auto_build: RYOKU_BLOBS_BUILD=$(CURDIR)/debian/build ryoku/shell/plugin/build.sh $(CURDIR)/debian/qml`; install to `usr/lib/$(DEB_HOST_MULTIARCH)/qt6/qml/Ryoku/Blobs/`.
3. Patch every reader of `/usr/lib/qt6/qml/Ryoku/...` (list in §1.4).
**Complexity:** Low.
**Issues / risks:** uses only public Qt API (no `*_p.h`, links `Qt6::Quick Qt6::Multimedia`, `CMakeLists.txt:37`), so no `qt6-base-abi` pin is needed; a Debian Qt minor transition still requires a rebuild for the plugin metadata Qt version check (`docs/development.md:68-73`).

### ryoku-rashin (`release/packages/ryoku-rashin/`)
**What it does:** builds `/usr/bin/ryoku-rashin` (`-mod=vendor`, `PKGBUILD:36-38`), runs `ryoku-rashin repo-index <repo> ryoku-repo.md` over the checkout at build (`:39-41`); installs symlink `/usr/bin/rashin` (`:48`), `/usr/share/ryoku/rashin/ryoku-repo.md` (`:49`), skill docs to `/usr/share/ryoku/skills/ryoku/{SKILL,gui,bar,plugins}.md` (`:53-56`), user unit `/usr/lib/systemd/user/ryoku-rashin.service` (`:60-61`, enabled only by `ryoku-rashin enable`).
**Arch couplings:** comment says the Hermes installer's build helper is apt-only and useless on Arch (`PKGBUILD:21-23`), which works in Debian's favour.
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| go (make) | build | golang-1.26-go | - | 1.26.9 | 1.26.9 | 1.26.9 | 1.26.8 | 1.26 (`ryoku/rashin/backend/go.mod`) |
| uv | Hermes venv (`:18-29`) | uv | - | - | 0.9.17 | 0.9.17 | - | |
| nodejs | npm/npx tooling | nodejs | 20.19.2 | - | 24.21.0 | 24.22.0 | 22.22.1 | |
| gcc | native deps | gcc (build-essential) | 14 | | | | | |
| prowl-agent | code index | prowl-agent ([ryoku]) | | | | | | |
| sqlite (opt) | introspection | sqlite3 (Suggests) | 3.46.1 | - | 3.53.4 | 3.53.4 | 3.46.1 | |
**As-is on Debian:** PARTIAL.
**Port steps:** `Package: ryoku-rashin`, `Architecture: amd64`, `Depends: ${misc:Depends}, uv, nodejs, gcc, prowl-agent`, `Suggests: sqlite3`; rules build + repo-index (needs the full checkout in the build tree; with source shape A this holds; `.git` is not needed by repo-index only if it reads the work tree: verify); `debian/ryoku-rashin.links`: `usr/bin/ryoku-rashin usr/bin/rashin`; `dh_installsystemduser --no-enable` for the unit.
**Complexity:** Low.
**Issues / risks:** the build output embeds the whole-repo index, so the package content changes with any commit, consistent with `RYOKU_PKGVER`.

### ryogami (`release/packages/ryogami/`)
**What it does:** builds `/usr/bin/ryogami` (`ryoku/shell/ryogami/daemon`, `-mod=vendor`) and `/usr/bin/ryogami-live` (livewall build.sh) (`PKGBUILD:35-46`); installs `/usr/lib/systemd/user/ryogami.service` (`:49-50`), the wall-ui tree to `/usr/share/ryogami/` (`:54-55`), `/usr/share/applications/ryogami-wall.desktop` (`:56-57`), license (`:58-59`). `license=('MIT')`.
**Arch couplings:** none.
**Dependencies:** go (1.22, `ryoku/shell/ryogami/daemon/go.mod`; trixie 1.24 suffices), libwayland-dev/libwayland-bin/wayland-protocols/libav*-dev (make, as ryoku-shell); runtime `imagemagick` (7.1.1.43 / - / 7.1.2.31 / 7.1.2.33 / 7.1.2.18), `ffmpeg`, `quickshell`, `curl` (8.14.1 / 8.21.0 / 8.22.0 / 8.23.0 / 8.18.0), `inotify-tools` (4.23.9 / - / 4.25.9 / 4.25.9 / 4.25.9).
**As-is on Debian:** PARTIAL (quickshell availability).
**Port steps:** `Package: ryogami`, `Architecture: amd64`, `Depends: ${shlibs:Depends}, ${misc:Depends}, imagemagick, ffmpeg, quickshell, curl, inotify-tools`; rules mirror `PKGBUILD:35-60`; `dh_installsystemduser --no-enable` (the doctor enables it, `ryoku-desktop/PKGBUILD:129-130`).
**Complexity:** Low.
**Issues / risks:** recipe comment "stdlib-only, so there is no vendor/ tree" (`PKGBUILD:37-39`) is stale: `ryoku/shell/ryogami/daemon/vendor/modules.txt` exists and the module requires `ryoku-wm`.

### ryoku-palette-bridge (`release/packages/ryoku-palette-bridge/`)
**What it does:** builds `/usr/bin/ryoku-palette-bridge` (`ryoku/palette-bridge`, `-mod=vendor`, `PKGBUILD:20-25`); installs `ryoku-palette-bridge-doctor`, `ryoku-palette-bridge-remove-integrations` (`:30-33`), user unit (`:34-35`), the whole source dir to `/usr/share/ryoku/palette-bridge/` (`:36-37`), license.
**Arch couplings:** none. Not depended on by any package and not in `system/packages/*.packages`; referenced by `ryoku/hub/backend/palettebridge.go` and the manifest (`ryoku/cli/internal/ryokumanifest/manifest.go`).
**Dependencies:** go >= 1.24 (`ryoku/palette-bridge/go.mod`): trixie golang-go 1.24 suffices.
**As-is on Debian:** YES.
**Port steps:** `Package: ryoku-palette-bridge`, `Architecture: amd64`, `Depends: ${misc:Depends}`; rules mirror the PKGBUILD; `dh_installsystemduser --no-enable`.
**Complexity:** Low.
**Issues / risks:** comment "GOFLAGS from the publish container pin the proxy" (`PKGBUILD:22-23`) matches nothing: `publish-repo.yml` sets no GOFLAGS; the build is offline only because the module has no requirements.

### ryoku-oh-my-zsh (`release/packages/ryoku-oh-my-zsh/`)
**What it does:** copies ohmyzsh at commit `4b657407c98bbc8830ae66c2ac7ff3d737c55a83` (committed 2026-08-29) into `/usr/share/oh-my-zsh/` (`PKGBUILD:24-31`); `provides/conflicts/replaces` `oh-my-zsh`, `oh-my-zsh-git` (`:20-22`) for AUR and CachyOS (`cachyos-zsh-config`) boxes. `arch=('any')`, `pkgver=${RYOKU_PKGVER}`.
**Arch couplings:** the provides/replaces exist only for AUR/CachyOS package names (`PKGBUILD:13-19`); container gate asserts them (`installation/tests/container-install.sh:83-92`).
**Dependencies:** git (make).
**As-is on Debian:** YES (no Debian package owns `/usr/share/oh-my-zsh`; `oh-my-zsh` is not packaged in Debian or Ubuntu).
**Port steps:** separate source (`3.0 (quilt)`, orig = GitHub archive of the commit), `Package: ryoku-oh-my-zsh`, `Architecture: all`, `Depends: ${misc:Depends}, zsh`, `Provides: oh-my-zsh`; `debian/install`: `* usr/share/oh-my-zsh/` (exclude `.git`); `debian/copyright` MIT. Version: if pinned from ryoku-desktop as `(= ${ryoku:Version})` it must carry `RYOKU_PKGVER` like Arch (`ryoku-desktop/PKGBUILD:31`).
**Complexity:** Low.
**Issues / risks:** drop the `oh-my-zsh-git` guard from the Debian gate.

### ryoku-desktop (`release/packages/ryoku-desktop/`)
**What it does:** the umbrella (`pkgrel=3`, `arch=('x86_64')` because it compiles Go helpers, `PKGBUILD:10-15`). Builds: Go helper modules found as `ryoku/apps/*/*/go.mod` (binary named after the module, `:303-311`), any `ryoku/apps/*/CMakeLists.txt` app (none ship, `:292-297`). Installs:
- `/etc/ryoku-release` with `RELEASE`, `NAME` (from `CODENAME`), `CHANNEL`, `VERSION`, `COMMIT` (`git rev-parse HEAD`), `DATE` (`:254-266`).
- `/usr/share/ryoku/config/`: `quickshell/` (shell) + `quickshell/hub/` (`:272-275`), every Quickshell app tree `quickshell/<app>/` (`:288-291`), `matugen/` (`:352-353`), `fish/config.fish`, `fish/conf.d/rashin.fish`, `qt6ct/qt6ct.conf`, `ryoku-terminal/env.sh`, `bash/ryoku.bash`, `bash/rashin.bash`, `zsh/ryoku.zsh`, `zsh/rashin.zsh`, `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `btop/btop.conf`, `starship.toml`, `environment.d/ryoku-session.conf`, `fastfetch/config.jsonc`, `fastfetch/fastfetch-emblem.png`, `wireplumber/`, `yazi/yazi.toml`, `kitty/`, `ghostty/`, `nvim/{init.lua,.ryoku-lazyvim,lua/}`, `pip/pip.conf`, `chromium-flags.conf`, `chrome-flags.conf` (`:369-441`), `systemd/user/` (`:472-473`).
- `/usr/bin/<app bin>` helpers (`:298-302`), `.desktop` files + `/usr/share/icons/hicolor/scalable/apps/<app>.svg` (`:312-318`), `ryoku-nvim.desktop`, `compress-video.desktop`, `install-app.desktop`, `ryoku-hub.desktop`, `ryoku-hub.svg`, `/usr/share/applications/mimeapps.list` (`:415-435`).
- QML modules `/usr/lib/qt6/qml/Ryoku/{PluginKit,Ui,FrameBars}` (`:324-349`).
- `/usr/share/ryoku/browser/` + `dist/{chromium,firefox}` (`:358-366`).
- `/usr/share/ryoku/lockscreen/qylock`, `install-qylock`, `/usr/bin/ryoku-qylock-{activate,lock,unlock-prepare}`, `/usr/share/ryoku/lockscreen/{ryoku-greeter,ryoku-wayland-session}` (`:446-466`).
- `/usr/bin/{claude,codex,opencode}-usage`, `/usr/lib/systemd/user/ryoku-ai-usage.{service,timer}`, `ryoku-bootstrap.service` (`:481-491`), `/usr/lib/environment.d/99-ryoku-session.conf` (`:494-495`), `/usr/lib/systemd/user-environment-generators/60-ryoku-xdg-dirs` (`:501-502`), `/usr/share/ryoku/ryodecors/` (`:508-509`).
- `/usr/bin/`: every executable `system/hardware/*/ryoku-*`, `system/extras/ryoku-*`, `system/containers/ryoku-*` (36 files), `ryostore-install`, `ryoku-fastfetch`, `ryoku-plugins-place`, `ryoku-i18n` (from `ryoku/i18n/tools/sync.py`) (`:518-554`); `/usr/share/ryoku/i18n/*.json` + `langs.json` (`:546-548`); `/usr/share/nautilus-python/extensions/ryoku-stash-menu.py` (`:560-561`).
- udev: `90-ryoku-gpu.rules`, `90-ryoku-backlight.rules`, `60-ryoku-i2c.rules`, `70-ryoku-maono.rules`, `72-ryoku-keyboard-uaccess.rules`, `62-ryoku-qmk-hid.rules` in `/usr/lib/udev/rules.d` (`:566-604`); `/etc/modules-load.d/ryoku-i2c.conf`, `/etc/modules-load.d/99-ryoku-uinput.conf` (`:579-580,614-615`); `/usr/lib/modprobe.d/99-ryoku-{audio-powersave,controller,bt-autosuspend}.conf` (`:593-628`).
- `/usr/lib/systemd/user/ryoku-bluetooth-reset.service` (`:634-635`); 13 polkit rules in `/usr/share/polkit-1/rules.d/` (`:636-723`); `/usr/lib/systemd/system/ryoku-network-kill-{guard,disconnect}.service` (`:656-659`).
- `/etc/systemd/logind.conf.d/10-ryoku-lid.conf` + libalpm hooks `94-ryoku-power-cutover-prepare.hook`, `95-ryoku-power-cutover.hook` (`:694-699`).
- `/usr/bin/ryoku-windows-entry`, `/etc/boot/hooks/post.d/45-ryoku-windows` (limine-entry-tool hook dir) (`:728-731`); `/usr/lib/initcpio/install/ryoku-gpu-trim` (`:737-738`); `/usr/share/plymouth/themes/ryoku/`, `/usr/share/ryoku/boot/{limine.conf,default.conf}`, `/usr/bin/ryoku-boot-apply` (`:742-749`).
Scriptlet `ryoku-desktop.install`: `pre_install`/`pre_upgrade` -> `_pre_upgrade_power_guard` (systemd-run a `systemd-inhibit --what=sleep --mode=block sleep infinity` unit and wait for it, `:82-113,226-232`); `post_install`: `_refresh` (icon cache + desktop db, `:12-19`), `_bluetooth`/`_rtkit`/`_powerprofiles` one-shot `systemctl enable` with markers in `/var/lib/ryoku/` (`:26-67`), `_bluetooth_tune` (edits `/etc/bluetooth/main.conf` in place, `:147-153`), `_wifi_regdom` (`:160-163`), `_backlight_fix` (`:169-172`), `_ai_usage_timer`/`_bt_reset_unit`/`_bootstrap` `systemctl --global enable` once (`:178-208`), `_boot_theme` (`:220-223`), `_hint`, `_schedule_power_cutover` (`:121-141`); `post_upgrade` same minus `_bootstrap`, plus `_network_kill_units` (`:212-216,249-263`); `post_remove`: `_refresh`, `_restore_logind`, rm marker (`:265-269`).
libalpm hooks: both trigger on Install/Upgrade/Remove of path `usr/bin/ryoku-clamshell`; 94 PreTransaction `ryoku-power-cutover prepare-package` with `AbortOnFail`; 95 PostTransaction `ryoku-power-cutover package` (`system/hardware/power/94-ryoku-power-cutover-prepare.hook:1-12`, `95-ryoku-power-cutover.hook:1-11`). Both the trigger path and the helper ship in ryoku-desktop itself (`system/hardware/power/ryoku-clamshell`, `system/hardware/power/ryoku-power-cutover`).
**Arch couplings:**
- libalpm hooks (`PKGBUILD:696-699`) and the deferred cutover waits for `/var/lib/pacman/db.lck` to disappear (`system/hardware/power/ryoku-power-cutover:957-969`).
- mkinitcpio install hook (`PKGBUILD:737-738`).
- Limine: `/etc/boot/hooks/post.d/45-ryoku-windows` (`:730-731`), `limine.conf`/`default.conf` (`:745-748`), `ryoku-boot-apply` syncs limine globals (`system/boot/ryoku-boot-apply:27-62`), `ryoku-hw-backlight-fix` writes `/etc/limine-entry-tool.d/` and runs `limine-mkinitcpio` (`system/hardware/display/ryoku-hw-backlight-fix:15-16,39,78-79`).
- `ryoku-wifi-regdom` uses Arch's `/etc/conf.d/wireless-regdom` (`system/hardware/network/ryoku-wifi-regdom:10,32`).
- QML dir `/usr/lib/qt6/qml` (`:324-349`) and the 18 qylock symlinks into it.
- `/etc/` files that become conffiles (§1.4).
- 11 polkit rules require group `wheel` (Cross-cutting).
- Depends with no Debian package (table).
- Comment: GPU udev rule, `linux-headers` "matches the base `linux` kernel" (`:204-208`).
**Dependencies:**
| Arch pkg | Used for (cite `PKGBUILD`) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Notes |
|---|---|---|---|---|---|---|---|---|
| go, cmake, ninja, qt6-base, qt6-declarative (make) | helpers/apps (`:19`) | golang-1.26-go, cmake, ninja-build, qt6-base-dev, qt6-declarative-dev | see §3.4 | | | | | `ryoku/apps/ryovm/*/go.mod` and `ryostore/backend/go.mod` say `go 1.26` |
| ryoku-shell/hub/rashin/blobs/ryoku/oh-my-zsh `=$pkgver` | exact pins (`:25-31`) | same, `(= ${binary:Version})` or `(= ${ryoku:Version})` | [ryoku] | | | | | |
| ryoku-keyring | (`:30`) | ryoku-archive-keyring | [ryoku] | | | | | |
| gpk | (`:33`) | gpk | [ryoku] | | | | | |
| ryoku-desktop-compositor | virtual (`:36`) | `ryoku-desktop-hyprland \| ryoku-desktop-compositor` | [ryoku] | | | | | real first alternative required for apt |
| xorg-xwayland | (`:37`) | xwayland | 24.1.6 | - | 24.1.14 | 24.1.14 | 24.1.10 | |
| qt6-wayland | (`:40`) | qt6-wayland | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| qt5-wayland | SDDM Qt5 greeter (`:38-41`) | qtwayland5 | 5.15.15 | - | 5.15.19 | 5.15.19 | 5.15.18 | |
| qt6-5compat | (`:42`) | qml6-module-qt5compat-graphicaleffects, libqt6core5compat6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| qt6-svg | (`:43`) | libqt6svg6, qt6-svg-plugins | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| qt6-imageformats | WebP previews (`:44-49`) | qt6-image-formats-plugins | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| weston | Wayland greeter (`:50-56`) | weston | 14.0.2 | - | 16.0.0 | 16.0.0 | 14.0.2 | |
| xdg-desktop-portal-gtk | (`:57`) | same | 1.15.3 | - | 1.15.3 | 1.15.3 | 1.15.3 | |
| adw-gtk-theme | GTK3 theme (`:58-64`) | none | - | - | - | - | - | build `adw-gtk3` v6.5 (github.com/lassekongo83/adw-gtk3) |
| gnome-themes-extra | (`:68`) | same | 3.28 | - | 3.28 | 3.28 | 3.28 | |
| papirus-icon-theme | (`:72`) | same | 20250501 | - | 20260801 | 20260801 | 20250501+git | |
| ryoku-cursors, ryoku-cursor-material | (`:80,85`) | same | [ryoku] | | | | | |
| quickshell | (`:87`) | quickshell | - | 0.3.0 | 0.3.2 | 0.3.2 | - | |
| syntax-highlighting | `org.kde.syntaxhighlighting` (`:88-90`) | qml6-module-org-kde-syntaxhighlighting | 6.13.0 | - | 6.30.0 | 6.30.0 | 6.24.0 | |
| qt6-declarative | QML runtime (`:143`) | qml6-module-qtquick, -qtquick-controls, -qtquick-templates, -qtquick-shapes, -qtquick-effects, -qtquick-layouts, -qtquick-window, -qtquick-dialogs, -qtqml, -qtqml-models, -qtqml-workerscript, -qt-labs-folderlistmodel | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | Debian splits Arch's single package per QML module; set derived from repo imports: QtQuick 848, QtQuick.Controls 65, QtQuick.Shapes 51, QtQuick.Effects 48, Qt5Compat.GraphicalEffects 17, QtMultimedia 14, QtQuick.Layouts 11, Qt.labs.folderlistmodel 8, QtQuick.Window 5, QtQuick.Dialogs 2, QtQml.Models 1, QtTest 1 (test only) |
| qt6-multimedia | video surfaces (`:139-142`) | qml6-module-qtmultimedia, libqt6multimedia6 | 6.8.2 | - | 6.11.2 | 6.11.2 | 6.10.2 | |
| zsh, zsh-autosuggestions, zsh-syntax-highlighting | (`:96-99`) | same | 5.9 / 0.7.1 / 0.8.0 | - | 5.9.2 / 0.7.1 / 0.8.0 | same | 5.9 / 0.7.1 / 0.8.0 | |
| zsh-history-substring-search | (`:98`) | none | - | - | - | - | - | build v1.1.0 (github.com/zsh-users/zsh-history-substring-search); check the path ryoku.zsh sources |
| brightnessctl, playerctl | (`:101-102`) | same | 0.5.1 / 2.4.1 | - | 0.5.1 / 2.4.1 | same | 0.5.1 / 2.4.1 | |
| mpv, mpv-mpris, yt-dlp | radio (`:103-107`) | same | 0.40.0 / 0.7.1 / 2025.04.30 | - / 1.2 / 2026.08.19 | 0.41.0 / 1.3 / 2026.08.19 | same | 0.41.0 / 1.2 / 2026.08.19 (bpo) | trixie yt-dlp is 17 months old; YouTube breaks old yt-dlp, use bpo |
| wl-clipboard | (`:108`) | same | 2.2.1 | 2.3.0 | 2.3.0 | 2.3.0 | 2.2.1 | |
| wl-clip-persist | (`:109`) | none | - | - | - | - | - | build v0.5.0 (Rust, github.com/Linus789/wl-clip-persist) |
| cliphist, grim, slurp, cava | (`:110-113`) | same | 0.5.0 / 1.4.0 / 1.5.0 / 0.10.4 | - | 0.5.0 / 1.5.0 / 1.5.0 / 1.0.0 | same | 0.5.0 / 1.4.0 / 1.6.0 / 0.10.7 | |
| python | wavecap.py (`:114-117`) | python3 | 3.13.5 | - | 3.14.7 | 3.14.7 | 3.14.3 | |
| pipewire | pw-record (`:118`) | pipewire, pipewire-bin | 1.4.2 | 1.6.9 | 1.6.9 | 1.6.9 | 1.6.2 | |
| jq, imagemagick | (`:119-120`) | same | 1.7.1 / 7.1.1.43 | - | 1.8.2 / 7.1.2.31 | 1.8.2 / 7.1.2.33 | 1.8.1 / 7.1.2.18 | |
| matugen | palette engine (`:121-124`) | none | - | - | - | - | - | build v4.2.0 (Rust, github.com/InioX/matugen); Arch 4.2.0 |
| ryogami | (`:131`) | same | [ryoku] | | | | | |
| ffmpeg, curl | (`:134,138`) | same | 7.1.5 / 8.14.1 | - / 8.21.0 | 9.0.2 / 8.22.0 | 9.0.2 / 8.23.0 | 8.0.1 / 8.18.0 | |
| zenity, iw, nftables | (`:145-151`) | same | 4.1.90 / 6.9 / 1.1.3 | - | 4.2.2 / 6.17 / 1.1.7 | same | 4.2.1 / 6.17 / 1.1.6 | `iw`, `nft` install to `/usr/sbin` on Debian (Cross-cutting PATH) |
| bluez, bluez-utils | (`:155-156`) | bluez (bluetoothctl is in bluez) | 5.82 | - | 5.87 | 5.87 | 5.85 | |
| pam-u2f | (`:160`) | libpam-u2f, pamu2fcfg | 1.4.0 | - | 1.4.0 | 1.4.0 | 1.4.0 | |
| rtkit | (`:163`) | same | 0.13 | - | 0.14 | 0.14 | 0.14 | |
| ttf-jetbrains-mono-nerd | UI font (`:168`) | none (`fonts-jetbrains-mono` is not the Nerd patch) | - | - | - | - | - | build from nerd-fonts v3.5.1 `JetBrainsMono.zip` |
| inter-font | (`:169`) | fonts-inter | 4.1 | - | 4.1 | 4.1 | 4.1 | |
| noto-fonts, noto-fonts-cjk, noto-fonts-emoji | (`:170-172`) | fonts-noto-core, fonts-noto-cjk, fonts-noto-color-emoji | 20201225 / 20240730 / 2.051 | - | 20201225 / 20240730 / 2.051 | same | same | |
| ttf-material-symbols-variable | every icon (`:164-173`) | none | - | - | - | - | - | build from google/material-design-icons variablefont (Arch 2.874); without it icons render as ligature names (`:166-167`) |
| tesseract, tesseract-data-eng | OCR (`:180-181`) | tesseract-ocr, tesseract-ocr-eng | 5.5.0 / 4.1.0 | - | 5.5.0 / 4.1.0 | same | 5.5.0 / 4.1.0 | |
| zbar | QR (`:182`) | zbar-tools | 0.23.93 | - | 0.23.93 | 0.23.93 | 0.23.93 | |
| gpu-screen-recorder | recording (`:183`) | gpu-screen-recorder | - | - | 5.13.8 | 5.13.8 | - | Arch 6.1.4; build for trixie/resolute (git.dec05eba.com/gpu-screen-recorder) |
| wf-recorder, wtype | (`:184-185`) | same | 0.5.0 / 0.4 | - | 0.6.0 / 0.4 | same | 0.6.0 / 0.4 | |
| libqalculate | calculator (`:186`) | qalc | 5.5.2 | - | 5.13.2 | 5.13.2 | 5.9.0 | |
| upower, power-profiles-daemon | (`:187-188`) | same | 1.90.9 / 0.30 | - | 1.91.5 / 0.30 | same | 1.91.1 / 0.30 | |
| ddcutil | DDC/CI (`:189-193`) | same | 2.2.0 | 2.2.7 | 2.2.7 | 2.2.7 | 2.2.5 | |
| hypridle, hyprpicker | (`:198-199`) | same | - | 0.1.8 / 0.4.7 | 0.1.8 / 0.4.7 | same | 0.1.7 / 0.4.6 | |
| linux-headers | xpadneo DKMS (`:200-207`) | linux-headers-amd64 (Debian) \| linux-headers-generic (Ubuntu) | 6.12.107 | 7.2.6 | 7.2.11 | 7.2.11 | - / 7.0.0 (generic) | |
| dkms | (`:208`) | dkms | 3.2.2 | - | 3.2.2 | 3.2.2 | 3.2.2 | |
| optdepends (`:210-245`) | apps | Suggests: kitty, fish, ble.sh, starship, fastfetch, yazi, neovim, nautilus, python3-nautilus, ryotunes, ryomotion, waifu2x-ncnn-vulkan, pavucontrol, songrec, openrgb, gamescope, gamemode, mangohud, chromium, kdialog, plasma-integration, qemu-system-x86, libvirt-daemon-system, ovmf, swtpm, looking-glass-client, quickemu, xorriso, spice-client-gtk, asusctl, qmk_hid | | | | | | name mapping of the app list is owned by the package-set report |
**As-is on Debian:** NO.
**Port steps:**
1. `debian/control` stanza: `Package: ryoku-desktop`, `Architecture: amd64`, `Depends:` the Debian column above (internal pins as `(= ${binary:Version})`), `Suggests:` the optdepends list (Arch optdepends never install; Debian `Suggests` never install; `Recommends` install by default, see Issues), `Pre-Depends: systemd` (preinst uses systemd-run).
2. `debian/rules` `override_dh_auto_build`: the Go helper loop and CMake loop from `PKGBUILD:283-311` with `GOFLAGS=-mod=vendor GOTOOLCHAIN=local`; generate `/etc/ryoku-release` from env `RYOKU_RELEASE`/`RYOKU_CHANNEL`/`RYOKU_COMMIT` (no `.git` exists in a Debian source build, `PKGBUILD:264` would yield `unknown`; sbuild filters the environment, so these must be passed with `--build-env` or `$environment_filter`).
3. `override_dh_auto_install`: port `package()` verbatim with path changes: QML modules to `usr/lib/$(DEB_HOST_MULTIARCH)/qt6/qml/Ryoku/{PluginKit,Ui,FrameBars}`; rewrite the 18 qylock symlinks to the multiarch target (or install real copies); drop `/usr/share/libalpm/hooks/*`; replace `/usr/lib/initcpio/install/ryoku-gpu-trim` with an initramfs-tools hook `/usr/share/initramfs-tools/hooks/ryoku-gpu-trim` (rewrite: initramfs-tools hooks use `hook-functions` `manual_add_modules`/`copy_exec`, and module exclusion is done through `/etc/initramfs-tools/conf.d` or by not adding nouveau) or drop it with the boot decision; Limine files only if the boot chain stays Limine.
4. `/etc` files: choose per file between conffile (default) and vendor location: `/usr/lib/modules-load.d/ryoku-i2c.conf`, `/usr/lib/modules-load.d/99-ryoku-uinput.conf`, `/usr/lib/systemd/logind.conf.d/10-ryoku-lid.conf` (systemd reads both trees), `/usr/lib/ryoku-release` + symlink or keep `/etc/ryoku-release` as conffile. Code that names the `/etc` paths: `docs/updates.md:424-435` (`updater.ryokuOverwriteGlob`, `reconcileConflictingRyokuFiles`), `ryoku/cli/internal/sys/release.go:41`.
5. Maintainer scripts (generated from `ryoku-desktop.install`):
   - `preinst` (`install`, `upgrade`): `_pre_upgrade_power_guard`, then `/usr/bin/ryoku-power-cutover prepare-package` when the old version already ships it (replaces hook 94; `AbortOnFail` -> `exit 1`).
   - `postinst configure`: `_bluetooth`, `_bluetooth_tune`, `_wifi_regdom`, `_backlight_fix`, `_rtkit`, `_powerprofiles`, `_boot_theme`, `_hint`, `_schedule_power_cutover`, `/usr/bin/ryoku-power-cutover package` (replaces hook 95); `_bootstrap` only when `$2` is empty (first install); `_network_kill_units` only when `$2` is set (upgrade); `udevadm control --reload-rules`. `_refresh` is covered by the `desktop-file-utils` trigger and the icon-cache trigger. `_ai_usage_timer`, `_bt_reset_unit`, `_bootstrap` can be `dh_installsystemduser` (it enables once and honours a later `disable`, same as the markers) with `--no-start`.
   - `prerm remove`: `ryoku-power-cutover prepare-package`; `postrm remove`: `systemctl reload systemd-logind`, `rm -f /var/lib/ryoku/power-cutover-hook-active` (the helper binary is gone by `postrm`, so the post half must run in `prerm` or from a copy).
   - `system/hardware/power/ryoku-power-cutover:960`: replace the `/var/lib/pacman/db.lck` existence test (dpkg's `/var/lib/dpkg/lock` and `lock-frontend` always exist) with an fcntl lock probe (e.g. `python3 -c 'import fcntl,sys;f=open(sys.argv[1],"w");fcntl.lockf(f,fcntl.LOCK_EX|fcntl.LOCK_NB)' /var/lib/dpkg/lock-frontend`).
6. `dh_installsystemd --no-enable --no-start` for `ryoku-network-kill-{guard,disconnect}.service` (the switch owns them, `ryoku-desktop.install:210-216`).
**Complexity:** High.
**Issues / risks:**
- `apt-get autoremove` removes packages that were pulled in as dependencies once a later ryoku-desktop drops them; pacman never autoremoves. Moving an app from Depends to Suggests (the pattern at `PKGBUILD:91-95,174-179`) marks it auto-removable on Debian.
- `ryoku-bluetooth-tune` edits `/etc/bluetooth/main.conf` in place (`ryoku-desktop.install:143-153`); on Debian that file is a bluez conffile, so every later bluez upgrade that changes it stops at a conffile prompt (non-interactive apt keeps the old file by default with `--force-confdef --force-confold`, never the new one).
- An unowned file at a conffile path (seeded by the installer or `deploy.sh`, `docs/updates.md:424-435`) produces dpkg's interactive conffile prompt on first package install; `--force-confnew` or moving the paths to `/usr/lib` avoids it.
- Conffiles survive `apt remove`: `/etc/systemd/logind.conf.d/10-ryoku-lid.conf` keeps the Ryoku lid policy after removal until purge, while Arch's `post_remove` restores the default immediately (`ryoku-desktop.install:69-75`).
- dpkg runs maintainer scripts with its lock held; `_schedule_power_cutover` detaches with `systemd-run --no-block` and polls for the package manager lock, so the lock probe change in step 5 is required or the deferred job waits 600 s and fails (`ryoku-power-cutover:959-969`).
- `system/boot/ryoku-boot-apply` runs `plymouth-set-default-theme` (`:19-20`); on Debian that also needs `update-initramfs -u` to take effect at early boot.

### ryoku-desktop-hyprland (`release/packages/ryoku-desktop-hyprland/`)
**What it does:** copies `ryoku/hyprland/` to `/usr/share/ryoku/config/hypr/` (`PKGBUILD:56-57`), `hyprland-portals.conf` to `.../xdg-desktop-portal/` (`:60-61`), picker `config.yaml` (`:65-66`), `ryoku/hyprland/scripts/ryoku-*` to `/usr/bin` (`:74-77`), builds `/usr/bin/ryoku-wm-hyprland` (`cd ryoku/wm/hyprland && go build`, `:81-83`), installs `/usr/lib/qt6/qml/Ryoku/Wm/Hyprland` (`:87-88`). `provides=('ryoku-desktop-compositor')`, not exclusive (`:43-45`).
**Arch couplings:** QML dir (`:87-88`).
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| go (make) | provider | golang-go | 1.24 | 1.27 | 1.27 | 1.27 | 1.26 | 1.22 (`ryoku/wm/go.mod`) |
| ryoku-desktop, plugins `=$pkgver` | (`:23-33`) | [ryoku], exact pins | | | | | | |
| hyprland | compositor (`:25`) | hyprland | - | 0.55.2 | 0.56.2 | 0.56.2 | 0.53.3 | Lua config (`ryoku/hyprland/hyprland.lua`) needs the Lua-config Hyprland line; owned by the compositor report |
| hyprpolkitagent | (`:34`) | same | - | 0.1.3 | 0.2.0 | 0.2.0 | 0.1.3 | |
| xdg-desktop-portal-hyprland | (`:35`) | same | - | 1.4.1 | 1.4.1 | 1.4.1 | 1.3.11 | |
| hyprland-preview-share-picker | (`:38`) | [ryoku] | | | | | | |
| hyprsunset | night light (`:41`) | same | - | 0.4.0 | 0.4.0 | 0.4.0 | - | |
**As-is on Debian:** PARTIAL.
**Port steps:** `Package: ryoku-desktop-hyprland`, `Architecture: amd64`, `Depends: ${misc:Depends}, ryoku-desktop (= ${binary:Version}), hyprland, hypr-dynamic-cursors (= ...), ryoku-hypr-plugins (= ...), hyprglass (= ...), imgborders (= ...), ryoku-keysounds (= ...), hyprpolkitagent, xdg-desktop-portal-hyprland, hyprland-preview-share-picker, hyprsunset`, `Provides: ryoku-desktop-compositor`; rules as the PKGBUILD with the QML path change.
**Complexity:** Medium.
**Issues / risks:** trixie main has no Hyprland at all; resolute has 0.53.3 and no hyprsunset. The circular `ryoku-desktop` <-> variant dependency is legal for dpkg (same as pacman).

### ryoku-desktop-niri (`release/packages/ryoku-desktop-niri/`)
**What it does:** copies `ryoku/niri/` to `/usr/share/ryoku/config/niri/` (`PKGBUILD:56-57`), `niri-portals.conf` (`:63-64`), builds `/usr/bin/ryoku-wm-niri` (`:71-73`), installs `/usr/lib/systemd/user/niri.service.d/ryoku-bootstrap.conf` (`:76-77`). `provides=('ryoku-desktop-compositor')`.
**Arch couplings:** none in the recipe.
**Dependencies:**
| Arch pkg | Used for | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|---|
| niri | compositor (`:26`) | none | - | - | - | - | - | Arch 26.04; build from github.com/YaLTeR/niri v26.04 (Rust; recipe owned by the compositor report) |
| xwayland-satellite | X11 (`:31`) | [ryoku] | | | | | | |
| xdg-desktop-portal-gnome | portal (`:34`) | same | 48.0 | - | 50.0 | 50.0 | 50.0 | |
| gammastep | night light (`:37`) | same | 2.0.9 | - | 2.0.11 | 2.0.11 | 2.0.9 | |
**As-is on Debian:** NO (niri missing everywhere; only `rust-niri-ipc` and `niri-companion` exist in forky/sid).
**Port steps:** `Package: ryoku-desktop-niri`, `Architecture: amd64`, `Depends: ${misc:Depends}, ryoku-desktop (= ${binary:Version}), niri, xwayland-satellite, xdg-desktop-portal-gnome, gammastep`, `Provides: ryoku-desktop-compositor`; add a `niri` source package to [ryoku].
**Complexity:** Medium.

### hypr-dynamic-cursors (`release/packages/hypr-dynamic-cursors/`)
**What it does:** clones VirtCode/hypr-dynamic-cursors default branch (`PKGBUILD:30`), checks out the commit `hyprpm.toml` pairs with the build host's Hyprland or falls back to HEAD (`:45-60`), `make all`, installs `/usr/lib/hyprland/plugins/dynamic-cursors.so` and an `.abi` receipt computed from `$(pkg-config --variable=prefix hyprland)/hyprland/src/version.h` (`:36-43,67-71`). `pkgver=${RYOKU_PKGVER}`.
**Arch couplings:** none Arch-specific; the build is non-hermetic (unpinned git, build-host Hyprland decides the commit).
**Dependencies:** hyprland-dev (- / 0.55.2 / 0.56.2 / 0.56.2 / 0.53.3), libhyprcursor-dev (- / 0.1.13 / 0.1.13 / 0.1.13 / 0.1.13), pkgconf, make, g++, git. On Debian `hyprland.pc` has `prefix=/usr/include/x86_64-linux-gnu` and the header is `/usr/include/x86_64-linux-gnu/hyprland/src/version.h` (extracted from `hyprland-dev_0.56.2+ds-3_amd64.deb`), so `_abi()` works unchanged with Debian's Hyprland; `version.h` carries `GIT_COMMIT_HASH` and the `*_VERSION` defines it parses.
**As-is on Debian:** PARTIAL.
**Port steps:**
1. Pre-build step (CI): read the target suite's `hyprland-dev` version, resolve the plugin commit from `hyprpm.toml` exactly as `prepare()` does, export that commit as `hypr-dynamic-cursors_<RYOKU_PKGVER>.orig.tar.xz` (offline build).
2. `Build-Depends: debhelper-compat (= 13), hyprland-dev, libhyprcursor-dev, pkgconf`; `Package: hypr-dynamic-cursors`, `Architecture: amd64`, `Depends: ${shlibs:Depends}, ${misc:Depends}, ${hyprland:ABI}`.
3. `override_dh_gencontrol: . /usr/lib/$(DEB_HOST_MULTIARCH)/hyprland/debian-abi-helper && dh_gencontrol -- "-Vhyprland:ABI=$${HYPRLAND_ABI}"` (Debian's own mechanism: `hyprland` `Provides: ${hyprland:Provides}` from that helper, and Debian's plugin packages depend on `${hyprland:ABI}`; Debian `hyprland` 0.56.2+ds-3 `debian/rules:30-32`, `hyprland-plugins` 0.56.0-1 `debian/rules`).
4. Install to `usr/lib/hyprland/plugins/dynamic-cursors.so` (path hardcoded by `ryoku/wm/hyprland/config_plugins.go:16`) plus the `.abi`.
**Complexity:** Medium.
**Issues / risks:** if the port builds its own Hyprland stack (prior art `debian13-stripped/tools/build-debs.sh:33-40`), the plugins must compile with the same compiler: prior art needs gcc-16 from sid on trixie for Hyprland >= 0.56 (C++26) (`build-debs.sh:24-26`), and `debian-abi-helper` only exists in Debian's own hyprland package.

### ryoku-hypr-plugins (`release/packages/ryoku-hypr-plugins/`)
**What it does:** clones hyprwm/hyprland-plugins, same hyprpm.toml resolution (`PKGBUILD:33,48-63`), `make -C hyprbars all`, `make -C hyprfocus all` (`:65-69`), installs `/usr/lib/hyprland/plugins/{hyprbars,hyprfocus}.so` + `.abi` (`:71-80`). `license=('BSD-3-Clause')`.
**Arch couplings:** none Arch-specific.
**Dependencies:** hyprland-dev, pkgconf, make, g++, git, libdrm-dev, libinput-dev, libpixman-1-dev, libwayland-dev, libxkbcommon-dev, libpango1.0-dev, libcairo2-dev (versions §3.4).
**As-is on Debian:** PARTIAL.
**Port steps:** as hypr-dynamic-cursors (resolved commit as orig, `${hyprland:ABI}`), `Build-Depends` the list above. Debian already ships `hyprland-plugin-hyprbars` and `hyprland-plugin-hyprfocus` (source `hyprland-plugins`: trixie-bpo 0.53.0, forky/sid 0.56.0, resolute 0.53.0) but installs `/usr/lib/x86_64-linux-gnu/hyprland/plugins/libhyprbars.so` with no `.abi` receipt; Ryoku's provider looks in `/usr/lib/hyprland/plugins` (`ryoku/wm/hyprland/config_plugins.go:16`), so Debian's packages are usable only after a provider change (path, `lib` prefix, receipt-less ABI check).
**Complexity:** Medium.
**Issues / risks:** trixie-bpo pairs hyprland 0.55.2 with hyprland-plugins 0.53.0; the Debian plugin version can lag the compositor.

### hyprglass (`release/packages/hyprglass/`)
**What it does:** clones hyprnux/hyprglass, hyprpm.toml resolution, `make`, installs `/usr/lib/hyprland/plugins/hyprglass.so` + `.abi` (`PKGBUILD:27-68`).
**Dependencies:** hyprland-dev, pkgconf, make, g++, git, libpixman-1-dev, libdrm-dev.
**As-is on Debian:** PARTIAL. **Port steps:** as hypr-dynamic-cursors. **Complexity:** Medium. **Issues / risks:** not packaged by Debian.

### imgborders (`release/packages/imgborders/`)
**What it does:** `git clone` of the committed `imgborders.bundle` (58,836 bytes; refs master `958b37b4`, tags 1.0.0-1.0.2; `sha256 48187e72...`, `PKGBUILD:38-40,55`), hyprpm.toml resolution, CMake build, installs `/usr/lib/hyprland/plugins/imgborders.so` + `.abi` (`:72-82`). Upstream codeberg.org/zacoons/imgborders.
**Dependencies:** hyprland-dev, cmake, pkgconf, git, libdrm-dev, libpixman-1-dev, libpango1.0-dev, libcairo2-dev.
**As-is on Debian:** PARTIAL (already offline). **Port steps:** keep the bundle in the Debian source (`debian/source/include-binaries`), `Build-Depends` above plus `git`; `${hyprland:ABI}`. **Complexity:** Low.
**Issues / risks:** `build-repo.sh:99-101` still says imgborders clones from Codeberg; the recipe uses the bundle.

### ryoku-keysounds (`release/packages/ryoku-keysounds/`)
**What it does:** builds the monorepo plugin `ryoku/hyprland/plugins/keysounds` with `make all MECHVIBES=<mechvibes checkout> IMPORTER=ryoku/hyprland/scripts/ryoku-keysounds-import` (`PKGBUILD:50-57`); installs `/usr/lib/hyprland/plugins/keysounds.so` + `.abi`, `/usr/share/ryoku/keysounds/` samples, mechvibes license, and the plugin source to `/usr/share/ryoku/hypr-plugins/keysounds/` for on-box rebuilds (`:59-69`). Mechvibes at commit `326252a1...` (`:32`).
**Dependencies:** hyprland-dev, pkgconf, make, g++, git, python3, ffmpeg, libpixman-1-dev, libdrm-dev; runtime `libcanberra0` (0.30 all suites).
**As-is on Debian:** PARTIAL.
**Port steps:** with source shape A it needs a component tarball (not possible in `3.0 (native)`), so it becomes its own `3.0 (quilt)` source: orig = `ryoku/hyprland/plugins/keysounds` + importer script, component `orig-mechvibes`; `Depends: ${shlibs:Depends}, ${misc:Depends}, ${hyprland:ABI}, libcanberra0`.
**Complexity:** Medium.
**Issues / risks:** on-box rebuild (`ryoku-hub desktop plugins rebuild keysounds`, `PKGBUILD:13-15`) needs `hyprland-dev` + `build-essential` on the user's machine; Debian splits headers into `hyprland-dev`.

### hyprland-preview-share-picker (`release/packages/hyprland-preview-share-picker/`)
**What it does:** builds WhySoBad/hyprland-preview-share-picker at commit `e2f30ff8...` (`pkgver=0.2.1.r9.ge2f30ff`) with the `lib/hyprland-protocols` submodule (`PKGBUILD:3-23`), `cargo build --frozen --release`, generates `schema.json` (`:27-33`); installs `/usr/bin/hyprland-preview-share-picker`, `/usr/share/hyprland-preview-share-picker/schema.json`, license (`:35-40`). Upstream latest release v0.2.1 (2025-04-29).
**Dependencies:**
| Arch pkg | Debian | trixie | trixie-bpo | forky | sid | resolute | Min version |
|---|---|---|---|---|---|---|---|
| cargo (make) | cargo, rustc | 1.85.1 | 1.96.1 | 1.96.1 | 1.97.1 | 1.93.1 | 1.85 (`edition = "2024"` in upstream `Cargo.toml:5`) |
| gtk4 | libgtk-4-dev / libgtk-4-1 | 4.18.6 | - | 4.24.1 | 4.24.1 | 4.22.4 | gtk4 crate feature `v4_8` (`Cargo.toml:17`) |
| gtk4-layer-shell | libgtk4-layer-shell-dev / libgtk4-layer-shell0 | 1.0.4 | - | 1.3.0 | 1.3.0 | 1.3.0 | crate 0.4.0 (`Cargo.toml:18`) |
| wayland, hyprland, xdg-desktop-portal-hyprland, slurp | runtime | as listed elsewhere | | | | | |
**As-is on Debian:** PARTIAL. **Port steps:** orig = commit archive; components: hyprland-protocols at the gitlink commit, `cargo vendor` output; `.cargo/config.toml` vendored-sources; `Build-Depends: debhelper-compat (= 13), cargo, rustc (>= 1.85), libgtk-4-dev, libgtk4-layer-shell-dev, pkgconf`; `override_dh_auto_build: cargo build --frozen --offline --release && ./target/release/hyprland-preview-share-picker schema > schema.json`; `DEB_BUILD_MAINT_OPTIONS=optimize=-lto` (`options=('!lto')`, `PKGBUILD:12`); `Depends: ${shlibs:Depends}, ${misc:Depends}, hyprland, xdg-desktop-portal-hyprland, slurp`.
**Complexity:** Medium. **Issues / risks:** transitive crate MSRVs in `Cargo.lock` may exceed trixie's rustc 1.85 (not checked); trixie-bpo has 1.96.1.

### xwayland-satellite (`release/packages/xwayland-satellite/`)
**What it does:** builds Supreeeme/xwayland-satellite at commit `add27951...` (`pkgver=0.8.2.r13.gadd2795`) because 0.8.2 broke override-redirect popup focus (`PKGBUILD:3-27`); seds `/usr/local` -> `/usr` in the user unit (`:33`), `cargo build --frozen --release --features systemd` (`:38-43`), installs `/usr/bin/xwayland-satellite`, `/usr/lib/systemd/user/xwayland-satellite.service`, license (`:45-50`).
**Arch couplings:** none; the pin is obsolete on Arch: upstream tagged v0.8.3 (GitHub compare `add2795...v0.8.3`: v0.8.3 is 2 commits ahead, so it contains the fix) and Arch extra ships `0.8.3-1`.
**Dependencies:** cargo/rustc >= 1.85 (upstream `Cargo.toml:15` `rust-version = "1.85.0"`, edition 2024), clang + libclang-dev (bindgen), libxcb1-dev (1.17.0 all), libxcb-cursor-dev (0.1.5 / - / 0.1.6 / 0.1.6 / 0.1.6), runtime xwayland, libxcb-cursor0.
**As-is on Debian:** PARTIAL (not in Debian/Ubuntu).
**Port steps:** package upstream tag v0.8.3 (orig = tag tarball + `cargo vendor` component); `Build-Depends: debhelper-compat (= 13), cargo, rustc (>= 1.85), clang, libclang-dev, libxcb1-dev, libxcb-cursor-dev, pkgconf`; rules: sed the unit, `cargo build --frozen --offline --release --features systemd`; `Depends: ${shlibs:Depends}, ${misc:Depends}, xwayland`; `dh_installsystemduser --no-enable`.
**Complexity:** Low.

### gpk (`release/packages/gpk/`)
**What it does:** repackages the GlazePKG release binary `gpk-linux-amd64` v0.6.10 (sha256 `b4e43c24...`) to `/usr/bin/gpk` (`PKGBUILD:12-34`); `depends=('pacman')`, `replaces/conflicts gpk-bin`, `options=('!strip' '!debug')`. Upstream latest v0.6.10 (2026-09-22).
**Arch couplings:** `depends=('pacman')` (`:18`); described as "the RyokuArch package manager" (`:3,14`).
**Dependencies:** none on Debian (static Go binary).
**As-is on Debian:** PARTIAL.
**Port steps:** `Package: gpk`, `Architecture: amd64`, `Depends: ${misc:Depends}`; `debian/install` the binary; `override_dh_strip:` and `override_dh_dwz:` empty.
**Complexity:** Low.
**Issues / risks:** `gpk update` self-updates from upstream (`PKGBUILD:10`) and would overwrite a dpkg-owned `/usr/bin/gpk` (dpkg `--verify` then reports it changed); whether GlazePKG drives apt as well as pacman was not checked.

### prowl-agent (`release/packages/prowl-agent/`)
**What it does:** builds neur0map/prowl-agent at commit `506e54fb...` (`pkgver=0.15.6`) with `CGO_ENABLED=1 -tags sqlite_fts5 -ldflags "-s -w -X main.version=v0.15.6 -X main.managedBy=pacman"` and `GOFLAGS=-mod=mod` (network) (`PKGBUILD:19-47`); installs `/usr/bin/prowl-agent` (`:49-51`). `license=('custom')`. Upstream latest v0.17.2 (2026-10-07).
**Arch couplings:** `-X main.managedBy=pacman` flips the self-update guard (`:41-45`).
**Dependencies:** golang >= 1.26.4 (upstream `go.mod` `go 1.26.4`), gcc, git; runtime libc only (sqlite is bundled by `mattn/go-sqlite3 v1.14.45`).
**As-is on Debian:** PARTIAL.
**Port steps:** orig = commit archive + `go mod vendor` component; `Build-Depends: debhelper-compat (= 13), golang-1.26-go, gcc`; build with `GOFLAGS=-mod=vendor`, `-X main.managedBy=dpkg` (or `apt`; the guard value must be one prowl recognises: verify in upstream source); `DEB_BUILD_MAINT_OPTIONS=optimize=-lto`; `override_dh_dwz:`; `Depends: ${shlibs:Depends}, ${misc:Depends}`.
**Complexity:** Medium.
**Issues / risks:** `docs/updates.md:106-111` says `ryoku update` runs `prowl update` only when prowl is not owned by a pacman package; that ownership check is pacman-specific (CLI report).

### ryomotion (`release/packages/ryomotion/`)
**What it does:** builds the OpenScreen fork `ryoku-dev/ryomotion` at commit `60ea129d...` (`pkgver=1.5.0`, `pkgrel=11`) with a fetched Node 22.22.1 (`npm ci`, `npm run build-vite`, `electron-builder --linux dir` with productName/executableName/appId overrides), replaces `public/openscreen.png` with the bundled logo (`PKGBUILD:21-58`); installs the unpacked Electron tree to `/opt/ryomotion/`, symlink `/usr/bin/ryomotion`, a generated `.desktop`, the logo as hicolor icons 16-1024 px (`:60-89`). The fork repository has no GitHub releases (API 404).
**Arch couplings:** none beyond names; `options=('!strip' '!debug')`.
**Dependencies:**
| Arch pkg | Debian | trixie | trixie-bpo | forky | sid | resolute |
|---|---|---|---|---|---|---|
| gtk3 | libgtk-3-0t64 | 3.24.49 | - | 3.24.52 | 3.24.52 | 3.24.52 |
| nss | libnss3 | 3.110 | - | 3.130 | 3.131 | 3.120 |
| alsa-lib | libasound2t64 | 1.2.14 | 1.2.16.1 | 1.2.16.1 | 1.2.16.1 | 1.2.15.3 |
| libnotify | libnotify4 | 0.8.6 | - | 0.8.8 | 0.8.8 | 0.8.8 |
| pipewire | pipewire | 1.4.2 | 1.6.9 | 1.6.9 | 1.6.9 | 1.6.2 |
| xdg-desktop-portal | xdg-desktop-portal | 1.20.3 | - | 1.22.1 | 1.22.1 | 1.21.1 |
| gpu-screen-recorder | gpu-screen-recorder | - | - | 5.13.8 | 5.13.8 | - |
| git (make) | git | | | | | |
**As-is on Debian:** PARTIAL.
**Port steps:** offline technique in §1.5 (Node component, npm cache component, Electron zip component) or a networked CI build; `Package: ryomotion`, `Architecture: amd64`, `Depends: ${misc:Depends}, libgtk-3-0t64 | libgtk-3-0, libnss3, libasound2t64 | libasound2, libnotify4, pipewire, xdg-desktop-portal, gpu-screen-recorder`; `override_dh_strip:`, `override_dh_dwz:`, `override_dh_shlibdeps:` scoped (Electron bundles libffmpeg.so etc.); install via `debian/install` + `debian/links` (`opt/ryomotion/ryomotion usr/bin/ryomotion`).
**Complexity:** High.
**Issues / risks:** `t64` library names exist in trixie/forky/sid/resolute; the alternatives keep older suites satisfiable. Package size: Electron unpacked trees are ~250 MB; relevant for GitHub Pages hosting limits (§2.5.3).

### ryoku-cursors (`release/packages/ryoku-cursors/`)
**What it does:** installs every Bibata v2.0.7 XCursor theme from the release tarball (sha256 `172e33c4...`) into `/usr/share/icons/`, and builds a hyprcursor variant of Bibata-Modern-Classic with `hyprcursor-util --extract/--create` into `/usr/share/icons/Bibata-Modern-Classic/{hyprcursors,manifest.hl}` (`PKGBUILD:28-72`); provides/conflicts/replaces `bibata-cursor-theme`, `-bin` (`:35-37`).
**Dependencies:** hyprcursor-util (- / 0.1.13 / 0.1.13 / 0.1.13 / 0.1.13), xcur2png (0.7.1 all). Debian `bibata-cursor-theme` 2.0.6 (trixie, forky, sid, resolute) ships XCursor dirs only (`Bibata-Modern-{Amber,Classic,Ice}`, `Bibata-Original-*`) and no hyprcursor manifest.
**As-is on Debian:** YES (builds with Debian tools).
**Port steps:** `Build-Depends: debhelper-compat (= 13), hyprcursor-util, xcur2png`; `Package: ryoku-cursors`, `Architecture: all`, `Provides: bibata-cursor-theme`, `Conflicts: bibata-cursor-theme`, `Replaces: bibata-cursor-theme`; `check()` -> `override_dh_auto_test`.
**Complexity:** Low.
**Issues / risks:** trixie main lacks `hyprcursor-util`; build in a bpo-enabled chroot.

### ryoku-cursor-material (`release/packages/ryoku-cursor-material/`)
**What it does:** runs the vendored fish recipe `compile_bibata_material.fish Ryoku` (with `metadata_generator.py`, `themes.json`) over `rtgiskard/bibata_cursor` at commit `f4ccfe8a...` to produce `Bibata-Material-Ryoku` (`PKGBUILD:36-56`); installs it to `/usr/share/icons/`, the Bibata SVG source to `/usr/share/ryoku-cursor-material/bibata/`, and `/usr/bin/ryoku-cursor-material-recolor` (python3, runtime recolor from matugen's post-hook) (`:58-69`).
**Dependencies:** make: fish (4.0.2 / - / 4.9.3 / 4.9.3 / 4.2.1), jq, librsvg2-bin, x11-apps (xcursorgen), python3, git (+ xcur2png per `build-toolchain.packages:61-63`); runtime python3, librsvg2-bin, x11-apps.
**As-is on Debian:** YES.
**Port steps:** orig = vendored recipe files, component = bibata_cursor commit; `Build-Depends: debhelper-compat (= 13), fish, jq, librsvg2-bin, x11-apps, python3, xcur2png`; `Package: ryoku-cursor-material`, `Architecture: all`, `Depends: ${misc:Depends}, python3, librsvg2-bin, x11-apps`.
**Complexity:** Low. **Issues / risks:** `x11-apps` is a large bundle just for `xcursorgen`; Debian has no split xcursorgen package.

### otf-space-grotesk (`release/packages/otf-space-grotesk/`)
**What it does:** installs `SpaceGrotesk-2.0.0/otf/*.otf` from the upstream release zip (sha256 `53b41557...`) to `/usr/share/fonts/OTF` (`PKGBUILD:17-32`). Not in Debian/Ubuntu.
**As-is on Debian:** YES. **Port steps:** `Package: fonts-space-grotesk` (Debian font naming) with `Provides: otf-space-grotesk`, `Architecture: all`; install to `usr/share/fonts/opentype/space-grotesk/`; repack zip to `.orig.tar.xz`; fontconfig cache is refreshed by fontconfig's trigger. **Complexity:** Low.

### ttf-maple-mono-nf (`release/packages/ttf-maple-mono-nf/`)
**What it does:** installs every `*.ttf` from `MapleMono-NF.zip` v7.9 (sha256 `59098b87...`) to `/usr/share/fonts/maple-mono-nf` (`PKGBUILD:13-25`). Not in Debian/Ubuntu.
**As-is on Debian:** YES. **Port steps:** `Package: fonts-maple-mono-nf`, `Provides: ttf-maple-mono-nf`, `Architecture: all`, install to `usr/share/fonts/truetype/maple-mono-nf/`. **Complexity:** Low.

### blesh (`release/packages/blesh/`)
**What it does:** copies `ble-0.4.0-devel3` release tarball to `/usr/share/blesh/` (`PKGBUILD:1-16`). Sourced by `ryoku/apps/bash/ryoku.bash:18-19` from `/usr/share/blesh/ble.sh`.
**Dependencies:** bash. Debian `ble.sh` (source and binary `ble.sh`): - / - / 0.4.0~git20250806 / 0.4.0~git20250806 / 0.4.0~git20250806, installs `/usr/share/blesh/ble.sh` (packages.debian.org sid filelist), same path as Ryoku expects.
**As-is on Debian:** YES on forky/sid/resolute via Debian's package; trixie needs a backport.
**Port steps:** forky/sid/resolute: depend on/suggest `ble.sh`; trixie: backport Debian's `ble.sh` source or repack upstream as `Package: ble.sh`.
**Complexity:** Low. **Issues / risks:** the Arch name `blesh` appears in `system/packages/base.packages`.

### broadcom-bt-firmware (`release/packages/broadcom-bt-firmware/`)
**What it does:** downloads upstream's own `.deb` (`broadcom-bt-firmware-12.0.1.1105.deb`, release `v12.0.1.1105_p4`, b2sum pinned), extracts `data.tar.gz`, installs 114 `brcm/*.hcd` to `/usr/lib/firmware/brcm`, license and docs (`PKGBUILD:36-66`). Upstream latest `v12.0.1.1105_p5`.
Debian's `firmware-brcm80211` (non-free-firmware: 20250410 / 20260916 / 20260916 / 20260916 / -; Ubuntu ships one `linux-firmware` instead) installs 116 files under `/usr/lib/firmware/brcm/` and not one `.hcd` (packages.debian.org sid filelist), the same gap the recipe describes for Arch's `linux-firmware-broadcom` (`PKGBUILD:12-14`), so no file conflict and no overlap.
**As-is on Debian:** YES.
**Port steps:** repack to a Debian package with `/usr/lib/firmware/brcm/*.hcd` (upstream's deb places them under `/lib/firmware`, `PKGBUILD:49-55`; on merged-usr Debian, shipping `/lib/...` paths from one package and `/usr/lib/...` from another is the DEP17 aliasing hazard); `Package: broadcom-bt-firmware`, `Architecture: all`, `Section: non-free-firmware/kernel`; postinst `update-initramfs -u` is not needed (btusb loads firmware at runtime).
**Complexity:** Low. **Issues / risks:** redistribution licence is Broadcom's; Debian would place it in non-free-firmware.

### game-devices-udev (`release/packages/game-devices-udev/`)
**What it does:** builds fabiscafe/game-devices-udev 1.0 with `arch-meson`, installs its udev rules, license (`PKGBUILD:35-59`); deliberately no `uinput.conf` (`:29-32`); `provides=('nintendo-udev')`; scriptlet reloads udev rules on install/upgrade/remove (`game-devices-udev.install:1-14`).
**Dependencies:** meson (1.7.0 / - / 1.12.1 / 1.12.1 / 1.10.1), udev. Not in Debian/Ubuntu (`steam-devices` covers only Valve hardware).
**As-is on Debian:** YES.
**Port steps:** `Build-Depends: debhelper-compat (= 13), meson, pkgconf, udev` (meson reads `udevdir` from `udev.pc`, `/usr/lib/udev` on Debian); `dh $@ --buildsystem=meson`; `Package: game-devices-udev`, `Architecture: all`, `Depends: ${misc:Depends}, udev`; `postinst`/`postrm`: `udevadm control --reload-rules || true`.
**Complexity:** Low.

### dualsensectl (`release/packages/dualsensectl/`)
**What it does:** builds nowrep/dualsensectl v0.7 with `arch-meson`, `meson install` (`PKGBUILD:17-39`).
**Dependencies:** meson; dbus, hidapi, libusb (`:24`) -> libdbus-1-dev, libhidapi-dev (0.14.0 / - / 0.15.0 / 0.15.0 / 0.15.0), libusb-1.0-0-dev. Debian `dualsensectl`: - / - / 0.7+git20250823 / same / same.
**As-is on Debian:** YES on forky/sid/resolute (Debian's is newer than Ryoku's 0.7).
**Port steps:** forky/sid/resolute: use Debian's; trixie: backport Debian's source (`dh $@ --buildsystem=meson`).
**Complexity:** Low.

### asusctl (`release/packages/asusctl/`)
**What it does:** builds asusctl 6.4.0 (`cargo build --release --locked -p asusctl -p asusd -p asus-shutdown`), `make DESTDIR=... install-asusctl install-asusd install-asus-shutdown install-data-asusd` (`PKGBUILD:2-27`); `conflicts=('asusctl-git' 'tlp')`; scriptlet `daemon-reload`, `udevadm control --reload`, `udevadm trigger --subsystem-match=platform --action=add`, restart `asusd` on upgrade (`asusctl.install:1-22`). Maintainer line `Ryoku CI <ci@ryoku.local>` (`PKGBUILD:1`). Upstream latest 6.5.0.
**Dependencies:** rust >= 1.82 (upstream `Cargo.toml:3`), clang, llvm, libclang-dev; libusb-1.0-0-dev, libudev-dev (257.13 / - / 262 / 262.1 / 259.9); runtime libusb-1.0-0, udev. Not in Debian/Ubuntu.
**As-is on Debian:** PARTIAL.
**Port steps:** orig = tag tarball + `cargo vendor` component; `Build-Depends: debhelper-compat (= 13), cargo, rustc (>= 1.82), clang, libclang-dev, llvm, libusb-1.0-0-dev, libudev-dev, pkgconf`; `override_dh_auto_build: cargo build --frozen --offline --release -p asusctl -p asusd -p asus-shutdown`; `override_dh_auto_install: $(MAKE) DESTDIR=$(CURDIR)/debian/asusctl install-asusctl install-asusd install-asus-shutdown install-data-asusd`; `Conflicts: tlp`; `postinst`/`postrm` from the scriptlet (`dh_installsystemd` would also restart asusd on upgrade).
**Complexity:** Medium.

### xpadneo-dkms (`release/packages/xpadneo-dkms/`)
**What it does:** xpadneo v0.10.4: `make PREFIX=$pkgdir ETC_PREFIX=/usr/lib install` (modprobe + udev files as vendor files), DKMS source tree in `/usr/src/hid-xpadneo-v0.10.4/` (`PKGBUILD:37-70`).
**Dependencies:** dkms, bluez, bluez-utils. Debian `xpadneo-dkms`: - / - / 0.10.4 / 0.10.4 / -, ships `/usr/lib/modprobe.d/xpadneo.conf`, `/usr/lib/udev/rules.d/60-xpadneo.rules`, `70-xpadneo-disable-hidraw.rules` (sid filelist).
**As-is on Debian:** YES on forky/sid; trixie and resolute need a build.
**Port steps:** forky/sid: use Debian's; trixie/resolute: backport Debian's source (uses `dh-dkms`).
**Complexity:** Low. **Issues / risks:** same package name as Debian's; with the §2.5.5 pin the [ryoku] copy wins even at equal version.

### limine-mkinitcpio-hook (`release/packages/limine-mkinitcpio-hook/`)
**What it does:** vendored AUR recipe: builds `limine-entry-tool` 1.37.1 (GraalVM native-image via Gradle 9.6.1 with the offline init script) and installs upstream's `install/arch-linux/{limine-entry-tool,limine-mkinitcpio-hook}/{etc,usr}` plus `/usr/lib/limine/limine-entry-tool`, hook symlinks in `/etc/boot/hooks/{pre,post}.d` (`PKGBUILD:10-102`); `depends=(bash grep tar limine mkinitcpio efibootmgr)`, `backup=(etc/limine-entry-tool.conf)`. Upstream tags now at 1.40.0.
**Arch couplings:** mkinitcpio (`:50`); upstream `install/` contains only `arch-linux` (GitLab tree of tag 1.37.1); the whole recipe exists to support the Arch boot chain.
**Dependencies:** limine (none in Debian/Ubuntu; upstream v12.9.3), mkinitcpio (none), efibootmgr (18 all), GraalVM CE JDK 25 tarball, Gradle 9.6.1 zip.
**As-is on Debian:** NO.
**Port steps:** depends on the boot-chain decision (boot report). If Limine is kept: package `limine` from upstream v12.9.3, write a Debian install tree for limine-entry-tool (kernel hooks in `/etc/kernel/postinst.d/` and `/etc/kernel/postrm.d/`, initramfs-tools instead of mkinitcpio), vendor all Gradle artifacts for offline builds.
**Complexity:** High.

### limine-snapper-sync (`release/packages/limine-snapper-sync/`)
**What it does:** builds limine-snapper-sync 1.31.0 the same way (GraalVM `jdk-25.0.2`) and installs upstream's `install/arch-linux/{etc,usr}` + `/usr/lib/limine/limine-snapper-sync` (`PKGBUILD:9-85`); `depends=(bash limine snapper btrfs-progs libnotify)`.
**Dependencies:** limine (none), snapper (0.10.6 all), btrfs-progs (6.14 / 7.1 / 7.1 / 7.1 / 6.17.1), libnotify-bin (0.8.6 / - / 0.8.8 / 0.8.8 / 0.8.8).
**As-is on Debian:** NO (no limine; upstream `install/` has only `arch-linux`).
**Port steps:** as limine-mkinitcpio-hook; the two recipes pin different GraalVM tarballs (`graal-25.1.3` vs `jdk-25.0.2`, `limine-mkinitcpio-hook/PKGBUILD:40`, `limine-snapper-sync/PKGBUILD:27`).
**Complexity:** High.

### ryotunes (imported, no recipe in this repo)
**What it does:** official prebuilt `ryotunes-<ver>-1-x86_64.pkg.tar.zst` from `ryoku-dev/ryotunes` GitHub releases, verified and re-signed into every channel (`release/repo/import-ryotunes.sh:1-164`), refreshed hourly (`refresh-ryotunes.yml`), and updated on boxes by `ryoku update` outside the [ryoku] set (`docs/updates.md:55-81`). Current upstream v1.2.1 (2026-10-17), Rust/Tauri + QML client; its `packaging/arch/PKGBUILD` depends on `webkit2gtk-4.1 libappindicator-gtk3 mpv yt-dlp ffmpeg openssl librsvg desktop-file-utils hicolor-icon-theme xdg-utils polkit quickshell`, makedepends `cargo nodejs pnpm appmenu-gtk-module xdotool`, `epoch=1`, installs `/usr/bin/{ryotunes,ryotunes-sync,ryotunesd,ryotunes-cli,ryotunes-qml,ryotunes-diagnostics}`, `/usr/share/ryotunes/{client,skins,matugen}`, user units `ryotunesd.{service,socket}` + preset.
**As-is on Debian:** NO (no deb asset).
**Port steps:** add a Debian packaging dir to the ryotunes repo (Build-Depends `cargo rustc nodejs libwebkit2gtk-4.1-dev libayatana-appindicator3-dev libssl-dev librsvg2-dev appmenu-gtk3-module xdotool`, pnpm via a vendored tarball since Debian has none; Depends `libwebkit2gtk-4.1-0, libayatana-appindicator3-1, mpv, yt-dlp, ffmpeg, librsvg2-2, desktop-file-utils, hicolor-icon-theme, xdg-utils, polkitd, quickshell`), publish `ryotunes_<ver>-1_amd64.deb` + `.sha256` per release, port the importer (§3.1).
**Complexity:** High.
**Issues / risks:** `docs/updates.md:79-81` says "The [ryoku] repo still builds the ryotunes package (a sha256-pinned source tarball)", contradicting the code (no recipe; import of the prebuilt package, `build-repo.sh:199-204`). The in-client updater installs with `pacman -U` (`docs/updates.md:65-70`; CLI report).

---

## 5. Build order

Build-time edges between [ryoku] packages are few: no PKGBUILD lists another [ryoku] package in `makedepends`. Build order is driven by external build inputs (Hyprland headers, hyprcursor, Go 1.26) and by the publish gate, which installs the whole runtime closure.

Runtime dependency graph (Arch `depends`, cites in §4):

```
ryoku-desktop ──= ryoku-shell, ryoku-hub, ryoku-rashin, ryoku-blobs, ryoku, ryoku-oh-my-zsh
              ──> ryoku-keyring, gpk, ryoku-cursors, ryoku-cursor-material, ryogami
              ──> ryoku-desktop-compositor (virtual)
ryoku-rashin  ──> prowl-agent
ryoku-desktop-hyprland ──= ryoku-desktop, hypr-dynamic-cursors, ryoku-hypr-plugins, hyprglass, imgborders, ryoku-keysounds
                       ──> hyprland-preview-share-picker   (provides ryoku-desktop-compositor)
ryoku-desktop-niri     ──= ryoku-desktop
                       ──> xwayland-satellite, niri(*)       (provides ryoku-desktop-compositor)
limine-snapper-sync    ··> limine-mkinitcpio-hook (optdepend)
ryoku-desktop          ··> ryomotion, asusctl, ryotunes (optdepends)
standalone (no internal edges): ryoku-palette-bridge, otf-space-grotesk, ttf-maple-mono-nf, blesh,
  broadcom-bt-firmware, game-devices-udev, dualsensectl, xpadneo-dkms, limine-mkinitcpio-hook
──= exact version pin   ──> plain depend   ··> optional   (*) not in Debian, new [ryoku] package
```

Debian build order (stages; each stage only needs the previous ones installed in the build chroot):

0. **Toolchain/base from the archive** (bpo on trixie): golang-1.26, rustc/cargo, Qt6 dev, hyprland-dev + libhyprcursor-dev + hyprcursor-util (trixie-bpo/forky/sid), meson, cmake. If the port builds its own Hyprland stack instead of Debian's: prior-art order `wayland wayland-protocols xkbcommon libinput lua hyprwayland-scanner hyprutils hyprlang hyprcursor hyprgraphics hyprland-protocols hyprwire aquamarine hyprland` (`debian13-stripped/tools/build-debs.sh:33-40`), with gcc-16 for Hyprland >= 0.56 (`:24-26`).
1. **New third-party packages Debian lacks** (no edges among them): quickshell (trixie main, resolute), uv (trixie, resolute), gpu-screen-recorder (trixie, resolute), niri, matugen, wl-clip-persist, adw-gtk3, zsh-history-substring-search, JetBrainsMono Nerd font, Material Symbols font, hyprsunset (resolute), Hyprland stack (resolute: 0.53.3 is too old for the Lua config), limine (only if kept), ble.sh / dualsensectl / xpadneo-dkms backports (trixie, resolute where missing).
2. **Leaves with no internal build or runtime edges:** ryoku-archive-keyring, gpk, prowl-agent, ryoku-oh-my-zsh, ryoku-cursors (needs hyprcursor-util from stage 0), ryoku-cursor-material, fonts-space-grotesk, fonts-maple-mono-nf, broadcom-bt-firmware, game-devices-udev, asusctl, xwayland-satellite, ryoku-palette-bridge, ryomotion (needs gpu-screen-recorder at install time only), limine stack (if kept).
3. **Hyprland-ABI packages** (build against stage-0 hyprland-dev; rebuild on every Hyprland upload): hypr-dynamic-cursors, ryoku-hypr-plugins, hyprglass, imgborders, ryoku-keysounds, hyprland-preview-share-picker.
4. **Monorepo set** (one source in shape A): ryoku-shell, ryoku-hub, ryoku, ryoku-blobs, ryoku-rashin, ryogami, ryoku-desktop, ryoku-desktop-hyprland, ryoku-desktop-niri. Build-time order inside the set is free; install-time they need stages 1-3 present in the repo.
5. **Imported:** ryotunes deb (from its own release).
6. **Gate:** install `ryoku-desktop` (+ `ryoku-desktop-niri` beside it) from the freshly indexed repo in each target container, as `container-install.sh` does today.

---

## 6. Creator infrastructure to re-point

Placeholders: `<repo-host>`, `<iso-host>`, `<docs-host>`, `<your-domain>`, `<your-org>`, `<your-repo>`, `<your-key-fpr>`, `<maintainer>`.

### 6.1 Release/packaging scope (this report)

| Item | Cite | What it is | Re-point to |
|---|---|---|---|
| `https://repo.ryoku.dev/stable/$arch` | `release/packages/README.md:4`; `installation/backend/lib/deploy.sh:64`; `installation/iso/pacman.conf:27` | client Server line | deb822 `URIs: https://<repo-host>/stable/` |
| default mirror for byte adoption | `release/repo/build-repo.sh:125` (`RYOKU_REPO_MIRROR` default) | build input | `https://<repo-host>/stable/` |
| log text | `release/repo/build-repo.sh:6,256` | | text |
| ISO bake source | `.github/workflows/publish-repo.yml:448` | repo URL passed to ISO build | `https://<repo-host>/releases/<tag>/` |
| layout comment | `.github/workflows/publish-repo.yml:3-11` | | |
| `RepoBase` | `ryoku/cli/internal/sys/release.go:24-28`; `ryoku/cli/internal/updater/update.go:1282` | channel URL builder | `https://<repo-host>` |
| ISO host | `.github/workflows/build-iso-reusable.yml:119-122` (`RYOKU_ISO_PUBLIC_BASE=https://iso.ryoku.dev/stable`), `:427` | manifest URLs | `https://<iso-host>/...` |
| Release key fingerprint | `release/repo/build-repo.sh:37`; `ryoku/shell/deploy.sh:659`; `release/packages/ryoku-keyring/ryoku-trusted:1`; `release/packages/ryoku-keyring/README.md:22-23`; `release/CHANGELOG.md:922` | signing identity | `<your-key-fpr>` |
| Release public key | `keys/ryoku-release-key.pub.asc`; `release/packages/ryoku-keyring/ryoku.gpg`; exported per ISO at `build-iso-reusable.yml:398-403` | | new key |
| Private key secrets | `secrets.GPG_PRIVATE_KEY` (`publish-repo.yml:83,202`; `build-iso-reusable.yml:131,379`; `refresh-ryotunes.yml:43`), `secrets.GPG_PASSPHRASE` (`build-iso-reusable.yml:380`) | | the human's secrets |
| R2 bucket | `bin/ryoku-r2-config:10-19` (`provider = Cloudflare`, `endpoint = ${R2_ENDPOINT}`); secrets `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`, `R2_BUCKET` (`publish-repo.yml:79-82,152-155,336-338,343,377,416`; `build-iso-reusable.yml:128-130,419-422`; `refresh-ryotunes.yml:44-47`; `release-ledger.yml:33-39`) | storage | the human's S3-compatible store or other host |
| Discord | `secrets.DISCORD_WEBHOOK_URL` (`publish-repo.yml:465`; `release-notes.yml:48`; `build-iso-reusable.yml:472`; `discord-notifications.yml:46`); `secrets.DISCORD_COMMIT_WEBHOOK_URL` (`commit-notifications.yml:33`) | announcements | the human's webhook or remove |
| Brand footer "Ryoku Arch : For the sake of power and beauty." | `release-notes.yml:128`; `build-iso-reusable.yml:519`; `commit-notifications.yml:61`; `discord-notifications.yml:62` | | text |
| brand images via raw.githubusercontent | `release-notes.yml:127`; `build-iso-reusable.yml:484` (both use `$GITHUB_REPOSITORY`, auto re-point on a fork) | | none needed |
| ryotunes source repo | `release/repo/import-ryotunes.sh:9,34,46` (`RYOKU_RYOTUNES_REPO` default `ryoku-dev/ryotunes`); `ryoku/cli/internal/ryotunesrelease/client.go:37`; `ryoku/cli/internal/updater/ryotunes.go:14`; `docs/updates.md:58,77` | | `<your-org>/ryotunes` |
| ryomotion fork | `release/packages/ryomotion/PKGBUILD:4,26,34`; appId `dev.ryoku.ryomotion` (`:57`) | | `<your-org>/ryomotion` or keep |
| creator-owned upstreams | `release/packages/gpk/PKGBUILD:8,16,23-24` (neur0map/glazepkg); `release/packages/prowl-agent/PKGBUILD:4,24,31` (neur0map/prowl-agent) | third-party binaries/sources | keep or fork |
| Maintainer / homepage | `# Maintainer: Ryoku <releases@ryoku.dev>` line 1 of every recipe except `blesh` and `asusctl` (`Ryoku CI <ci@ryoku.local>`, `asusctl/PKGBUILD:1`); `url="https://ryoku.dev"` in the 12 monorepo recipes (e.g. `ryoku-desktop/PKGBUILD:16`) | | `Maintainer: <maintainer>`, `Homepage: https://<your-domain>` |
| Arch/CachyOS packager key | `.github/workflows/publish-repo.yml:296-297` (`F3B607488DB35A47` via keyserver.ubuntu.com) | base-image keyring recovery | delete (Arch-only) |
| CI throwaway key identity | `installation/tests/build-ryoku-repo.sh:45` (`ci@ryoku.local`) | | cosmetic |
| Branch model names | `main`, `unstable-dev`, tag `unstable-dev-latest`, rolling release `unstable` (`publish-repo.yml:26-29,119-131`; `release-channel-versions.yml:81-95`; `release-notes.yml:179-180`; `delivery-check.yml:10-12,39`) | | keep or rename consistently |

### 6.2 Repo-wide (from the full sweep)

| Category | Cites | Re-point to |
|---|---|---|
| `repo.ryoku.dev` in installer/CLI/tests | `installation/backend/lib/deploy.sh:64,201`; `installation/backend/lib/network.sh:186,195,207`; `installation/iso/build.sh:78,104,239`; `installation/iso/offline-repo.sh:22`; `installation/tests/install-vm.py:196`; `ryoku/shell/deploy.sh:660`; `ryoku-shell-installer/engine.go:34`; `ryoku-shell-installer/detect.go:227`; `ryoku-shell-installer/main.go:512`; tests `ryoku/cli/internal/sys/release_test.go:27-51`, `ryoku/cli/internal/doctor/doctor_pacnew_test.go:10,41`; i18n strings in 37 `ryoku/i18n/catalog/*.json` (regenerate via `ryoku/i18n/tools/sync.py`) | `<repo-host>`; path shape changes (apt layout), so rewrites not string swaps |
| `iso.ryoku.dev` | `README.md:21` (badge reading `latest.json`) | `<iso-host>` |
| `docs.ryoku.dev` | `installation/tui/main.go:33,2595` | `<docs-host>` |
| `ryoku.dev` site | `README.md:21,26,43,188` | `<your-domain>` |
| `releases@ryoku.dev` | key UID; `README.md:196`; `release/CHANGELOG.md:922` | `<maintainer>` |
| GitHub `ryoku-dev/ryoku-arch` (code) | `bin/ryoku-recovery:8,35`; `bin/ryoku-track:11,26`; `bin/ryoku-project-bootstrap:14,22-23`; `ryoku-shell-installer/engine.go:29`; `ryoku-shell-installer/install.sh:7,15`; `ryoku/cli/recovery.go:13`; `ryoku/cli/track.go:16`; `ryoku/cli/internal/updater/commits.go:33`; `ryoku/cli/internal/doctor/doctor.go:36`; `ryoku/wm/hyprland/config_plugins_tier.go:83` | `<your-org>/<your-repo>` |
| GitHub `ryoku-dev/ryoku` (docs) | `README.md:22,218,292`; `CONTRIBUTING.md:168,171`; `SECURITY.md:16`; `.github/ISSUE_TEMPLATE/config.yml:4`; `ryoku-shell-installer/README.md:12,104` | `<your-org>/<your-repo>` (code and docs use two different slugs for one repo) |
| `ryoku-dev/ryostore` | `ryoku/apps/ryostore/backend/paths.go:12,16`; `ryoku/shell/ryogami/wall-ui/qml/wallpaper/RyowallsSource.qml:23`; `ryoku/hub/backend/ricepublish.go:92`; `ryoku/cli/plugin_share.go:30-31`; `system/extras/README.md:9`; `docs/plugins.md:544` | `<your-org>/ryostore` |
| Personal accounts | `.github/FUNDING.yml:1-2` (neur0map, Ko-fi ryokuarch); `CODE_OF_CONDUCT.md:56`; `SECURITY.md:18`; `installation/tui/main.go:37,39,2407` (Discord invite, x.com/neur0map) | the human's |
| Discord invite `discord.gg/8KjBmUEyKA` | `README.md:23`; `installation/tui/main.go:37` | the human's or remove |
| GitHub Projects | `secrets.PROJECTS_TOKEN`, `vars.PROJECT_NUMBER`, `vars.PROJECT_URL` (`project-auto-add.yml:30-31`; `project-roadmap-export.yml:29,42`; `project-triage.yml:34-36`); `repository_dispatch: roadmap-refresh` from the creator's site (`project-roadmap-export.yml:12-14`) | the human's board or remove |
| OpenRouter i18n | `secrets.RYOKU_I18N_KEY`, `vars.RYOKU_I18N_MODEL` (`i18n.yml:64-66`) | optional |
| Browser add-on ID `ryoku-theme@ryoku.arch` | `ryoku/browser/manifest.firefox.json:6`; `ryoku/cli/internal/doctor/reconcile_browser.go:19`; `reconcile_zen.go:56` | an ID, no infrastructure |
| Creator workspace residue | `UNPUSHED-REVIEW.md:3,18,29` (`/home/nero/Work/ryoku-arch`, `/home/nero/Work/ryoku-cachy`) | delete |
| Arch mirrors (Arch infra, not creator) | `installation/backend/lib/mirrors.sh`, `installation/backend/lib/network.sh`, `installation/iso/airootfs/etc/pacman.d/mirrorlist`, `installation/iso/offline-repo.sh`, `installation/tests/install-vm.py:150`, `installation/tui/system.go`, `ryoku-shell-installer/engine.go`, `ryoku/apps/ryovm/bin/ryovm`, `tests/install-mirrors.sh` | Debian/Ubuntu mirrors |

Complete list of Actions secrets/vars: `DISCORD_COMMIT_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`, `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE`, `PROJECTS_TOKEN`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`, `R2_BUCKET`, `RYOKU_I18N_KEY` (secrets); `PROJECT_NUMBER`, `PROJECT_URL`, `RYOKU_I18N_MODEL` (vars). No `ghcr.io`/`quay.io` images; container images used: `archlinux:latest` (`publish-repo.yml:71,275,318`; `install-test.yml:34,139`; `refresh-ryotunes.yml:32`; `release-ledger.yml:21`; `build-iso-reusable.yml:187`), `cachyos/cachyos:latest` (`publish-repo.yml:275`; `install-test.yml:34`).

---

## Docs vs code disagreements found

1. `release/packages/README.md:57`: ryoku-hub "needs network at build time"; code builds offline from a committed vendor tree (`ryoku-hub/PKGBUILD:7-9,25`).
2. `release/packages/README.md:52-54`: gpk and ryoku-keyring are "the exceptions" that fetch upstream; about 20 recipes fetch upstream sources (§1.5).
3. `release/packages/README.md:9-37` lists 10 of the 34 packages.
4. `docs/updates.md:79-81`: [ryoku] builds ryotunes from a pinned source tarball; code imports the official prebuilt package (`build-repo.sh:199-204`) and no recipe exists.
5. `release/repo/build-toolchain.packages:71-84`: pnpm/nodejs/webkit2gtk/libappindicator "for ryotunes' PKGBUILD", which no longer exists.
6. `docs/development.md:98-100`: a newly listed package "reaches only fresh installs"; `docs/updates.md:230-241,382-392` and `reconcileManifest` deliver it on update.
7. `docs/development.md:121-125` names four packages built from source; 12 monorepo recipes build from source.
8. `release/packages/ryogami/PKGBUILD:37-39`: "no vendor/ tree to carry"; `ryoku/shell/ryogami/daemon/vendor/modules.txt` exists.
9. `release/packages/ryoku-palette-bridge/PKGBUILD:22-23`: GOFLAGS from the publish container; none set in `publish-repo.yml`.
10. `release/packages/xwayland-satellite/PKGBUILD:9-11`: no tagged release carries the fix; upstream v0.8.3 does and Arch extra ships 0.8.3-1.
11. `release/repo/build-repo.sh:99-101`: imgborders clones from Codeberg; recipe uses the vendored bundle (`imgborders/PKGBUILD:23-28`).
12. `CONTRIBUTING.md:112-114`: Go programs and Ryoku.Blobs "ship prebuilt in the ISO"; `docs/development.md:121-125` and the recipes say they come from the signed repo.
13. `CONTRIBUTING.md:118`, `docs/development.md:134`: every commit passes the hooks; nothing enables `core.hooksPath`.

## Issues / risks (cross-package)

- **Go 1.26 on trixie:** `ryoku-shell`, `ryoku-hub` (1.26.4), `ryoku-rashin`, `ryoku-desktop`'s app helpers and `prowl-agent` (1.26.4) need Go 1.26; trixie main has 1.24, so trixie builds require `trixie-backports` (`golang-1.26` 1.26.9 or `golang-go` 1.27). With `GOTOOLCHAIN=local` an older compiler fails instead of downloading.
- **No hermetic builds today:** makepkg fetches from GitHub, Codeberg, gitlab.com, nodejs.org, npmjs, services.gradle.org, Maven Central and GraalVM releases; `build-repo.sh` retries because of it (`:99-114`). Debian offline builds need every item in §1.5 vendored.
- **Non-reproducible bytes under immutable names** stays a requirement on Debian (apt hash mismatch instead of pacman's size error); the adopt-published logic must be ported, keyed on `Package_Version_Arch.deb`.
- **Per-package signatures disappear:** apt trusts `.deb` files only through `InRelease` -> `Packages` hashes; the frozen release dirs are only as trustworthy as their signed indexes.
- **Recommends semantics:** if optdepends are mapped to `Recommends` instead of `Suggests`, apt installs them by default on fresh installs (matching the ISO pacstrap) but also on `ryoku update` boxes the first time they appear, which the Arch design avoided (`ryoku-desktop/PKGBUILD:91-95`).
- **Version pins across sources:** in shape B every monorepo source must be uploaded together; a missing upload leaves `ryoku-desktop` uninstallable (the same "partial upgrade fails loudly" intent as `ryoku-desktop/PKGBUILD:21-24`).
- **Hyprland ABI churn:** every Hyprland upload in the chosen suite (bpo/forky/sid move often) breaks all six plugin packages until rebuilt; Debian's `${hyprland:ABI}` makes apt refuse the upgrade instead of loading a mismatched `.so`.
- **Package-name collisions with Debian:** `xpadneo-dkms`, `dualsensectl`, `quickshell`, `uv`, `gpu-screen-recorder`, `hyprland*` exist in some Debian suites; the origin pin (§2.5.5) makes [ryoku] win even when Debian's version is newer, which also blocks Debian security updates for those names.
- **Sandbox env filtering:** sbuild passes only whitelisted environment variables; `RYOKU_PKGVER`, `RYOKU_RELEASE`, `RYOKU_CHANNEL` (`build-repo.sh:83-97`) must be passed explicitly or written into `debian/changelog`/a generated file before the build.
- **Host side effect of this investigation:** running `gpg --show-keys` on the key created an empty `/home/me/.gnupg/` (`pubring.kbx`, `trustdb.gpg`, no keys); removing it was blocked by the permission system, so it is still there.

## Questions for the human

1. **Source-package shape.** A: one `3.0 (native)` source for the monorepo (exact pins via `${binary:Version}`, one ~300 MB source per build, plugins/oh-my-zsh/keysounds stay separate). B: one source per PKGBUILD (mirrors Arch, 300 MB tree duplicated per source, pins via a substvar, all sources must publish together).
2. **Repo tool.** apt-ftparchive (stateless, closest to `build-repo.sh`, no by-hash), reprepro (persistent db, one version per suite), or aptly (persistent db, native snapshots + `publish switch` for the stable pointer, native S3 publish, by-hash).
3. **Hosting.** S3-compatible bucket (today's model, costs), GitHub Pages (1 GB site, 100 MB per file), GitHub Releases flat repos (natural per-tag freezing, flat layout only), or own server.
4. **Channel layout.** D1 per-channel repo roots (CLI switches `URIs`, pools duplicated, keeps channel-specific `ryoku-desktop`) or D2 one root with suites (shared pool; requires `ryoku-desktop` to stop embedding `CHANNEL=` or carry per-channel versions).
5. **New signing key.** Who holds it (GitHub secret only, or offline primary + CI subkey), algorithm (ed25519 works with trixie's sqv), expiry, and whether `.deb` files should also carry `debsigs` signatures (apt ignores them).
6. **Debian packages that already exist in some suites** (ble.sh, dualsensectl, xpadneo-dkms, bibata-cursor-theme, quickshell, uv, gpu-screen-recorder, hyprland-plugin-hyprbars/-hyprfocus, Hyprland stack): use Debian's where present (fewer builds, Debian security updates, but versions and paths differ from Arch: plugins live in `/usr/lib/x86_64-linux-gnu/hyprland/plugins/lib*.so` without `.abi` receipts) or always ship [ryoku] builds (Arch parity, pin blocks Debian updates).
7. **Hyprland source.** Debian's hyprland (trixie-bpo 0.55.2, forky/sid 0.56.2; enables `${hyprland:ABI}`) or the port's own stack (prior art in `debian13-stripped`, gcc-16 needed on trixie for >= 0.56, no `debian-abi-helper`).
8. **Limine stack.** Port limine + limine-entry-tool + limine-snapper-sync to Debian (no upstream Debian install tree, no mkinitcpio) or drop both packages with a different boot chain (owned by the boot report).
9. **ryomotion and ryotunes builds.** Fully vendored offline builds (large component tarballs, refresh tooling) or CI builds with network (simpler, not reproducible in sbuild).
10. **CachyOS ISO variant and container leg.** Drop them, or replace with a different variant (for example an alternative kernel); there is no Debian counterpart to the CachyOS repo layer.
11. **`/etc` files** (`/etc/ryoku-release`, logind lid drop-in, two modules-load files): keep as conffiles at the Arch paths (remove leaves them, conffile prompts on seeded files) or move to `/usr/lib/...` vendor paths (requires code changes in the CLI/doctor that name the `/etc` paths).

## Cross-cutting findings (other subsystems must know)

- **QML import path:** Debian's `QT_INSTALL_QML` is `/usr/lib/x86_64-linux-gnu/qt6/qml`. Hardcoded `/usr/lib/qt6/qml` readers: `ryoku/shell/ipc/daemon.go:411`, `installation/tests/container-install.sh:184-185`, `bin/ryoku-dev-lint-qml:28`; comments in `ryoku/shell/environment.d/ryoku-session.conf:11`, `ryoku/hyprland/modules/env.lua:67`, `ryoku/shell/deploy.sh:523`; 18 git symlinks in `ryoku/lockscreen/qylock/quickshell-lockscreen/imports/QtGraphicalEffects/` point at `/usr/lib/qt6/qml/Qt5Compat/GraphicalEffects/` and dangle on Debian. `qmllint` stays at `/usr/lib/qt6/bin/qmllint`.
- **QML module packages:** Arch `qt6-declarative` is one package; Debian needs the per-module `qml6-module-*` list from the ryoku-desktop table (derived from actual imports).
- **`wheel` group:** 11 polkit rules grant on `isInGroup("wheel")`: `system/hardware/bluetooth/54-ryoku-bluetooth-a2dp.rules`, `system/hardware/gpu/45-ryoku-gpu-mux.rules`, `system/policy/52-ryoku-timedate.rules`, `system/hardware/network/{48-ryoku-wifi-regdom,49-ryoku-wifi-powersave,50-ryoku-dns,51-ryoku-wifi-backend,55-ryoku-network-kill}.rules`, `system/hardware/power/{47-ryoku-power,53-ryoku-game-tune}.rules`, `system/containers/46-ryoku-docker.rules`. Debian/Ubuntu admins are in `sudo`; the installer must create `wheel` or the rules must test `sudo`.
- **PATH:** `ryoku/shell/environment.d/ryoku-session.conf:16` sets `PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin`, dropping `/usr/sbin`; on Debian `iw` and `nft` live in `/usr/sbin` (Arch merges sbin into bin), so helpers calling them by bare name from the session break.
- **dpkg lock:** anything that waits on `/var/lib/pacman/db.lck` (`system/hardware/power/ryoku-power-cutover:960`) must probe dpkg's fcntl locks instead; the lock files always exist on Debian.
- **Arch-only paths used from maintainer-script helpers:** `/etc/conf.d/wireless-regdom` (`system/hardware/network/ryoku-wifi-regdom:10,32`), `/etc/limine-entry-tool.d/` + `limine-mkinitcpio` (`system/hardware/display/ryoku-hw-backlight-fix:15-16,39,78-79`), limine sync in `system/boot/ryoku-boot-apply:27-62`.
- **Channel state file:** the CLI's channel is the `[ryoku]` Server line in `/etc/pacman.conf` (`ryoku/cli/internal/sys/release.go:35-37,53-120`); on Debian it becomes `URIs:` (or `Suites:`) in `/etc/apt/sources.list.d/ryoku.sources` plus the origin pin; `ryoku track`/`rollback` need `apt-get install --allow-downgrades` and `apt-get update` with the pin at 1001.
- **Release metadata:** `release.json` / `manifest.json` / `releases/index.json` formats are distro-neutral; only the paths (`x86_64/`) change with the apt layout (`bin/ryoku-release-ledger:92-101`, `release.go:92-96`).
- **ryotunes third channel:** in-client updater installs `.pkg.tar.zst` with `pacman -U` (`docs/updates.md:65-70`); needs a `.deb` asset and `apt-get install ./file.deb`.
- **`stash-install.sh`** routes Arch packages to `pacman -U` and unpacks `.deb` into `~/.local` (`ryoku/shell/scripts/stash-install.sh:40-58,158-159`); inverted on Debian.
- **`/etc/bluetooth/main.conf`** is a bluez conffile on Debian; in-place edits by `ryoku-bluetooth-tune` create conffile prompts on bluez upgrades.
- **Kernel headers metapackage differs per base:** `linux-headers-amd64` (Debian), `linux-headers-generic` (Ubuntu).
- **resolute gaps:** no quickshell, no uv, no gpu-screen-recorder, no hyprsunset, Hyprland 0.53.3; Ubuntu's `live-build` (3.0~a57) is unusable for the ISO.
- **trixie main gaps:** no Hyprland stack, no quickshell, no hypridle/hyprpicker, Go 1.24 (bpo provides all of these except uv and gpu-screen-recorder).

## Debian package names needed by this section (flat list)

adw-gtk3 (new), apt, apt-utils, appmenu-gtk3-module, aptly, ble.sh, bluez, broadcom-bt-firmware (new), brightnessctl, btrfs-progs, build-essential, cargo, cava, clang, cliphist, cmake, curl, debhelper, desktop-file-utils, devscripts, dkms, dose-distcheck, dpkg-dev, dualsensectl, efibootmgr, equivs, fakeroot, ffmpeg, fish, fonts-inter, fonts-jetbrains-mono-nerd (new), fonts-maple-mono-nf (new), fonts-material-symbols (new), fonts-noto-cjk, fonts-noto-color-emoji, fonts-noto-core, fonts-space-grotesk (new), gammastep, game-devices-udev (new), gcc, git, gnome-themes-extra, gnupg, golang-1.26-go, golang-go, gpk (new), gpu-screen-recorder, grim, gtk-update-icon-cache, hicolor-icon-theme, hyprcursor-util, hypridle, hyprland, hyprland-dev, hyprland-preview-share-picker (new), hyprpicker, hyprpolkitagent, hyprsunset, imagemagick, inotify-tools, iw, jq, libasound2t64, libavcodec-dev, libavformat-dev, libavutil-dev, libayatana-appindicator3-dev, libcairo2-dev, libcanberra-dev, libcanberra0, libclang-dev, libdbus-1-dev, libdrm-dev, libgtk-3-0t64, libgtk-4-dev, libgtk4-layer-shell-dev, libhidapi-dev, libhyprcursor-dev, libinput-dev, libkf6syntaxhighlighting6, libmpv-dev, libnotify-bin, libnotify4, libnss3, libpam-u2f, libpango1.0-dev, libpixman-1-dev, libqt6core5compat6, libqt6multimedia6, libqt6svg6, libssl-dev, libswscale-dev, libudev-dev, libusb-1.0-0-dev, libwayland-bin, libwayland-dev, libwebkit2gtk-4.1-dev, libxcb-cursor-dev, libxcb1-dev, libxkbcommon-dev, librsvg2-bin, limine (new, if kept), linux-headers-amd64, linux-headers-generic, lintian, live-build, llvm, matugen (new), meson, mmdebstrap, mpv, mpv-mpris, nftables, niri (new), ninja-build, nodejs, papirus-icon-theme, pamu2fcfg, pipewire, pipewire-bin, pkgconf, playerctl, power-profiles-daemon, prowl-agent (new), python3, qalc, qml6-module-org-kde-syntaxhighlighting, qml6-module-qt-labs-folderlistmodel, qml6-module-qt5compat-graphicaleffects, qml6-module-qtmultimedia, qml6-module-qtqml, qml6-module-qtqml-models, qml6-module-qtqml-workerscript, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-dialogs, qml6-module-qtquick-effects, qml6-module-qtquick-layouts, qml6-module-qtquick-shapes, qml6-module-qtquick-templates, qml6-module-qtquick-window, qt6-base-dev, qt6-declarative-dev, qt6-image-formats-plugins, qt6-multimedia-dev, qt6-shader-baker, qt6-shadertools-dev, qt6-svg-plugins, qt6-wayland, qtwayland5, quickshell, rclone, reprepro, rtkit, rustc, ryoku-archive-keyring (new), ryoku-cursor-material (new), ryoku-cursors (new), ryomotion (new), ryotunes (new), sbuild, slurp, snapper, sqlite3, tesseract-ocr, tesseract-ocr-eng, udev, unzip, upower, uv, wayland-protocols, weston, wf-recorder, wl-clip-persist (new), wl-clipboard, wtype, x11-apps, xcur2png, xdg-desktop-portal, xdg-desktop-portal-gnome, xdg-desktop-portal-gtk, xdg-desktop-portal-hyprland, xpadneo-dkms, xwayland, xwayland-satellite (new), yt-dlp, zbar-tools, zenity, zsh, zsh-autosuggestions, zsh-history-substring-search (new), zsh-syntax-highlighting.

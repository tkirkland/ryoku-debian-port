# Ryoku CLI subcommands outside update/rollback/doctor: Debian port facts

Scope: commit 98a0368. All Ryoku cites are relative to the repo root.
`ryoku/cli/vendor/ryoku-wm/*.go` is byte-identical to `ryoku/wm/*.go`
(`diff -rq` shows only tests and subdirs missing from vendor), so wm cites use
`ryoku/wm/…`. The module wiring is `replace ryoku-wm => ../wm` at
`ryoku/cli/go.mod:18`. Debian/Ubuntu claims cite sources.debian.org,
git.launchpad.net or packages.debian.org / packages.ubuntu.com file lists, which
I fetched read-only.

Dispatcher (`ryoku/cli/main.go:48-95`):

- **reload** → `sys.Run("ryoku-shell","reload")` at :66
- **wm** → `cmdWm` at :68
- **recovery** at :72
- **track** at :74
- **plugin** at :76
- **keyring** at :84
- **security-key** at :86
- **keyboard** at :88
- **import** at :90

Process-wide setup: `scrubQuickshellCrashEnv()` at :41, and `i18n.Use("")` at
:42, which reads `/usr/share/ryoku/i18n` (`ryoku/i18n/i18n.go:30`). That
directory is laid by `release/packages/ryoku-desktop/PKGBUILD:546-548`.

---

## 1. Per-subcommand

### 1.1 `ryoku wm` (`ryoku/cli/wm.go`, `ryoku/wm/*.go`)

**Dispatch** (wm.go:26-51): `status`, `caps`, `state`, `act`, `session`,
`config`, `reset-paths`, `use`.

**Provider resolution:**

- `wm.Open()` runs `Detect()` and sets the binary to `ryoku-wm-<name>`
  (client.go:45-52). `OpenNamed(name)` does the same for a named provider
  (client.go:56-61).
- `Detect()` order (detect.go:213-245):
  1. `RYOKU_WM`
  2. a live session handle: `HYPRLAND_INSTANCE_SIGNATURE`, dialled at
     `$XDG_RUNTIME_DIR/hypr/<sig>/.socket.sock` with `/tmp/hypr/...` as fallback
     (detect.go:46-59, 63-75); or `NIRI_SOCKET` (detect.go:48)
  3. `XDG_CURRENT_DESKTOP` components (detect.go:224-231)
  4. an existing `~/.config/{hypr,niri}` (detect.go:232-243)
- Every verb execs the provider binary through `runContext` (client.go:405-421).
  It uses a process group plus Pdeathsig (client.go:383-397).
- The provider binaries are built and installed by the variant packages, e.g.
  `ryoku-wm-hyprland` → `/usr/bin` at
  `release/packages/ryoku-desktop-hyprland/PKGBUILD:81-83`.

**Verbs:**

- **status** (wm.go:57-83): prints the Detection fields, then
  `ryoku-wm-<n> caps` JSON (client.go:83-102).
- **caps** (wm.go:88-98): JSON from caps. Consumer:
  `ryoku/shell/scripts/ryoku-cmd-nightlight:36`.
- **state** (wm.go:102-114): provider `state` (client.go:235-248). The timeout
  comes from `RYOKU_WM_CALL_TIMEOUT` (wm.go:116-127).
- **act** (wm.go:132-155):
  - Checks the capability, then runs provider `act <id> args`
    (client.go:151-169).
  - Exit codes: 3 for ErrNoProvider, 4 for ErrUnsupported (wm.go:148-153).
- **session** (wm.go:159-165):
  - Provider `session` (client.go:306-311) emits `Exec=Hyprland`
    (`ryoku/wm/hyprland/apply.go:197-201`) or `Exec=niri-session`
    (`ryoku/wm/niri/wayland_session.go:8-13`).
  - Consumer: `ryoku/lockscreen/sddm/setup:134`.
- **config** (wm.go:171-206): prints JSON built from the static maps
  `ConfigDir`, `ConfigSeeds`, `ConfigUserOwned` (detect.go:79-163) plus
  `caps.GeneratedFiles`. Consumer: `ryoku/shell/deploy.sh:721`.
- **reset-paths** (wm.go:215-231): pure Go `ResetPaths` (detect.go:202-204).
  Consumer: `bin/ryoku-recovery:161-162`.
- **use `<name>`** (wm.go:233-332):
  1. Reads the store `~/.config/ryoku/desktop.json` (wm.go:253).
  2. Dry run: `ryoku-wm-<n> apply <store> --preview` (wm.go:263,
     client.go:193-206).
  3. Reclaim preview (wm.go:268, 404-418).
  4. Package name is `ryoku-desktop-<name>` (wm.go:270).
  5. **Checkout box** (`deployedProvider`, wm.go:353-363): `syncLeafScripts`
     copies `<repo>/ryoku/<name>/scripts/ryoku-*` into `~/.local/bin`
     (wm.go:375-398, detect.go:93-98).
  6. **Package box**:
     - `pacman -Si <pkg>` (wm.go:288, 522-525)
     - `sudo pacman -S --needed --noconfirm <pkg>` (wm.go:295)
     - On failure: `sudo pacman -Rdd --noconfirm ryoku-desktop-<active>` and
       retry (wm.go:296-305), gated by `pacman -Qq` (wm.go:529-532)
     - A comment relies on Arch snap-pac snapshotting the transaction
       (wm.go:271-274)
  7. If `/usr/share/ryoku/config` exists (`sys.BaseConfigDir`,
     `ryoku/cli/internal/sys/fsops.go:12-17`), it runs `updater.Materialize()`
     then `doctor.Run(nil)` (wm.go:317-322, 337-347).
  8. With `--remove-previous`, `removePreviousCompositor` runs:
     - `wm.Reclaim`, then `VerifyRemoval`, then
       `sudo pacman -Rns --noconfirm <targets>` (wm.go:426-445).

**Reclaim** (reclaim.go):

- Package lists come from the provider caps `Packages` (reclaim.go:195-201):
  Hyprland list at `ryoku/wm/hyprland/caps.go:66-82`, niri list at
  `ryoku/wm/niri/caps.go:72-81`.
- `pacman -Q` (reclaim.go:204-206).
- `pacman -Rs --print --print-format %n --assume-installed ryoku-desktop-compositor,1 <targets>`
  (reclaim.go:247-267).
- Parses pacman's stdout line `removing X breaks dependency` (reclaim.go:217,
  223-237).
- `pacman -Qi`, summing "Installed Size" in `N.NN KiB/MiB/GiB` format
  (reclaim.go:271-292, 307-325).
- The virtual `ryoku-desktop-compositor` (reclaim.go:213) is provided by the
  variant PKGBUILDs (`release/packages/ryoku-desktop-hyprland/PKGBUILD:43`,
  `…-niri/PKGBUILD:39`).

No hyprpm, hyprctl or `niri msg` calls exist in scope. All of that is behind the
provider binaries.

**Arch-specific:** Partial. status, caps, state, act, session, config and
reset-paths are distro-neutral. `use` and reclaim are pacman-only.

| Interface                                                                       | file:line                                                    | Purpose                            | Arch-specific?   | Debian equivalent                                                                                                             |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `ryoku-wm-<name>` exec (caps/act/apply/state/session)                           | ryoku/wm/client.go:49,59,405                                 | provider seam                      | No               | same, must ship in variant .deb                                                                                               |
| `HYPRLAND_INSTANCE_SIGNATURE`, `NIRI_SOCKET`, `RYOKU_WM`, `XDG_CURRENT_DESKTOP` | ryoku/wm/detect.go:46-48,214,224                             | detection                          | No               | same                                                                                                                          |
| `$XDG_RUNTIME_DIR/hypr/<sig>/.socket.sock`, `/tmp/hypr/...`                     | ryoku/wm/detect.go:53-59                                     | liveness dial                      | No               | same                                                                                                                          |
| `~/.config/ryoku/desktop.json`                                                  | ryoku/cli/wm.go:253                                          | neutral store                      | No               | same                                                                                                                          |
| `/usr/share/ryoku/config`                                                       | ryoku/cli/internal/sys/fsops.go:16; wm.go:317                | packaged base tree (ryoku-desktop) | No (path)        | same path in ryoku-desktop .deb                                                                                               |
| `pacman -Si`                                                                    | ryoku/cli/wm.go:523                                          | availability                       | Yes              | `apt-cache policy <pkg>` (Candidate) / `apt-cache show`                                                                       |
| `sudo pacman -S --needed --noconfirm`                                           | ryoku/cli/wm.go:295,303                                      | install variant                    | Yes              | `sudo apt-get install -y <pkg>`                                                                                               |
| `sudo pacman -Rdd --noconfirm`                                                  | ryoku/cli/wm.go:300                                          | force-drop old variant             | Yes              | `sudo dpkg -r --force-depends` (or one apt transaction `install new old-`)                                                    |
| `pacman -Qq`                                                                    | ryoku/cli/wm.go:530                                          | installed?                         | Yes              | `dpkg-query -W -f='${Status}'`                                                                                                |
| `sudo pacman -Rns --noconfirm`                                                  | ryoku/cli/wm.go:439                                          | remove old compositor              | Yes              | `sudo apt-get purge --autoremove -y`                                                                                          |
| `pacman -Q`                                                                     | ryoku/wm/reclaim.go:205                                      | installed?                         | Yes              | `dpkg-query -W`                                                                                                               |
| `pacman -Rs --print --assume-installed`                                         | ryoku/wm/reclaim.go:251-255                                  | removal plan                       | Yes              | `apt-get -s purge --autoremove …` (apt has no `--assume-installed`; simulate `install <incoming> <outgoing>-` in one command) |
| "removing X breaks dependency" parse                                            | ryoku/wm/reclaim.go:217                                      | blocked targets                    | Yes              | rewrite for apt `-s` output                                                                                                   |
| `pacman -Qi` "Installed Size"                                                   | ryoku/wm/reclaim.go:275-289                                  | size                               | Yes              | `dpkg-query -W -f='${Installed-Size}'` (integer KiB)                                                                          |
| snap-pac comment                                                                | ryoku/cli/wm.go:271-274                                      | rollback snapshot                  | Yes              | Debian `snapper` ships `/etc/apt/apt.conf.d/80snapper` (trixie and resolute file lists)                                       |
| provider `Packages` lists                                                       | ryoku/wm/hyprland/caps.go:66-82; ryoku/wm/niri/caps.go:72-81 | reclaim set                        | Yes (Arch names) | Debian names, see §2                                                                                                          |

### 1.2 `ryoku track` (`ryoku/cli/track.go`)

**Steps:**

1. `parseTrackArgs` takes one channel plus optional `--source` (track.go:49-67).
2. **With `--source`:** only `main` or `unstable-dev` are accepted (track.go:19,
   32-36). `trackFromSource` (track.go:91-110):
   - Runs `bash <repo>/bin/ryoku-track <chan>` if `sys.ResolveRepo()` finds a
     checkout (track.go:92-95).
   - Otherwise it needs `curl`, runs `curl -fsSL <trackURL> -o tmp`, then
     `bash tmp <chan>` (track.go:97-109).
   - `trackURL` =
     `https://raw.githubusercontent.com/ryoku-dev/ryoku-arch/main/bin/ryoku-track`
     (track.go:16).
3. **Otherwise:** `packageChannelFor` maps unstable-dev→testing and main→stable
   (track.go:73-84), then calls `updater.Track(pkg)` (track.go:44).
   `updater.Track` (`ryoku/cli/internal/updater/release.go:126-174`):
   - `sys.PkgInstalled("ryoku-desktop")` = `pacman -Q` (sys.go:47-49).
   - Reads the `[ryoku] Server` from `/etc/pacman.conf` (sys/release.go:37,
     100-120).
   - If source-tracked, `RetireSourceTracking` (sys/repo.go:92-104) removes
     `~/.local/state/ryoku/repo`, the `RYOKU_CHANNEL=` line in
     `~/.config/environment.d/ryoku.conf`, and `hl.env("RYOKU_CHANNEL"` in
     `~/.config/<wmdir>/user.lua`.
   - `SetPackagedChannel` rewrites the Server line (sys/release.go:130-162) via
     `sudo install -D -m 0644 -o root -g root` (sys/release.go:197-213).
   - It also deletes `/var/lib/pacman/sync/ryoku.{db,files}{,.sig}`
     (sys/release.go:169-185, 190).
   - `clearSessionChannelEnv` runs
     `systemctl --user unset-environment RYOKU_CHANNEL` and
     `dbus-update-activation-environment RYOKU_CHANNEL=`
     (updater/release.go:202-206).
   - Finally `Update(--channel-switch)`, which the comment describes as pacman
     `-Syyu` + `-S ryoku-desktop` (updater/release.go:193-196).
   - Channel URLs are `https://repo.ryoku.dev/stable/$arch`,
     `…/channels/testing/$arch` and `…/releases/<tag>/$arch` (sys/release.go:28,
     55-65).

**`bin/ryoku-track`:**

- `sudo pacman -S --needed --noconfirm git go cmake ninja qt6-shadertools wayland base-devel matugen`
  (:36)
- `git clone`/`fetch`/`reset` of `https://github.com/ryoku-dev/ryoku-arch.git`
  into `~/ryoku-arch` (:25-26, 39-54)
- Writes `~/.config/environment.d/ryoku.conf` (:57-58)
- `systemctl --user set-environment` (:62) and
  `dbus-update-activation-environment` (:63)
- `bash $REPO/ryoku/shell/deploy.sh` (:67)
- `pkill -9 -x ryoku-shell` and `pkill -f "quickshell.*hub"` (:68-69), then
  `~/.local/bin/ryoku-shell daemon` (:70)
- Appends `hl.env("RYOKU_CHANNEL",…)` to the hardcoded `~/.config/hypr/user.lua`
  (:75-80)

**Arch-specific:** Yes.

| Interface                                                                                             | file:line                               | Purpose               | Arch-specific?          | Debian equivalent                                                                                                        |
| ----------------------------------------------------------------------------------------------------- | --------------------------------------- | --------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| raw.githubusercontent.com/ryoku-dev/ryoku-arch/main/bin/ryoku-track                                   | ryoku/cli/track.go:16                   | script fetch          | Yes (Arch tree)         | port's own repo/script URL                                                                                               |
| `curl`, `bash`                                                                                        | track.go:97,106,94,109                  | fetch/run             | No                      | curl, bash                                                                                                               |
| `git -C … rev-parse/remote get-url` (ResolveRepo, `~/ryoku-arch` with origin containing "ryoku-arch") | ryoku/cli/internal/sys/repo.go:33,44-47 | find checkout         | Partial (repo name)     | rename                                                                                                                   |
| `/etc/pacman.conf` `[ryoku]` Server                                                                   | sys/release.go:37,100-162               | channel = Server line | Yes                     | `/etc/apt/sources.list.d/ryoku.sources` (URIs/Suites); apt uses no `$arch` in URIs                                       |
| `/var/lib/pacman/sync/ryoku.*`                                                                        | sys/release.go:170-185,190              | drop stale db         | Yes                     | `/var/lib/apt/lists/*ryoku*`, then `apt-get update`                                                                      |
| `sudo install -D …`                                                                                   | sys/release.go:213                      | root write            | No                      | same                                                                                                                     |
| `pacman -Q ryoku-desktop`                                                                             | sys/sys.go:47-49,59                     | installed check       | Yes                     | `dpkg-query -W`                                                                                                          |
| `systemctl --user unset-environment`, `dbus-update-activation-environment`                            | updater/release.go:203-204              | env cleanup           | No                      | same (dbus-user-session / dbus-x11 ship the latter)                                                                      |
| `sudo pacman -S … base-devel matugen`                                                                 | bin/ryoku-track:36                      | build deps            | Yes                     | `apt-get install git golang-go cmake ninja-build qt6-shader-baker libwayland-dev build-essential` (matugen not packaged) |
| `~/.config/hypr/user.lua`                                                                             | bin/ryoku-track:75                      | session env           | No (hardcodes Hyprland) | same                                                                                                                     |

### 1.3 `ryoku recovery` (`ryoku/cli/recovery.go`)

**Steps:**

- Prefers `bash <repo>/bin/ryoku-recovery args` (recovery.go:19-23).
- Otherwise needs curl: `curl -fsSL` then bash (recovery.go:25-37). URL:
  `https://raw.githubusercontent.com/ryoku-dev/ryoku-arch/main/bin/ryoku-recovery`
  (recovery.go:13).

**`bin/ryoku-recovery`:**

- Repo URL `https://github.com/ryoku-dev/ryoku-arch.git` (:8).
- `is_ryoku` checks `ryoku-shell`/`ryoku` on PATH, `/usr/share/ryoku`, the XDG
  dirs, and `^\[ryoku\]` in `/etc/pacman.conf` (:54-62).
- Requires git and go (:70-71).
- Clone, `checkout -f -B`, `reset --hard`, `clean -fdx` into `~/ryoku-arch`
  (:95-110).
- `sudo pacman -Syu --needed --noconfirm $(base.packages)`, guarded by
  `command -v pacman` (:126-138).
- Removes `~/.config/ryoku/user_edits` (:150).
- `go run . wm reset-paths` from the checkout, falling back to
  `ryoku wm reset-paths`, then removes each path (:160-171).
- Removes `~/.config/ryoku/{shell,theme,…,plugins}.json` (:176-178).
- Runs `ryoku/shell/deploy.sh` (:180-183).
- `pacman -Q ryoku-desktop` decides whether to remove `state/repo` and
  `state/deployed` (:191-195).
- `sudo pacman -S --needed --noconfirm ryogami matugen` if `[ryoku]` is in
  pacman.conf (:207-210).

**Arch-specific:** Yes.

| Interface                                                | file:line                  | Purpose              | Arch-specific? | Debian equivalent                            |
| -------------------------------------------------------- | -------------------------- | -------------------- | -------------- | -------------------------------------------- |
| ryoku-arch raw script URL                                | ryoku/cli/recovery.go:13   | fetch                | Yes            | port's URL                                   |
| `/etc/pacman.conf` grep                                  | bin/ryoku-recovery:60,207  | identity / repo gate | Yes            | `/etc/apt/sources.list.d/ryoku.sources`      |
| `system/packages/base.packages` + `pacman -Syu --needed` | bin/ryoku-recovery:127-132 | base reinstall       | Yes            | Debian package list + `apt-get install -y`   |
| `pacman -Q ryoku-desktop`                                | bin/ryoku-recovery:191     | packaged?            | Yes            | `dpkg-query -W ryoku-desktop`                |
| `pacman -S ryogami matugen`                              | bin/ryoku-recovery:209     | wallpaper deps       | Yes            | apt (matugen not in any Debian/Ubuntu suite) |
| `go run . wm reset-paths`                                | bin/ryoku-recovery:161     | seam                 | No             | golang-go                                    |

### 1.4 `ryoku plugin` (plugin.go, plugin_new.go, plugin_share.go, plugin_audit.go)

**Dispatch** (plugin.go:61-84): new, add, remove, list, validate, export, share.

- **add** (plugin.go:222-315):
  1. Treats the argument as a local dir if `<arg>/manifest.json` exists;
     otherwise requires git (:247-250).
  2. Stages in a temp dir: `copyPluginTree`, or `git clone --depth 1` then
     removes `.git` (:265-281).
  3. `validateManifest` (:159-202) checks the reserved ids from the widget
     catalogue
     `/usr/share/ryoku/config/quickshell/shell/modules/bar/barstyles/qsbar/core/widgets.json`,
     falling back to the checkout (:98-109, 113-133).
  4. Runs `auditPlugin` (plugin_audit.go, pure Go, no exec).
  5. Refuses if already installed: `~/.local/share/ryoku/plugins/<id>` (:92-94)
     or a receipt `~/.local/state/ryoku/store/plugins/<id>.json` (:502-508).
  6. `ryostore install plugins <id> --from <src>` (:300, 499).
  7. With `--bar`: `ryoku-plugins-place <id> enabled true` and
     `… host topbarGlyph` (:305-313). The tool resolves to the checkout copy or
     the PATH copy (:137-145).
- **remove** (:317-334): `ryostore remove plugins <id>`, then
  `ryoku-plugins-place <id> forget`.
- **list** (:400-477): merges `RYOSTORE_PLUGINS_DIR`/`RYOKU_PLUGINS_DIR`
  (:481-495), receipts, and `~/.config/ryoku/plugins.json` (:541-566).
- **validate** (:336-375): manifest check plus audit.
- **new** (plugin_new.go:28-110):
  - Embedded template (:23-24).
  - Default directory via `xdg-user-dir DOCUMENTS` (:255-265).
  - Author from `git config user.name/email` (:280-294).
  - `git init/add/commit` (:298-305; gitCommitAs at plugin_share.go:460-467).
- **export** (plugin_share.go:55-133): copies the plugin to `exportRoot`
  (`xdg-user-dir DOCUMENTS`, :35-42), writes `product-manifest.json` and
  `registry-entry.json`, then git init/commit.
- **share** (plugin_share.go:499-545):
  - Uses `gh auth status` (:548) and `gh api user -q .login` (:552).
  - Then `gh repo fork ryoku-dev/ryostore --clone=false` (:571), `gh repo clone`
    (:582), and git remote add upstream
    `https://github.com/ryoku-dev/ryostore.git`, fetch/reset/checkout/push
    (:586-617).
  - Then `gh pr create -R ryoku-dev/ryostore` (:641-647).
  - Without gh: prints the form URL
    `https://github.com/ryoku-dev/ryostore/issues/new?...` (:31, 729-752) and
    runs `xdg-open` (:753-755).
- **audit allowlist** (plugin_audit.go:54-61) names commands only: notify-send,
  wl-copy, nmcli, pactl, playerctl, brightnessctl, pkexec, …

**Packaging:**

- `ryostore` is built from `ryoku/apps/ryostore/backend` (module `ryostore`) to
  `/usr/bin/ryostore` by the Go-helper loop at
  `release/packages/ryoku-desktop/PKGBUILD:304-311`.
- `ryoku-plugins-place` is installed at `PKGBUILD:538-539`. It needs `jq` and
  `flock` (`ryoku/shell/quickshell/plugins/ryoku-plugins-place:17-28`).

**Arch-specific:** No.

| Interface                                                                                            | file:line                                                                     | Purpose               | Arch-specific? | Debian equivalent                                        |
| ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | --------------------- | -------------- | -------------------------------------------------------- |
| `git clone/init/add/commit/push/config`                                                              | plugin.go:276; plugin_new.go:281-304; plugin_share.go:126-130,486-495,586-617 | fetch/scaffold/share  | No             | git                                                      |
| `gh auth/api/repo fork/repo clone/pr create`                                                         | plugin_share.go:548,552,571,582,641                                           | PR submission         | No             | `gh` (absent in forky; present in trixie, sid, resolute) |
| `xdg-user-dir DOCUMENTS`                                                                             | plugin_new.go:256-257; plugin_share.go:36                                     | authoring/export root | No             | xdg-user-dirs                                            |
| `xdg-open`                                                                                           | plugin_share.go:753-754                                                       | open form             | No             | xdg-utils                                                |
| `ryostore`, `ryoku-plugins-place`                                                                    | plugin.go:300,306,309,327,331,499                                             | install/placement     | No             | ship in ryoku-desktop .deb (needs jq, util-linux)        |
| github.com/ryoku-dev/ryostore (issues/new, .git, `-R`)                                               | plugin_share.go:30-31,586,641                                                 | catalogue             | No             | same                                                     |
| `/usr/share/ryoku/config/.../widgets.json`                                                           | plugin.go:98-109                                                              | reserved ids          | No             | same path                                                |
| `~/.local/share/ryoku/plugins`, `~/.local/state/ryoku/store/plugins`, `~/.config/ryoku/plugins.json` | plugin.go:93,503,543                                                          | state                 | No             | same                                                     |

### 1.5 `ryoku keyring` (`ryoku/cli/internal/keyring/*`)

**Dispatch** (keyring.go:82-101): status, set, init, apply-pam. The mode is
stored in `~/.config/ryoku/keyring.json` (keyring.go:43-79).

- **status** (status.go:153-170): `gatherStatus` (status.go:85-127) reads:
  - the PAM file `/etc/pam.d/sddm`, overridable by `RYOKU_PAM_FILE`
    (pam.go:25-30)
  - `pamPresent`, which requires a line whose **first field equals
    `auth`/`session`** and contains `pam_gnome_keyring.so` (pam.go:35-48)
  - autologin from `/etc/sddm.conf` and `/etc/sddm.conf.d/*`
    `[Autologin] User=`, root overridable by `RYOKU_SDDM_CONF_ROOT`
    (status.go:36-83)
  - daemon liveness via D-Bus `NameHasOwner org.freedesktop.secrets`
    (dbus.go:107-117)
  - keyring files under `$XDG_DATA_HOME/keyrings/{default,<name>.keyring}`, with
    a magic-byte probe (probe.go:21-62)
  - An unconfigured box infers unlock-on-login if PAM is wired, else never-ask
    (status.go:89-103).
- **set** (set.go:26-69):
  - unlock-on-login points `keyrings/default` at login, backing up to
    `default.ryoku-bak` (set.go:178-197).
  - `--convert` uses D-Bus `ChangeWithMasterPassword`; `--reset` moves files to
    `keyrings/backup-<ts>/` (set.go:202-219).
  - never-ask uses `CreateWithMasterPassword` with an empty password
    (dbus.go:68-74), or convert/reset.
  - Then `writeConfig`, then `applyPAMHalf` (set.go:229-241). If the content
    would change, it runs
    `pkexec env PKEXEC_UID=<uid> <self> keyring apply-pam <mode>`
    (set.go:245-251).
- **apply-pam** (pam.go:161-173):
  - Requires the file to exist and be writable.
  - unlock-on-login inserts `auth optional pam_gnome_keyring.so` /
    `session optional pam_gnome_keyring.so auto_start` (pam.go:18-21)
    **immediately after `<kind> include system-login`** (pam.go:53-65). A
    missing anchor is an error (pam.go:115-117).
  - Other modes strip every line containing `pam_gnome_keyring.so`
    (pam.go:69-79).
  - Writes atomically via tmp+rename (pam.go:108-148).
- **init** (init.go:24-69): first-login default, called from
  `ryoku/hyprland/modules/autostart.lua:51` and `ryoku/niri/autostart.kdl:41`.
- **Reconcile** (reconcile.go:27-91) is used by doctor
  (`internal/doctor/reconcile_keyring.go:18`). Its remedy string is
  `sudo ryoku keyring apply-pam <mode>` (reconcile.go:65).

**D-Bus** (dbus.go:15-21): service `org.freedesktop.secrets`, path
`/org/freedesktop/secrets`, interfaces:

- `org.freedesktop.Secret.Service.OpenSession("plain")` (:48)
- `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface.{CreateWithMasterPassword,ChangeWithMasterPassword}`
  (:73, :83)
- `org.freedesktop.Secret.Collection.Label` (:94)
- `Service.Collections` (:88)

These come from upstream gnome-keyring, not the distro. godbus is v5.2.2
(`ryoku/cli/go.mod:5`).

**Debian facts:**

- **Stock sddm PAM file is different.** Debian trixie's `/etc/pam.d/sddm`
  (sources.debian.org sddm 0.21.0+git20250502.4fe234b-2 `debian/sddm.pam`) has:
  - `@include common-auth`, `-auth optional pam_gnome_keyring.so`,
    `@include common-session`,
    `-session optional pam_gnome_keyring.so auto_start`
  - **no `system-login`**
  - Ubuntu resolute is the same.
  - forky/sid (git20260819) keeps `-auth … pam_gnome_keyring.so` but has **no**
    session gnome_keyring line.
- **Module path:** `libpam-gnome-keyring` installs
  `/usr/lib/x86_64-linux-gnu/security/pam_gnome_keyring.so`. The code uses the
  bare module name, so no path change is needed.
- **pam-auth-update profile:** `libpam-gnome-keyring` ships
  `/usr/share/pam-configs/gnome-keyring` (Password-Type: Additional,
  `optional pam_gnome_keyring.so`) and its postinst runs
  `pam-auth-update --package`.
- **pkexec** is a separate Debian package (`pkexec`).

**Arch-specific:** Partial. The D-Bus, file and keyring logic is neutral. The
PAM anchor and first-field parsing assume Arch's file.

| Interface                                                      | file:line                             | Purpose               | Arch-specific? | Debian equivalent                                             |
| -------------------------------------------------------------- | ------------------------------------- | --------------------- | -------------- | ------------------------------------------------------------- |
| `/etc/pam.d/sddm`                                              | keyring/pam.go:29                     | SDDM stack            | No (path)      | same path (Debian/Ubuntu sddm ship it; it is a dpkg conffile) |
| anchor `auth/session include system-login`                     | keyring/pam.go:57,93,99               | insert point          | Yes            | `@include common-auth` / `@include common-session`            |
| first field `auth`/`session` only                              | keyring/pam.go:38                     | detect wiring         | Yes in effect  | also match `-auth`/`-session` (Debian stock lines)            |
| `pam_gnome_keyring.so`                                         | keyring/pam.go:19-20                  | module                | No (bare name) | package `libpam-gnome-keyring`                                |
| `/etc/sddm.conf`, `/etc/sddm.conf.d/`                          | keyring/status.go:37-38,82            | autologin             | No             | same                                                          |
| `pkexec env PKEXEC_UID=…`                                      | keyring/set.go:248                    | escalate              | No             | package `pkexec`                                              |
| D-Bus `org.freedesktop.secrets` + gnome-keyring internal iface | keyring/dbus.go:15-21,48,73,83,88,113 | create/rekey keyrings | No             | `gnome-keyring`                                               |
| `$XDG_DATA_HOME/keyrings/*`                                    | keyring/probe.go:25-46                | keyring files         | No             | same                                                          |
| `~/.config/ryoku/keyring.json`                                 | keyring/keyring.go:43-45              | mode                  | No             | same                                                          |

### 1.6 `ryoku security-key` (`ryoku/cli/internal/securitykey/*`)

**Dispatch** (securitykey.go:30-51): status, enroll, remove, set, apply-pam.

**Files:**

- Auth file `~/.config/Yubico/u2f_keys`, overridable by
  `RYOKU_SECURITY_KEY_AUTHFILE` (securitykey.go:18-23).
- Policy `~/.config/ryoku/security-key.json`. It is resolved for the real user
  under sudo/pkexec via `SUDO_UID`/`PKEXEC_UID` (config.go:36-54).

**Subcommands:**

- **enroll** (enroll.go:13-57):
  - Requires `pamu2fcfg`; the error text says "install pam-u2f first"
    (enroll.go:21-22).
  - `pamu2fcfg -o pam://<host> -i pam://<host> [-N] [-V]` (enroll.go:24-26,
    59-69).
  - Appends the credential to the auth file (authfile.go:47-96).
- **status** (status.go:152-169):
  - Device probe: `systemd-cryptenroll --fido2-device=list`, then
    `fido2-token -L` (status.go:74-97).
  - Targets are detected by `pam_u2f.so` substring in each PAM file
    (pam.go:82-92).
- **set `<sudo|polkit|login> on|off`** (set.go:79-96):
  - Requires `pamu2fcfg` and enrolment (set.go:22-34).
  - `applyPAMHalf` (pam.go:185-199) escalates with
    `pkexec env PKEXEC_UID=<uid> <self> security-key apply-pam <t> on|off`
    (pam.go:201-211).
- **set mode / touch-required / pin-verification / user-verification**
  (set.go:41-77): writes the policy, then `rewriteEnabledTargets` rewrites the
  PAM files directly with no escalation (pam.go:167-183).
- **apply-pam** (pam.go:220-236):
  - Target files: `/etc/pam.d/{sudo,polkit-1,sddm}`, root overridable by
    `RYOKU_SECURITY_KEY_PAM_ROOT` (pam.go:14-40). `login` maps to `sddm`
    (pam.go:27-28).
  - The file must exist and be writable (pam.go:148-155, 232-234).
  - Strips all `pam_u2f.so` lines, then **prepends**
    `auth sufficient|required pam_u2f.so openasuser cue origin=pam://<host> appid=pam://<host> userpresence=… [pinverification=1] userverification=…`
    as line 1 (pam.go:42-72, 94-110).

**Debian facts (package file lists):**

- `polkitd` ships `/usr/lib/pam.d/polkit-1` (trixie, forky, sid and resolute),
  **not** `/etc/pam.d/polkit-1`. Arch's `polkit` also ships
  `usr/lib/pam.d/polkit-1` (archlinux.org file list).
- `sudo` ships `/etc/pam.d/sudo` and `/etc/pam.d/sudo-i`.
- `sddm` ships `/etc/pam.d/{sddm,sddm-autologin,sddm-greeter}`.
- `libpam-u2f` installs `/usr/lib/x86_64-linux-gnu/security/pam_u2f.so` and has
  no pam-configs profile.
- `pamu2fcfg` is a separate package (`/usr/bin/pamu2fcfg`).
- `systemd-cryptenroll` is in `systemd-cryptsetup`; `fido2-token` is in
  `fido2-tools`.
- Ubuntu resolute: neither the `sudo` nor the `sudo-rs` file list shows
  `/etc/pam.d/sudo` (where it comes from is unverified).

**Arch-specific:** Partial.

| Interface                                 | file:line                     | Purpose                                            | Arch-specific?                 | Debian equivalent                                                                       |
| ----------------------------------------- | ----------------------------- | -------------------------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------- |
| `/etc/pam.d/sudo`                         | securitykey/pam.go:18,24      | sudo target                                        | No                             | same (Debian also has `sudo-i`, not targeted)                                           |
| `/etc/pam.d/polkit-1`                     | securitykey/pam.go:25-26      | polkit target                                      | Absent on both Arch and Debian | real file is `/usr/lib/pam.d/polkit-1`; copy it to `/etc/pam.d/polkit-1` before editing |
| `/etc/pam.d/sddm`                         | securitykey/pam.go:27-28      | login target                                       | No                             | same                                                                                    |
| `pam_u2f.so` (bare)                       | securitykey/pam.go:52         | module                                             | No                             | `libpam-u2f`                                                                            |
| `pamu2fcfg` + hint "install pam-u2f"      | enroll.go:21-26; set.go:23-24 | enrolment                                          | Hint Yes                       | packages `pamu2fcfg` + `libpam-u2f`                                                     |
| `systemd-cryptenroll --fido2-device=list` | status.go:82                  | probe                                              | No                             | `systemd-cryptsetup`                                                                    |
| `fido2-token -L`                          | status.go:83                  | probe                                              | No                             | `fido2-tools`                                                                           |
| `pkexec env PKEXEC_UID=…`                 | securitykey/pam.go:208        | escalate                                           | No                             | `pkexec`                                                                                |
| `~/.config/Yubico/u2f_keys`               | securitykey.go:22             | pam_u2f auth file (default location, `openasuser`) | No                             | same                                                                                    |

### 1.7 `ryoku keyboard` (`ryoku/cli/internal/keyboard/*`)

**Dispatch** (cmd.go:19-36): status, detect, apply.

- **Desktop layout** comes from `~/.config/ryoku/desktop.json`
  `desktop.input.kb*`, falling back to `hypr.json` (cmd.go:40-77).
- **status** (cmd.go:112-139) runs `Read` (cmd.go:93-110):
  - greeter: `Option "XkbLayout"` in `/etc/X11/xorg.conf.d/00-keyboard.conf`
    (keyboard.go:144-164)
  - console: `KEYMAP=` in `/etc/vconsole.conf` (keyboard.go:168-179)
  - boot image: newest non-fallback match of `/boot/EFI/Linux/*.efi` or
    `/boot/initramfs-*.img`, compared by mtime against `/etc/vconsole.conf`
    (keyboard.go:195-234)
- **detect** (cmd.go:155-163): order is X11, then console (via the
  `consoleToXkb` table, keyboard.go:41-58), then the locale country from `LANG=`
  in `/etc/locale.conf` or `$LANG` (keyboard.go:183-192).
- **apply** (cmd.go:165-204):
  - With no TTY and not root, re-execs
    `pkexec <self> keyboard apply --resolved <l> <v> <o> [--no-boot]`
    (cmd.go:192-201).
  - `ApplySystem` runs
    `localectl set-x11-keymap <layout> "" <variant> <options>`
    (keyboard.go:254-263).
  - `RebuildBootImage` requires `mkinitcpio` and runs `sudo mkinitcpio -P`
    (keyboard.go:268-276).
  - User messages name mkinitcpio (cmd.go:245, 250).
- **xkbrules.go**:
  - Reads `/usr/share/X11/xkb/rules/base.lst`, then `evdev.lst`
    (xkbrules.go:20-23, 38-45, 77-139).
  - Used only by doctor (`internal/doctor/reconcile_kb_layout_code.go:39`), not
    by the subcommand.
  - Other doctor users of this package: `reconcile_keymap.go:40,44,71,76,159`.

**Debian facts (sources.debian.org systemd):**

1. **localectl cannot write.** Debian ships a D-Bus policy that denies
   `SetLocale`, `SetVConsoleKeyboard` and `SetX11Keyboard` on
   `org.freedesktop.locale1`, for root and everyone else. So
   `localectl set-x11-keymap` is refused on every candidate base.
   - trixie 257.13-1~deb13u1:
     `debian/extra/dbus-1/system.d/systemd-localed-read-only.conf`, installed
     unconditionally (`debian/systemd.install:574`).
   - forky/sid 262.x: the same policy renamed
     `org.freedesktop.locale1.read-only.conf` (`systemd.install:549`).
   - Ubuntu resolute: the same file (`debian/systemd.install:577`).
2. **The config files are symlinks.** `debian/extra/tmpfiles.d/debian.conf`
   (trixie, sid, resolute) has `L+ /etc/vconsole.conf - - - - default/keyboard`
   and `L+ /etc/default/locale - - - - ../locale.conf`. So `/etc/vconsole.conf`
   resolves to `/etc/default/keyboard`, which holds
   `XKBMODEL/XKBLAYOUT/XKBVARIANT/XKBOPTIONS` and no `KEYMAP=`.
3. **No systemd vconsole.** Debian builds systemd with `-Dvconsole=false`
   (`debian/rules:84` in trixie, `:76` in sid).
4. **mkinitcpio does not exist** in any Debian or Ubuntu suite. The initramfs
   tool is `initramfs-tools` (`/boot/initrd.img-<kver>`) or `dracut`.
5. **xkb rules match.** `xkb-data` ships
   `/usr/share/X11/xkb/rules/{base,evdev}.{lst,xml}`.

**Arch-specific:** Yes. xkbrules.go alone is No.

| Interface                                                         | file:line               | Purpose           | Arch-specific?                  | Debian equivalent                                                                                                                                 |
| ----------------------------------------------------------------- | ----------------------- | ----------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/vconsole.conf` `KEYMAP=`                                    | keyboard.go:150,168-179 | console layer     | Yes                             | `/etc/default/keyboard` `XKBLAYOUT=` (console-setup); the vconsole path is a symlink to it                                                        |
| `/etc/X11/xorg.conf.d/00-keyboard.conf`                           | keyboard.go:149,154-164 | greeter layer     | Yes (localed writes it on Arch) | not written on Debian; read `/etc/default/keyboard`                                                                                               |
| `/etc/locale.conf` `LANG=`                                        | keyboard.go:184         | locale fallback   | Partial                         | `/etc/default/locale` is a symlink to `../locale.conf` on Debian systemd, so the read works                                                       |
| `localectl set-x11-keymap`                                        | keyboard.go:259         | push layout       | Yes (denied on Debian)          | write `/etc/default/keyboard` and run `setupcon` (console-setup); `dpkg-reconfigure -f noninteractive keyboard-configuration`                     |
| `mkinitcpio -P` via sudo                                          | keyboard.go:269-272     | rebuild initramfs | Yes                             | `update-initramfs -u -k all` (initramfs-tools loads a console keymap only with `KEYMAP=y`, per initramfs.conf(5)) or `dracut --regenerate-all -f` |
| `/boot/EFI/Linux/*.efi`, `/boot/initramfs-*.img`, "fallback" skip | keyboard.go:195-218     | freshness         | Yes                             | `/boot/initrd.img-*`                                                                                                                              |
| `pkexec <self> keyboard apply --resolved`                         | cmd.go:192-201          | escalate          | No                              | `pkexec`                                                                                                                                          |
| `/usr/share/X11/xkb/rules/base.lst`, `evdev.lst`                  | xkbrules.go:21-22       | layout catalogue  | No                              | `xkb-data`                                                                                                                                        |

### 1.8 `ryoku import` (`ryoku/cli/internal/importer/importer.go`)

**Steps:**

1. `parseArgs` (:124-163) handles `--url`, `--keep mine|ryoku` and
   `--undo [ts]`.
2. `runImport` (:185-209) execs `ryoku-hub import scan <src>`.
3. `buildDecisions` (:98-111) settles every clash to `--keep`.
4. Execs `ryoku-hub import apply -` with the decisions JSON on stdin (:199).
5. `runUndo` execs `ryoku-hub import undo [ts]` (:211-233).

The binary name is the constant `ryoku-hub` (:27, 34-46). It is packaged at
`release/packages/ryoku-hub/PKGBUILD:29` → `/usr/bin/ryoku-hub`.

The engine is out of the CLI but is what `import` runs:

- `git clone --depth 1` (`ryoku/hub/backend/import.go:170`)
- `snapper -c root create -c number …` and `snapper -c root cleanup number`,
  best-effort (`import_apply.go:348-349`)
- `luac -p` (`import_apply.go:491-498`)

**Arch-specific:** No for the CLI. Partial for the engine.

| Interface                          | file:line                                 | Purpose          | Arch-specific?                    | Debian equivalent                                                           |
| ---------------------------------- | ----------------------------------------- | ---------------- | --------------------------------- | --------------------------------------------------------------------------- |
| `ryoku-hub import scan/apply/undo` | importer.go:27,186,199,212                | engine           | No                                | ship `/usr/bin/ryoku-hub`                                                   |
| `git clone`                        | ryoku/hub/backend/import.go:170           | `--url` source   | No                                | git                                                                         |
| `snapper -c root …`                | ryoku/hub/backend/import_apply.go:348-349 | snapshot         | Partial (assumes a "root" config) | snapper (best-effort, errors ignored)                                       |
| `luac -p`                          | ryoku/hub/backend/import_apply.go:491,498 | Lua syntax check | No                                | `lua5.4` provides `/usr/bin/luac` via update-alternatives (lua5.4.postinst) |

### 1.9 `ryoku reload`

`ryoku reload` runs `sys.Run("ryoku-shell","reload")` (main.go:66).

`ryoku-shell` is the Go daemon/client in `ryoku/shell/ipc`. It is packaged as
`/usr/bin/ryoku-shell` (`release/packages/ryoku-shell/PKGBUILD:28,37`), which
depends on quickshell, ffmpeg, wayland, jq and uv (:19).

**Client:** sends the line `reload` to `$XDG_RUNTIME_DIR/ryoku-shell.sock`
(falling back to `/tmp`) with a 45 s deadline
(`ryoku/shell/ipc/main.go:18-26, 80-115`).

**Daemon** (`daemon.go:1338-1339`, `reload()` at `:1433-1488`):

1. Runs `ryoku-reload-cover begin` (daemon.go:38-63). That script launches
   `qs -p <dir>` from `~/.config/quickshell/reload-cover` or
   `/usr/share/ryoku/reload-cover`
   (`ryoku/shell/scripts/ryoku-reload-cover:5-8,105-111`). The fallback dir is
   laid by `ryoku-shell/PKGBUILD:61-62`.
2. SIGTERMs each supervised Quickshell component (only `"shell"`,
   daemon.go:31-35).
3. Waits up to 12 s for a new PID that stays up for 3 s.

It does **not** reload the compositor, although the usage text says "restart the
shell + reload Hyprland" (main.go:13, :102).

**Arch-specific:** No. Debian: quickshell is in trixie-backports 0.3.0-1~bpo13+1
and forky/sid 0.3.2-1; it is absent from trixie main and from resolute.

### 1.10 crashenv.go

Unsets `__QUICKSHELL_CRASH_{INFO_FD,DUMP_PID,DUMP_FD,LOG_FD,SIGNAL}` before any
child `qs` runs (`ryoku/cli/crashenv.go:12-22`; called at main.go:41). No
external calls. **Arch-specific:** No.

### 1.11 `internal/ryotunesrelease`

**Consumer:** doctor only. `doctor.go:183` registers `reconcileRyotunes`, which
calls `ryotunesrelease.Ensure` at `internal/doctor/reconcile_ryotunes.go:100`
and `ryotunesrelease.Check` at `:123`. No CLI subcommand calls it directly.

**Flow:**

1. **Installed version:** `pacman -Q ryotunes` (client.go:149-159).
2. **Latest release:**
   - `GET {api}/repos/ryoku-dev/ryotunes/releases/latest`, where `api` =
     `https://api.github.com` or `RYOKU_GITHUB_API` (client.go:37, 93-98;
     discover.go:200-212, UA `ryoku-cli`).
   - Asset contract: `ryotunes-<pkgver>-<pkgrel>-x86_64.pkg.tar.zst` plus
     `.sha256` (discover.go:64-66, 77-118).
   - Download from
     `https://github.com/ryoku-dev/ryotunes/releases/download/<tag>/<asset>`
     (client.go:78; discover.go:265-267).
   - Redirects are allowed only to github.com, api.github.com,
     objects.githubusercontent.com and release-assets.githubusercontent.com
     (client.go:114-119).
   - Cache: `~/.local/state/ryoku/ryotunes-release/latest.json`, TTL 1 h
     (client.go:81; discover.go:128; ryotunesrelease.go:59).
3. **Verify:**
   - sha256, then `pacman -Qip <file>` with `LC_ALL=C` (client.go:164-172).
   - Name must be `ryotunes`, arch `x86_64`, epoch `1:` (ryotunesrelease.go:35,
     40, 52; install.go:62).
   - Ordering via `vercmp` (client.go:290-300).
4. **Install** (client.go:214-243), each step through `sudo` unless already root
   (client.go:264-269):
   - `mktemp -d /var/tmp/ryotunes-release.XXXXXXXXXX`
   - `install -m 0644`
   - `sha256sum`
   - `pacman -U --noconfirm`
   - `rm -rf`

**Arch-specific:** Yes. The package format, `pacman -Q`, `-Qip`, `-U`, `vercmp`
and the `x86_64` arch name are all Arch.

**Debian change:**

- A `.deb` asset contract (`ryotunes_<ver>_amd64.deb`).
- `dpkg-query -W -f='${Version}'`.
- `dpkg-deb -f <file> Package Version Architecture`.
- `dpkg --compare-versions` (exit-code based, not -1/0/1).
- `apt-get install -y <staged.deb>` or `dpkg -i`.
- Arch name `amd64`.

### 1.12 `internal/ryokumanifest` + `cmd/ryoku-manifest`

**Generator:** `cmd/ryoku-manifest` is built and run only at publish time by
`release/repo/build-repo.sh:248-252`. It writes `manifest.json` next to the
channel's `release.json`.

**Inputs** (`ryoku/cli/cmd/ryoku-manifest/main.go:55-86`):

- `system/packages/{base,dev,hardware,aur}.packages`
- every `release/packages/*/PKGBUILD`, parsed for `pkgname=` (generate.go:67-68)
- every `ryoku/wm/*/caps.go` `compositorPackages` literal (generate.go:84-85)

**Content** (generate.go:139-169):

- The first-party lane excludes compositor-declared names and `OptIn` names:
  asusctl, dualsensectl, pam-fprint-grosshack, limine-snapper-sync,
  ryoku-palette-bridge (manifest.go:127-133).
- The provisioned lane is `Apps()`: kitty, fish, blesh, starship, fastfetch,
  yazi, neovim, nautilus, nautilus-python, ryomotion, waifu2x-ncnn-vulkan,
  pavucontrol, songrec, openrgb, gamescope, gamemode, mangohud
  (manifest.go:161-181).

**Runtime consumers:**

- `internal/updater/manifest.go:34-49` (FetchManifest)
- `internal/doctor/reconcile_manifest.go:82,179`
- `internal/doctor/reconcile_shipped_apps.go:31`

**Arch-specific:** Yes.

- PKGBUILD parsing would become `debian/control` `Package:` parsing.
- The AUR lane has no Debian analogue.
- Every listed name needs Debian mapping, e.g. nautilus-python →
  `python3-nautilus`.

---

## 2. Arch names referenced → Debian names (pkgver output)

Columns: trixie | trixie-bpo | forky | sid | resolute. "-" means absent.

| Arch name (where)                                             | Debian name                                | trixie                       | trixie-bpo          | forky                        | sid           | resolute                            |
| ------------------------------------------------------------- | ------------------------------------------ | ---------------------------- | ------------------- | ---------------------------- | ------------- | ----------------------------------- |
| gnome-keyring, pam module + daemon (keyring)                  | gnome-keyring / libpam-gnome-keyring       | 48.0-1                       | -                   | 51.1-3                       | 51.1-3        | 50.0-1                              |
| pam-u2f (enroll.go:22, set.go:24, ryoku-desktop PKGBUILD:160) | libpam-u2f + pamu2fcfg                     | 1.4.0-1                      | -                   | 1.4.0-3+b2                   | 1.4.0-3+b2    | 1.4.0-3build1                       |
| libfido2, `fido2-token` (status.go:83)                        | fido2-tools                                | 1.15.0-1+b1                  | -                   | 1.17.0-2                     | 1.17.0-2      | 1.16.0-2build1                      |
| systemd, `systemd-cryptenroll` (status.go:82)                 | systemd-cryptsetup                         | 257.13-1~deb13u1             | -                   | 262-1                        | 262.1-1       | 259.9-0ubuntu0.1                    |
| systemd, `localectl` (keyboard.go:259)                        | systemd                                    | 257.13-1~deb13u1             | -                   | 262-1                        | 262.1-1       | 259.9-0ubuntu0.1                    |
| polkit, `pkexec` (keyring/securitykey/keyboard)               | pkexec (+ polkitd)                         | 126-2                        | -                   | 127-3                        | 128-1         | 127-2ubuntu1.1                      |
| sddm                                                          | sddm                                       | 0.21.0+git20250502.4fe234b-2 | -                   | 0.21.0+git20260819.da0b64d-1 | same          | 0.21.0+git20250502.4fe234b-2ubuntu3 |
| mkinitcpio (keyboard.go:269)                                  | initramfs-tools (mkinitcpio: - everywhere) | 0.148.4                      | -                   | 0.151                        | 0.151         | 0.151ubuntu1                        |
| (alt)                                                         | dracut                                     | 106-6                        | -                   | 112-7                        | 112-7         | 110-11ubuntu0.1                     |
| xkeyboard-config (xkbrules.go:21)                             | xkb-data                                   | 2.42-1                       | -                   | 2.48-1                       | 2.48-1        | 2.46-2                              |
| console keymap (vconsole)                                     | console-setup / keyboard-configuration     | 1.242~deb13u1                | -                   | 1.249                        | 1.249         | 1.237ubuntu3.1                      |
| git                                                           | git                                        | 1:2.47.3-0+deb13u1           | -                   | 1:2.53.0-1                   | 1:2.55.0-1    | 1:2.53.0-1ubuntu1                   |
| github-cli, `gh` (plugin_share.go)                            | gh (github-cli: -)                         | 2.46.0-3                     | -                   | **-**                        | 2.46.0-4+b1   | 2.46.0-4                            |
| curl (recovery.go/track.go)                                   | curl                                       | 8.14.1-2+deb13u5             | 8.21.0-2~bpo13+1    | 8.22.0-1                     | 8.23.0-1      | 8.18.0-1ubuntu2.8                   |
| xdg-user-dirs                                                 | xdg-user-dirs                              | 0.18-2                       | -                   | 0.20-1                       | 0.20-1        | 0.19-1                              |
| xdg-utils                                                     | xdg-utils                                  | 1.2.1-2                      | -                   | 1.2.1-2                      | 1.2.1-2       | 1.2.1-2ubuntu2                      |
| jq (ryoku-plugins-place)                                      | jq                                         | 1.7.1-6+deb13u3              | -                   | 1.8.2-1                      | 1.8.2-1       | 1.8.1-4ubuntu2                      |
| util-linux, flock                                             | util-linux                                 | 2.41.5-0+deb13u1             | -                   | 2.42.4-1                     | 2.42.4-1      | 2.41.3-3ubuntu2.3                   |
| coreutils (mktemp/install/sha256sum)                          | coreutils                                  | 9.7-3                        | -                   | 9.10-1                       | 9.10-1        | 9.7-3ubuntu2.1                      |
| sudo                                                          | sudo                                       | 1.9.16p2-3+deb13u2           | -                   | 1.9.17p2-9                   | 1.9.17p2-9    | 1.9.17p2-1ubuntu3.2                 |
| (Ubuntu alt)                                                  | sudo-rs                                    | 0.2.5-5+deb13u1              | -                   | 0.2.15-1                     | 0.2.15-1      | 0.2.13-0ubuntu1.2                   |
| lua, `luac` (hub import)                                      | lua5.4                                     | 5.4.7-1+b2                   | -                   | 5.4.9-1                      | 5.4.9-1       | 5.4.8-1build1                       |
| snapper                                                       | snapper                                    | 0.10.6-1.2                   | -                   | 0.10.6-1.3+b1                | 0.10.6-1.3+b1 | 0.10.6-1.3                          |
| quickshell (`qs`, reload cover)                               | quickshell                                 | -                            | 0.3.0-1~bpo13+1     | 0.3.2-1                      | 0.3.2-1       | -                                   |
| go (ryoku-recovery:71, ryoku-track:36)                        | golang-go                                  | 2:1.24~2                     | 2:1.27~1~bpo13+1    | 2:1.27~1                     | 2:1.27~1      | 2:1.26~1                            |
| cmake                                                         | cmake                                      | 3.31.6-2                     | 4.3.4-1~bpo13+1     | 4.3.4-1                      | 4.3.4-1       | 4.2.3-2ubuntu2                      |
| ninja                                                         | ninja-build                                | 1.12.1-1+b1                  | -                   | 1.13.2-1+b1                  | 1.13.2-1+b1   | 1.13.2-1                            |
| qt6-shadertools                                               | qt6-shader-baker / qt6-shadertools-dev     | 6.8.2-3                      | -                   | 6.11.2-2                     | 6.11.2-2      | 6.10.2-1                            |
| wayland                                                       | libwayland-dev / libwayland-bin            | 1.23.1-3                     | -                   | 1.26.0-1                     | 1.26.0-1      | 1.24.0-2                            |
| base-devel (base-devel: -)                                    | build-essential                            | 12.12                        | -                   | 12.12+b1                     | 12.12+b1      | 12.12ubuntu2.26.04.2                |
| matugen (recovery:209, track:36)                              | —                                          | -                            | -                   | -                            | -             | -                                   |
| hyprland (caps)                                               | hyprland                                   | -                            | 0.55.2+ds-1~bpo13+1 | 0.56.2+ds-3                  | 0.56.2+ds-3   | 0.53.3+ds-4                         |
| hyprpolkitagent                                               | hyprpolkitagent                            | -                            | 0.1.3-2~bpo13+1     | 0.2.0-1                      | 0.2.0-1       | 0.1.3-1                             |
| xdg-desktop-portal-hyprland                                   | same                                       | -                            | 1.4.1-1~bpo13+1     | 1.4.1-1                      | 1.4.1-1       | 1.3.11-1build2                      |
| hypridle                                                      | same                                       | -                            | 0.1.8-1~bpo13+1     | 0.1.8-1+b1                   | 0.1.8-1+b1    | 0.1.7-2                             |
| hyprpicker                                                    | same                                       | -                            | 0.4.7-1~bpo13+1     | 0.4.7-1+b2                   | 0.4.7-1+b2    | 0.4.6-1                             |
| hyprsunset                                                    | same                                       | -                            | 0.4.0-1~bpo13+1     | 0.4.0-1+b1                   | 0.4.0-1+b1    | -                                   |
| niri (niri caps)                                              | —                                          | -                            | -                   | -                            | -             | -                                   |
| xwayland-satellite                                            | —                                          | -                            | -                   | -                            | -             | -                                   |
| xdg-desktop-portal-gnome                                      | same                                       | 48.0-2                       | -                   | 50.0-1                       | 50.0-1        | 50.0-0ubuntu1                       |
| gammastep                                                     | same                                       | 2.0.9-1+b2                   | -                   | 2.0.11-1                     | 2.0.11-1      | 2.0.9-2                             |
| libnotify, `notify-send` (audit allowlist)                    | libnotify-bin                              | 0.8.6-1                      | -                   | 0.8.8-1+b1                   | 0.8.8-1+b1    | 0.8.8-1                             |
| wl-clipboard                                                  | same                                       | 2.2.1-2                      | 2.3.0-1~bpo13+1     | 2.3.0-1                      | 2.3.0-1       | 2.2.1-2build1                       |
| networkmanager, `nmcli`                                       | network-manager                            | 1.52.1-1                     | -                   | 1.58.1-1                     | 1.58.1-1      | 1.54.3-2ubuntu3.1                   |
| libpulse, `pactl`                                             | pulseaudio-utils                           | 17.0+dfsg1-2+b1              | -                   | 17.0+dfsg1-3                 | 17.0+dfsg1-3  | 1:17.0+dfsg1-2ubuntu4               |
| playerctl                                                     | same                                       | 2.4.1-3                      | -                   | 2.4.1-4                      | 2.4.1-4       | 2.4.1-3build1                       |
| brightnessctl                                                 | same                                       | 0.5.1-3.1+b1                 | -                   | 0.5.1-3.1+b2                 | 0.5.1-3.1+b2  | 0.5.1-3.1build1                     |

**Manifest `Apps()` list (manifest.go:161-181):**

| Name                               | trixie           | trixie-bpo | forky           | sid             | resolute             |
| ---------------------------------- | ---------------- | ---------- | --------------- | --------------- | -------------------- |
| kitty                              | 0.41.1-2+deb13u2 | -          | 0.48.2-1.1      | 0.48.2-1.1      | 0.45.0-1build1       |
| fish                               | 4.0.2-1          | -          | 4.9.3-1         | 4.9.3-1         | 4.2.1-3.2            |
| starship                           | 1.22.1-5         | -          | 1.26.0-4        | 1.26.0-5        | 1.22.1-9ubuntu1      |
| fastfetch                          | 2.40.4+dfsg-1    | -          | 2.69.0+dfsg-1   | 2.69.0+dfsg-1   | 2.57.1+dfsg-1ubuntu1 |
| neovim                             | 0.10.4-8         | -          | 0.12.4-1        | 0.12.4-1        | 0.11.6-1             |
| nautilus                           | 48.3-2           | -          | 51.0.1-3        | 51.0.1-3        | 1:50.2.2-0ubuntu0.2  |
| nautilus-python → python3-nautilus | 4.0.1-2          | -          | 4.1.0-2         | 4.1.0-2         | 4.1.0-1build1        |
| pavucontrol                        | 6.1-1            | -          | 6.1-1+b1        | 6.1-1+b1        | 6.1-1build1          |
| openrgb                            | -                | -          | 1.0+ds-0.1      | 1.0+ds-0.1      | 0.9+git20251009+ds-1 |
| gamescope                          | -                | -          | -               | -               | 3.16.20+ds-1         |
| gamemode                           | 1.8.2-2          | -          | 1.8.2-2+b2      | 1.8.2-2+b2      | 1.8.2-2build1        |
| mangohud                           | 0.7.2-2          | -          | 0.8.4+dfsg-1+b1 | 0.8.4+dfsg-1+b1 | 0.8.2~rc2-1          |

- **Absent everywhere:** yazi, waifu2x-ncnn-vulkan, songrec.
- **First-party in `release/packages/`:** blesh, ryomotion.
- **Hyprland caps names that are first-party PKGBUILDs here:**
  hypr-dynamic-cursors, hyprglass, imgborders, hyprland-preview-share-picker,
  ryoku-hypr-plugins, ryoku-keysounds.
- **Virtual:** `ryoku-desktop-compositor` is a Provides on the variants. Debian
  would use `Provides:` plus
  `Depends: ryoku-desktop-hyprland | ryoku-desktop-compositor`.

---

## 3. Tests encoding Arch paths or assumptions

| Test file:line                                                                                   | What it encodes                                                                             | Change needed                                                                                                                                         |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| ryoku/cli/internal/keyring/pam_test.go:10-24                                                     | `archSDDM` fixture: `auth/account/password/session include system-login`                    | add a Debian fixture (`@include common-auth`, `-auth optional pam_gnome_keyring.so`, `@include common-session`, `-session … auto_start`)              |
| keyring/pam_test.go:27-52, 54-75                                                                 | asserts the keyring lines sit right after the `system-login` include (36-45)                | assert placement after `@include common-auth/common-session`                                                                                          |
| keyring/pam_test.go:82, 94-95, 119-120, 128-129                                                  | no-anchor case uses `account include system-login`; files seeded from archSDDM              | Debian equivalents                                                                                                                                    |
| keyring/init_test.go:11,26,45,62; set_test.go:79,96,110,124,138,159,179; status_test.go:47,57,81 | every sandbox (`set_test.go:34-46`) is seeded with archSDDM                                 | parametrize over the Debian fixture; add a case where stock `-auth`/`-session` lines must read as "present"                                           |
| keyring/status_test.go:14,28                                                                     | `/etc/sddm.conf(.d)` shape                                                                  | none (same on Debian)                                                                                                                                 |
| ryoku/cli/internal/securitykey/securitykey_test.go:165-167, 213                                  | fake PAM root with files `sudo`, `polkit-1`, `sddm` seeded `auth include system-auth`       | content is cosmetic (the logic prepends), but the `polkit-1` fixture assumes `/etc/pam.d/polkit-1` exists; add a "file only in `/usr/lib/pam.d`" case |
| securitykey_test.go:284-292                                                                      | `#%PAM-1.0\nauth include system-auth` round trip                                            | add a Debian `@include common-auth` fixture                                                                                                           |
| securitykey_test.go:77                                                                           | `fido2-token -L` table format (upstream libfido2)                                           | none                                                                                                                                                  |
| ryoku/cli/internal/keyboard/keyboard_test.go:136-153                                             | Arch boot images `ryoku_linux*.efi`, `initramfs-linux-fallback.img`, glob `initramfs-*.img` | Debian `initrd.img-<kver>` naming                                                                                                                     |
| keyboard_test.go:158-183                                                                         | freshness against `vconsole.conf`                                                           | compare against `/etc/default/keyboard` (vconsole is a symlink on Debian)                                                                             |
| keyboard_test.go:189-~226 (TestReadReportsDriftOnAFrenchBox)                                     | `KEYMAP=fr-latin1` in vconsole.conf plus `00-keyboard.conf` X11                             | Debian `XKBLAYOUT=fr` in `/etc/default/keyboard`                                                                                                      |
| keyboard_test.go:86-118                                                                          | `--resolved` pkexec round trip (comment ties it to mkinitcpio, #177)                        | logic stays; boot-rebuild expectations change                                                                                                         |
| keyboard/xkbrules_test.go:9-14, 74                                                               | `base.lst` fixture                                                                          | none (xkb-data has the same format and path)                                                                                                          |
| ryoku/cli/internal/ryotunesrelease/ryotunesrelease_test.go:80-95                                 | `cmpVer` emulates pacman `vercmp` with epoch                                                | emulate `dpkg --compare-versions`                                                                                                                     |
| ryotunesrelease_test.go:68, 145, 160, 202, 228, 256-258, 278-287                                 | `ryotunes-<v>-<rel>-x86_64.pkg.tar.zst`, `1:` epoch                                         | `.deb` naming, `amd64`                                                                                                                                |
| ryotunesrelease_test.go:129, 324, 348-354, 376                                                   | stubbed pacman `-Qip` metadata, arch `x86_64`                                               | dpkg-deb fields, `amd64`                                                                                                                              |
| ryoku/cli/internal/importer/importer_test.go                                                     | stubs `runHub`                                                                              | none                                                                                                                                                  |
| ryoku/cli/track_test.go:41-56                                                                    | channel aliases (stable/testing/tags)                                                       | none unless the channel model changes                                                                                                                 |
| ryoku/cli/recovery_test.go:11-42; track_test.go:60-80                                            | handoff to `bin/ryoku-recovery` / `bin/ryoku-track`                                         | none (generic), but the scripts they hand off to are Arch                                                                                             |
| ryoku/cli/wm_leafscripts_test.go:73-84                                                           | comments name the `/usr/bin` packaged layout and the `~/ryoku-arch` fallback                | rename if the clone dir changes                                                                                                                       |
| ryoku/cli/plugin_test.go, plugin_new_test.go, plugin_share_test.go, plugin_audit_test.go         | no Arch content (`/etc/passwd` only as a symlink target at plugin_test.go:126)              | none                                                                                                                                                  |
| (outside the brief, used by `wm use`) ryoku/wm/reclaim_test.go:14-17, 251-259                    | pacman `-Rs` plan model and the "removing X breaks dependency" stdout                       | rewrite for apt `-s` output                                                                                                                           |

---

## 4. Issues and risks for Debian

1. **`ryoku keyboard apply` cannot work as written on any candidate base.**
   - Debian/Ubuntu systemd deny `org.freedesktop.locale1.SetX11Keyboard` for
     everyone, including root (policy files cited in §1.7). The call is
     keyboard.go:259.
   - doctor's `reconcile_keymap.go:71` calls the same `ApplySystem`.
   - `mkinitcpio` is absent, so after the system write `apply` returns an error
     (keyboard.go:269-271, cmd.go:249-251).
2. **The keyboard status/detect layers read Arch files.**
   - `ConsoleKeymap()` returns "" on Debian: `/etc/vconsole.conf` resolves to
     `/etc/default/keyboard`, which has no `KEYMAP=` (tmpfiles `debian.conf`).
   - `00-keyboard.conf` is not maintained.
   - The boot-image globs match nothing, so status says "no image found" and
     `BootStale` is false (keyboard.go:195-234).
   - Debian systemd is built with `-Dvconsole=false`.
3. **keyring PAM wiring on Debian's sddm stack.**
   - No `system-login` anchor exists, so `set unlock-on-login` fails with "has
     no auth include system-login anchor" (pam.go:57, 115-117).
   - `pamHasKeyring` only matches lines whose first field is exactly
     `auth`/`session` (pam.go:38). Debian's stock
     `-auth`/`-session optional pam_gnome_keyring.so` lines therefore read as
     **not wired**: status reports `pam lines: no` and init infers never-ask.
   - never-ask/ask strip those stock lines (pam.go:69-79), which triggers a
     pkexec escalation on first `set`.
   - forky/sid sddm has only the `-auth` gnome_keyring line.
   - `libpam-gnome-keyring` also wires a `password` line into `common-password`
     via pam-auth-update, outside `/etc/pam.d/sddm`.
   - `/etc/pam.d/sddm` is a dpkg conffile, so local edits interact with sddm
     upgrades.
   - `ryoku/lockscreen/sddm/setup:108-112` uses the same `system-login` anchor
     (outside this scope).
4. **The security-key polkit target points at a file that does not ship.**
   `/etc/pam.d/polkit-1` is not shipped on Debian/Ubuntu (polkitd ships
   `/usr/lib/pam.d/polkit-1`), nor on Arch. `pamWritable` (O_WRONLY on a missing
   file) fails, so `apply-pam polkit on` errors even as root
   (securitykey/pam.go:25-26, 148-155, 232-234).
5. **Other security-key facts:**
   - The u2f line is prepended as line 1 of the file. On Debian's sddm that is
     above `auth requisite pam_nologin.so` and `pam_succeed_if user != root`
     (securitykey/pam.go:106-109).
   - Debian's `sudo -i` uses `/etc/pam.d/sudo-i`, which is not a target.
   - Ubuntu resolute: `/etc/pam.d/sudo` does not appear in the sudo or sudo-rs
     file lists; where it comes from is unverified.
6. **track and recovery are bound to the Arch tree and pacman.**
   - The URLs fetch `ryoku-dev/ryoku-arch` scripts (recovery.go:13, track.go:16;
     `bin/ryoku-recovery:8`; `bin/ryoku-track:26`).
   - On a Debian box with no checkout, `ryoku recovery` downloads and runs the
     Arch script. That script clones the Arch tree, skips pacman (guarded at
     :128), and runs `deploy.sh`.
   - `ryoku track --source` dies at `sudo pacman -S` (`bin/ryoku-track:36`,
     `set -e`).
   - The packaged `ryoku track` path is unusable on Debian:
     - `PkgInstalled` uses `pacman -Q` (sys.go:48), so it is always false.
     - `RyokuServer` reads `/etc/pacman.conf`, so it is always "".
     - `updater.Track` therefore returns "no ryoku-desktop package and no
       [ryoku] repo" (updater/release.go:131-136).
   - `ResolveRepo`'s fallback requires `~/ryoku-arch` with an origin containing
     "ryoku-arch" (sys/repo.go:44-47).
7. **`wm use` package box is pacman end to end.**
   - apt has no `--assume-installed`.
   - pacman's refusal-line parser and its "Installed Size" units differ from
     dpkg's integer KiB.
   - The rollback comment relies on snap-pac. Debian's `snapper` ships an apt
     hook (`/etc/apt/apt.conf.d/80snapper`).
8. **Compositor availability.**
   - niri and xwayland-satellite are in no Debian or Ubuntu suite, so the niri
     variant has no archive source.
   - hyprland and its satellites are not in trixie main; they are in
     trixie-backports, forky, sid and resolute.
   - hyprsunset is absent in resolute.
   - matugen (installed by recovery and track) is absent everywhere.
9. **ryotunesrelease (doctor's ryotunes reconciler)** hard-codes the pacman
   package format, GitHub asset naming, epoch contract, `x86_64`, `vercmp`,
   `pacman -Qip` and `pacman -U` (§1.11). A Debian port needs a new
   release-asset contract published by ryoku-dev/ryotunes.
10. **ryoku-manifest** parses PKGBUILD `pkgname=` and reads `aur.packages`
    (generate.go:67-68; cmd/ryoku-manifest/main.go:65-84). The `OptIn` and
    `Apps` lists are Arch names. yazi, waifu2x-ncnn-vulkan and songrec are
    absent in all suites; gamescope exists only in resolute; openrgb is not in
    trixie.
11. **gh is absent from forky**, so `plugin share` falls back to the form plus
    xdg-open (plugin_share.go:541-544). That is functional.
12. **`ryoku reload`** only restarts Quickshell components, not the compositor,
    despite its usage text (main.go:13, :102 vs
    `ryoku/shell/ipc/daemon.go:1433-1488`). quickshell is missing from trixie
    main and from resolute.
13. **Paths Debian packaging must reproduce:**
    - `/usr/share/ryoku/i18n` (ryoku-desktop PKGBUILD:546-548; main.go:42)
    - `/usr/share/ryoku/config` (PKGBUILD:252; plugin catalogue, `wm use`)
    - `/usr/share/ryoku/reload-cover` (ryoku-shell PKGBUILD:61-62)
    - `/usr/bin/{ryostore,ryoku-plugins-place,ryoku-hub,ryoku-shell,ryoku-wm-hyprland,ryoku-wm-niri}`
14. **pkexec is a separate Debian package.** keyring, security-key and keyboard
    escalation all exec it (keyring/set.go:248, securitykey/pam.go:208,
    keyboard/cmd.go:201). Arch's `polkit` bundles it.
15. **Commands referenced by name only:** the plugin audit allowlist
    (plugin_audit.go:54-61) and the import engine's `luac` are provided by
    Debian packages with different package names but identical command names
    (§2). No code change is needed there.

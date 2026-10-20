# 11: Compositors, window-manager seam, compositor plugins, app configs, theming assets

Scope: the Hyprland compositor and its hypr* library stack, the Lua config tree
`ryoku/hyprland/` (modules, seeds, helper scripts, shaders, the in-repo
`keysounds` plugin), the five compositor-plugin packages and their ABI coupling,
the screen-share picker, niri (`ryoku/niri/`) and xwayland-satellite, the
window-manager seam `ryoku/wm/` (both providers), every app config dir under
`ryoku/apps/`, fonts, cursors, icon/GTK/Qt themes, `ryoku/assets/`, portals, the
polkit agent and the wayland-session files. Source pinned at `98a0368`
(0.75.5-beta.20). Debian/Ubuntu versions are from `tools/pkgver` and the
Debian/Launchpad madison APIs, Arch versions from archlinux.org, upstream
versions from `git ls-remote`/GitHub, all on 2026-10-17.

| Component                                                                     | Path                                                                                              | As-is on Debian                                                                                                     | Complexity                                    | Blocking issues                                                                                                                                                                  |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hyprland compositor + hypr* stack                                             | `ryoku/hyprland/`, `release/packages/ryoku-desktop-hyprland`                                      | forky/sid: YES (0.56.2, identical to Arch). trixie: NO (trixie-bpo is 0.55.2). resolute: NO (0.53.3, no Lua config) | Low on forky/sid; High on trixie and resolute | Ryoku needs Hyprland >= 0.56.0. 0.56 needs Lua 5.5, libinput >= 1.29, wayland-protocols >= 1.49 and was only ever built by Debian with GCC 16; trixie has none of these.         |
| Hyprland Lua config tree                                                      | `ryoku/hyprland/*.lua`, `modules/`                                                                | YES on Hyprland >= 0.56                                                                                             | Low                                           | Theme names it sets (`adw-gtk3-dark`, `Bibata-Modern-Ice`) need theme debs that Debian lacks or ships incomplete.                                                                |
| Hyprland helper scripts                                                       | `ryoku/hyprland/scripts/`                                                                         | YES                                                                                                                 | Low                                           | `cvt` is in Debian `xcvt`; one `pacman -S` error string.                                                                                                                         |
| Hyprland plugins: hyprbars, hyprfocus, dynamic-cursors, hyprglass, imgborders | `release/packages/{ryoku-hypr-plugins,hypr-dynamic-cursors,hyprglass,imgborders}`                 | NO (Debian ships only hyprbars/hyprfocus, under another path and file name)                                         | Medium                                        | ABI lock to the exact Hyprland build; Debian's `hyprland-abi-<sha>` virtual makes every Hyprland binNMU uninstall them.                                                          |
| keysounds plugin (in-repo)                                                    | `ryoku/hyprland/plugins/keysounds`, `release/packages/ryoku-keysounds`                            | PARTIAL (builds against `hyprland-dev` + `libcanberra-dev`)                                                         | Low                                           | Same ABI lock.                                                                                                                                                                   |
| hyprland-preview-share-picker                                                 | `release/packages/hyprland-preview-share-picker`                                                  | NO (not packaged)                                                                                                   | Low                                           | none (cargo build, rustc >= 1.85)                                                                                                                                                |
| Portals, polkit agent, session files                                          | `ryoku/hyprland/{xdph.conf,hyprland-portals.conf}`, `ryoku/niri/niri-portals.conf`, `ryoku/wm/*/` | PARTIAL                                                                                                             | Low                                           | Debian's `xdg-desktop-portal-gnome` Recommends gnome-shell (niri). Debian ships `hyprland-uwsm.desktop` without uwsm installed.                                                  |
| niri compositor + config                                                      | `ryoku/niri/`, `release/packages/ryoku-desktop-niri`                                              | NO (not in any suite)                                                                                               | Medium                                        | Needs niri >= 26.04; vendored cargo build.                                                                                                                                       |
| xwayland-satellite                                                            | `release/packages/xwayland-satellite`                                                             | NO (not in any suite)                                                                                               | Low                                           | cargo build v0.8.3.                                                                                                                                                              |
| wm seam core (incl. reclaim)                                                  | `ryoku/wm/*.go`                                                                                   | PARTIAL                                                                                                             | Medium                                        | `reclaim.go` drives `pacman -Rs --print` / `pacman -Qi`.                                                                                                                         |
| ryoku-wm-hyprland provider                                                    | `ryoku/wm/hyprland/`                                                                              | PARTIAL                                                                                                             | Medium                                        | `pacman -Q`; QML installed to the Arch Qt path; runtime plugin rebuild needs a C++26 compiler.                                                                                   |
| ryoku-wm-niri provider                                                        | `ryoku/wm/niri/`                                                                                  | YES                                                                                                                 | Low                                           | none in the binary; runtime needs niri >= 26.04.                                                                                                                                 |
| App-config delivery                                                           | `release/packages/ryoku-desktop/PKGBUILD`, `ryoku materialize`                                    | NO                                                                                                                  | Medium                                        | PKGBUILD install lines must become `debian/*.install`/rules; shipped-apps reconciler is pacman-only                                                                              |
| kitty                                                                         | `ryoku/apps/kitty`                                                                                | YES                                                                                                                 | Low                                           | "SpaceMono Nerd Font" is installed by nothing (Arch too)                                                                                                                         |
| fish                                                                          | `ryoku/apps/fish`                                                                                 | PARTIAL                                                                                                             | Low                                           | `fd` is `fdfind` on Debian                                                                                                                                                       |
| bash + ble.sh                                                                 | `ryoku/apps/bash`                                                                                 | PARTIAL                                                                                                             | Low                                           | ble.sh not in trixie; Hub-created `~/.bash_profile` shadows Debian's `~/.profile`; `fd`                                                                                          |
| zsh + plugins + oh-my-zsh                                                     | `ryoku/apps/zsh`                                                                                  | PARTIAL                                                                                                             | Low                                           | Arch plugin paths hardcoded; zsh-history-substring-search and oh-my-zsh not in Debian                                                                                            |
| terminal-shell env                                                            | `ryoku/apps/terminal-shell`                                                                       | PARTIAL                                                                                                             | Low                                           | `fd`                                                                                                                                                                             |
| starship                                                                      | `ryoku/apps/starship`                                                                             | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |
| fastfetch                                                                     | `ryoku/apps/fastfetch`                                                                            | YES                                                                                                                 | Low                                           | readout text says "Arch desktop"                                                                                                                                                 |
| btop                                                                          | `ryoku/apps/btop`                                                                                 | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |
| ghostty                                                                       | `ryoku/apps/ghostty`                                                                              | NO (no Debian package; optional app)                                                                                | Medium                                        | needs zig 0.15.2 build or third-party deb                                                                                                                                        |
| Neovim / LazyVim                                                              | `ryoku/apps/nvim`                                                                                 | NO on trixie, YES forky/sid/resolute                                                                                | Medium                                        | LazyVim needs nvim >= 0.11.2; trixie has 0.10.4                                                                                                                                  |
| yazi                                                                          | `ryoku/apps/yazi`                                                                                 | NO                                                                                                                  | Low                                           | not packaged anywhere; config needs yazi >= 25.12.29                                                                                                                             |
| Nautilus extension                                                            | `ryoku/apps/nautilus`                                                                             | YES                                                                                                                 | Low                                           | Debian name `python3-nautilus`                                                                                                                                                   |
| npm rc                                                                        | `ryoku/apps/npm`                                                                                  | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |
| pip.conf                                                                      | `ryoku/apps/pip`                                                                                  | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |
| WirePlumber BT policy                                                         | `ryoku/apps/wireplumber`                                                                          | PARTIAL (Debian), YES (Ubuntu)                                                                                      | Low                                           | Debian pipewire is built without AAC                                                                                                                                             |
| mimeapps.list                                                                 | `ryoku/apps/mimeapps.list`                                                                        | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |
| chromium-flags.conf                                                           | `ryoku/apps/chromium-flags.conf`                                                                  | NO                                                                                                                  | Low                                           | Debian's chromium wrapper ignores `~/.config/chromium-flags.conf`; Ubuntu has only a snap                                                                                        |
| share-picker config                                                           | `ryoku/apps/hyprland-preview-share-picker`                                                        | YES (once the picker is packaged)                                                                                   | Low                                           | picker itself not in Debian                                                                                                                                                      |
| tools launchers                                                               | `ryoku/apps/tools`                                                                                | PARTIAL                                                                                                             | Low                                           | Install app routes `.pkg.tar.*` to pacman, `.deb` to a payload extract                                                                                                           |
| RyoStore                                                                      | `ryoku/apps/ryostore`                                                                             | PARTIAL                                                                                                             | High                                          | `go 1.26`; bundle catalogue is Arch package names; bundle actuator is pacman/AUR                                                                                                 |
| Ryoport (ryovm)                                                               | `ryoku/apps/ryovm`                                                                                | PARTIAL                                                                                                             | Medium                                        | `setup` verb is pacman/yay/paru; `go 1.26` helpers                                                                                                                               |
| preinstalled.md inventory                                                     | `docs/preinstalled.md`                                                                            | PARTIAL                                                                                                             | High                                          | ~20 packages have no Debian package at all                                                                                                                                       |
| Fonts                                                                         | `release/packages/{otf-space-grotesk,ttf-maple-mono-nf}`, package lists                           | PARTIAL (7 families missing)                                                                                        | Low                                           | Space Grotesk, Maple Mono NF, Fraunces, Material Symbols, three Nerd Fonts are not in Debian. SpaceMono Nerd Font is referenced but shipped by no Ryoku package, on Arch either. |
| Cursors                                                                       | `release/packages/{ryoku-cursors,ryoku-cursor-material}`                                          | PARTIAL                                                                                                             | Low                                           | Debian `bibata-cursor-theme` 2.0.6 has no hyprcursor manifest; vimix/phinger/catppuccin/apple are not in Debian.                                                                 |
| Icons, GTK, Qt theme                                                          | package lists, `autostart.lua`                                                                    | PARTIAL                                                                                                             | Low                                           | `adw-gtk3` is not in Debian.                                                                                                                                                     |
| Brand, wallpapers, decor art                                                  | `ryoku/assets/`                                                                                   | YES                                                                                                                 | Low                                           | none                                                                                                                                                                             |

---

## Part A: Hyprland

### Hyprland compositor and the hypr* stack (`ryoku/hyprland/`, `release/packages/ryoku-desktop-hyprland`)

**What it does:**

- `ryoku-desktop-hyprland` is the Hyprland variant of the desktop. It depends on
  `hyprland`, the five plugin packages pinned `=$pkgver`, `hyprpolkitagent`,
  `xdg-desktop-portal-hyprland`, `hyprland-preview-share-picker` and
  `hyprsunset` (`release/packages/ryoku-desktop-hyprland/PKGBUILD:22-42`), and
  provides the `ryoku-desktop-compositor` virtual (`:43`).
- It copies the whole `ryoku/hyprland/` tree to `/usr/share/ryoku/config/hypr/`
  (`:56-57`), the portal routing to
  `/usr/share/ryoku/config/xdg-desktop-portal/hyprland-portals.conf` (`:60-61`),
  and the share-picker config (`:65-66`). `ryoku materialize` lays these into
  `~/.config` (the update/materialize contract is outside this file).
- It installs every `ryoku/hyprland/scripts/ryoku-*` to `/usr/bin` (`:74-77`),
  builds `ryoku-wm-hyprland` with `go build` (`:81-83`), and copies the
  provider's QML to `/usr/lib/qt6/qml/Ryoku/Wm/Hyprland` (`:87-88`).
- `hypridle` and `hyprpicker` come from the umbrella `ryoku-desktop`
  (`release/packages/ryoku-desktop/PKGBUILD:198-199`), so they are needed on a
  niri-only box too.
- The provider's switch list repeats these names:
  `ryoku/wm/hyprland/caps.go:66-81`.

**Minimum Hyprland version: 0.56.0.** Evidence, in order of strength:

1. Every `settings.lua` the provider writes for an enabled plugin calls
   `hl.get_loaded_plugins()` (`ryoku/wm/hyprland/config_plugins.go:111-118`). It
   was added in Hyprland v0.56.0 (release notes: "config/lua: add
   get_loaded_plugins (#14582)"). On 0.55.x the call errors inside the `pcall`,
   so plugin config is silently skipped.
2. `ryoku/hyprland/CHANGELOG.md:46-51` removed the maximise workaround for
   Hyprland #13322 because "it is fixed upstream in Hyprland 0.56.0". On 0.55
   the maximise keybinds (`modules/binds.lua:12`) regress.
3. `ryoku/wm/hyprland/config_plugins.go:244-245` emits hyprfocus keys "the 0.56
   plugin renamed".
4. The provider's tests use a `v0.56.2` version.h
   (`ryoku/wm/hyprland/config_plugins_test.go:40`). Docs disagree:
   `ryoku/README.md:9-10` says "Hyprland 0.55+".

**When Hyprland gained Lua config:** v0.55.0, released 2026-05-09, by
"config/lua: init lua config manager, use lua if available (#13817)", with
"config: use lua by default, generate lua if no config present" in the same
release. v0.55.x links Lua 5.4. v0.56.0 (2026-07-20) moved to Lua 5.5: upstream
`CMakeLists.txt:291` at v0.56.2 is
`pkg_search_module(LUA REQUIRED ... lua55 lua5.5 lua-55 lua-5.5 lua>=5.5 lua<5.6)`,
and Debian's build-depends changed from `liblua5.4-dev` (0.55.2+ds-1~bpo13+1) to
`liblua5.5-dev` (0.56.2+ds-3).

**Lua APIs the config tree calls** (grep of `ryoku/hyprland/**/*.lua`, call
counts): `hl.animation` 111, `hl.bind` 109, `hl.dsp.exec_cmd` 46, `hl.curve` 38,
`hl.env` 25, `hl.window_rule` 23, `hl.exec_cmd` 23, `hl.dsp.window.resize` 14,
`hl.dsp.focus` 13, `hl.dsp.window.move` 12, `hl.layer_rule` 10, `hl.dsp.global`
9, `hl.config` 8, `hl.on` 7 (events `hyprland.start`, `config.reloaded`,
`monitor.added`, `monitor.removed`), `hl.dsp.submap` 5, `hl.dispatch` 5,
`hl.dsp.workspace.move` 4, `hl.dsp.window.{fullscreen,center}` 2 each,
`hl.define_submap` 2, `hl.monitor`, `hl.dsp.window.{pin,float,drag,close}`,
`hl.dsp.group.toggle` 1 each. The Go providers and scripts add `hl.unbind`,
`hl.device`, `hl.workspace_rule`, `hl.gesture`, `hl.keyword`, `hl.dsp.dpms`,
`hl.dsp.exit`, `hl.dsp.workspace.toggle_special`, `hl.plugin.load`,
`hl.plugin.hyprbars.add_button`, `hl.get_loaded_plugins`. Live changes go
through `hyprctl eval` (`ryoku/hyprland/scripts/ryoku-monitor`,
`ryoku/hyprland/dev-binds.sh:27`, `ryoku/wm/hyprland/session.go:131`), which
only exists on Lua-config Hyprland.

Lua 5.5 detail: `hl.dsp.global(...)` (`modules/binds.lua:58,61,65-70`) is valid
only because Lua 5.5's `luaconf.h` defines `LUA_COMPAT_GLOBAL` by default
("avoids 'global' being a reserved word", lua v5.5.0 `luaconf.h:340-342`). A Lua
5.5 built without that define makes `binds.lua` a syntax error.

**Arch couplings:**

- `release/packages/ryoku-desktop-hyprland/PKGBUILD:25`: `hyprland` unversioned.
  Arch rolling guarantees the newest; a deb needs `hyprland (>= 0.56.0)`.
- `PKGBUILD:87-88`: QML installed to `/usr/lib/qt6/qml/Ryoku/Wm/Hyprland`.
  Debian's Qt6 QML dir is `/usr/lib/x86_64-linux-gnu/qt6/qml`.
- `PKGBUILD:48`: makepkg runs from a full checkout
  (`_repo="$startdir/../../.."`).
- `modules/env.lua:72,79`: `QML_IMPORT_PATH`/`QML2_IMPORT_PATH` are set to
  `$HOME/.local/lib/qt6/qml` for checkout deploys. Not multiarch-sensitive.
- `modules/env.lua:1-4`: `XCURSOR_THEME`/`HYPRCURSOR_THEME` =
  `Bibata-Modern-Ice`; `modules/autostart.lua:7` sets the same live. See
  Cursors.
- `modules/autostart.lua:13`: `gsettings ... gtk-theme adw-gtk3-dark`. See GTK.
- `modules/autostart.lua:70`: `limine-snapper-restore --notify`, guarded by
  `command -v`; on Debian without limine-snapper-sync the line does nothing.
- `modules/autostart.lua:34`:
  `systemctl --user try-restart xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service`.
  The three unit names are identical in Debian (`xdg-desktop-portal-hyprland`
  ships `/usr/lib/systemd/user/xdg-desktop-portal-hyprland.service`).
- `modules/autostart.lua:39`: `systemctl --user stop hyprpolkitagent`. Unit name
  identical in Debian (`/usr/lib/systemd/user/hyprpolkitagent.service`).
- No `pacman`, `/usr/lib/<arch>` or os-release reference in the `.lua` files.

**Dependencies** (Arch = current archlinux.org `extra`; "-" = absent):

| Arch pkg                                                                      | Used for (cite)                                             | Debian/Ubuntu pkg                                                                                                                          | trixie  | trixie-bpo          | forky                               | sid         | resolute                                   | Min version Ryoku needs (why, cite)                                                                                                                         |
| ----------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------------------- | ----------------------------------- | ----------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| hyprland 0.56.2-4                                                             | compositor (`ryoku-desktop-hyprland/PKGBUILD:25`)           | hyprland                                                                                                                                   | -       | 0.55.2+ds-1~bpo13+1 | 0.56.2+ds-3                         | 0.56.2+ds-3 | 0.53.3+ds-4                                | 0.56.0 (`config_plugins.go:114`, CHANGELOG `:46-51`)                                                                                                        |
| (headers inside hyprland)                                                     | plugin builds, ABI receipts                                 | hyprland-dev                                                                                                                               | -       | 0.55.2              | 0.56.2                              | 0.56.2      | 0.53.3                                     | same build as the running hyprland                                                                                                                          |
| aquamarine 0.15.1                                                             | backend                                                     | libaquamarine14, libaquamarine-dev                                                                                                         | -       | 0.15.1-1~bpo13+1    | 0.15.1-1                            | 0.15.1-1    | 0.10.0                                     | >= 0.9.3 (Hyprland `CMakeLists.txt:147`); major.minor is part of the plugin ABI                                                                             |
| hyprutils 0.14.2                                                              |                                                             | libhyprutils13, libhyprutils-dev                                                                                                           | -       | 0.14.2-1~bpo13+1    | 0.14.2-1                            | 0.14.2-1    | 0.11.0                                     | >= 0.14.0 (`CMakeLists.txt:150`)                                                                                                                            |
| hyprlang 0.6.8                                                                |                                                             | libhyprlang2, libhyprlang-dev                                                                                                              | -       | 0.6.8-4~bpo13+1     | 0.6.8-4                             | 0.6.8-4     | 0.6.8-2                                    | >= 0.6.7                                                                                                                                                    |
| hyprcursor 0.1.13                                                             | cursor themes, `ryoku-cursors` build                        | libhyprcursor0, libhyprcursor-dev, hyprcursor-util                                                                                         | -       | 0.1.13-2~bpo13+1    | 0.1.13-2                            | 0.1.13-2    | -                                          | >= 0.1.7                                                                                                                                                    |
| hyprgraphics 0.5.1                                                            |                                                             | libhyprgraphics4, libhyprgraphics-dev                                                                                                      | -       | 0.5.1-2~bpo13+1     | 0.5.1-2                             | 0.5.1-2     | 0.5.0                                      | >= 0.5.1                                                                                                                                                    |
| hyprwayland-scanner 0.4.6                                                     | build                                                       | hyprwayland-scanner                                                                                                                        | -       | 0.4.6-1~bpo13+1     | 0.4.6-1                             | 0.4.6-1     | 0.4.5                                      | >= 0.3.10 (`CMakeLists.txt:293`)                                                                                                                            |
| hyprland-protocols 0.8.0                                                      | build                                                       | hyprland-protocols                                                                                                                         | -       | 0.7.1-2~bpo13+1     | 0.7.1-2                             | 0.7.1-2     | 0.7.0                                      | >= 0.7.0 (`CMakeLists.txt:532`)                                                                                                                             |
| hyprwire 0.3.1                                                                | hyprctl (`hyprctl/CMakeLists.txt:8`)                        | libhyprwire3, libhyprwire-dev, hyprwire-scanner                                                                                            | -       | 0.3.1-3~bpo13+1     | 0.3.1-3                             | 0.3.1-3     | 0.3.0                                      | any                                                                                                                                                         |
| hyprland-guiutils 0.2.2                                                       | Arch `hyprland` hard-depends on it (Hyprland's own dialogs) | hyprland-guiutils                                                                                                                          | -       | 0.2.2-1~bpo13+1     | 0.2.2-1                             | 0.2.2-1     | -                                          | none; Debian `hyprland` does not depend on or recommend it                                                                                                  |
| hyprtoolkit 0.6.0                                                             | guiutils, hyprpolkitagent 0.2                               | libhyprtoolkit-dev                                                                                                                         | -       | 0.5.3-1~bpo13+1     | 0.6.0-3                             | 0.6.0-3     | 0.5.3                                      | -                                                                                                                                                           |
| xdg-desktop-portal-hyprland 1.4.1                                             | ScreenCast/Screenshot (`hyprland-portals.conf:5-6`)         | xdg-desktop-portal-hyprland                                                                                                                | -       | 1.4.1-1~bpo13+1     | 1.4.1-1                             | 1.4.1-1     | 1.3.11                                     | >= 1.3.9 (`custom_picker_binary`, `xdph.conf:8`; added in xdph v1.3.9)                                                                                      |
| hyprpolkitagent 0.2.0                                                         | installed, stopped at login (`autostart.lua:39`)            | hyprpolkitagent                                                                                                                            | -       | 0.1.3-2~bpo13+1     | 0.2.0-1                             | 0.2.0-1     | 0.1.3                                      | none (not run)                                                                                                                                              |
| hyprsunset 0.4.0                                                              | night light (`ryoku/wm/hyprland/act.go:278`)                | hyprsunset                                                                                                                                 | -       | 0.4.0-1~bpo13+1     | 0.4.0-1                             | 0.4.0-1     | -                                          | -                                                                                                                                                           |
| hypridle 0.1.8                                                                | idle timers (`ryoku-desktop/PKGBUILD:198`)                  | hypridle                                                                                                                                   | -       | 0.1.8-1~bpo13+1     | 0.1.8-1                             | 0.1.8-1     | 0.1.7                                      | -                                                                                                                                                           |
| hyprpicker 0.4.7                                                              | Super+Shift+C (`modules/binds.lua:75`)                      | hyprpicker                                                                                                                                 | -       | 0.4.7-1~bpo13+1     | 0.4.7-1                             | 0.4.7-1     | 0.4.6                                      | `-a`                                                                                                                                                        |
| lua 5.5.1                                                                     | config runtime                                              | liblua5.5-0, liblua5.5-dev                                                                                                                 | -       | -                   | 5.5.1-1                             | 5.5.1-1     | 5.5.0-3ubuntu0.1                           | 5.5 with `LUA_COMPAT_GLOBAL` (`binds.lua:58`)                                                                                                               |
| libinput 1.32.0                                                               |                                                             | libinput10, libinput-dev                                                                                                                   | 1.28.1  | -                   | 1.31.3                              | 1.31.3      | 1.31.1                                     | >= 1.29 (`CMakeLists.txt:267`)                                                                                                                              |
| libxkbcommon 1.13.2                                                           |                                                             | libxkbcommon0, libxkbcommon-dev                                                                                                            | 1.7.0   | 1.13.1              | 1.13.1                              | 1.13.1      | 1.13.1                                     | >= 1.11.0 (`:264`)                                                                                                                                          |
| wayland 1.26.0                                                                |                                                             | libwayland-server0, libwayland-dev                                                                                                         | 1.23.1  | -                   | 1.26.0                              | 1.26.0      | 1.24.0                                     | >= 1.22.91 (`:265`)                                                                                                                                         |
| wayland-protocols 1.49                                                        | build                                                       | wayland-protocols                                                                                                                          | 1.44    | 1.47                | 1.49                                | 1.49        | 1.47                                       | >= 1.49 (`:266`)                                                                                                                                            |
| glaze 9.0.0                                                                   | build                                                       | libglaze-dev                                                                                                                               | -       | 8.4.0               | 8.4.0                               | 8.4.0       | 7.0.2                                      | upstream `7...<8` (`:133`), else FetchContent v7.2.0 at configure time (network); Debian patch `Relax-glaze-version-requirement.patch` drops the cap        |
| gcc 16.x                                                                      | build                                                       | g++-16                                                                                                                                     | -       | -                   | 16.2.0-3 (default `g++` 4:16.1.0-3) | 16.2.0-3    | 16-20260322 snapshot (default g++ is 15.2) | C++26 (`CMakeLists.txt:101`); Debian built 0.56.1 and 0.56.2 only with GCC 16.1/16.2 (buildd logs); upstream 0.56.0 notes "nix: gcc15Stdenv -> gcc16Stdenv" |
| cmake                                                                         | build                                                       | cmake                                                                                                                                      | 3.31.6  | 4.3.4               | 4.3.4                               | 4.3.4       | 4.2.3                                      | >= 3.30 (`CMakeLists.txt:1`)                                                                                                                                |
| libeis                                                                        | build                                                       | libeis-dev                                                                                                                                 | 1.3.901 | -                   | 1.5.0                               | 1.5.0       | 1.5.0                                      | any (`:283`)                                                                                                                                                |
| muparser, re2, lcms2, tomlplusplus, udis86, glslang, libdisplay-info, libseat | build                                                       | libmuparser-dev, libre2-dev, liblcms2-dev, libtomlplusplus-dev, libudis86-dev, glslang-dev/glslang-tools, libdisplay-info-dev, libseat-dev | present | udis86 1.7.2        | present                             | present     | present                                    | none beyond presence                                                                                                                                        |

Upstream latest tags equal Arch's versions for every hypr component except
hyprland-protocols (Arch 0.8.0, Debian 0.7.1; Hyprland needs >= 0.7.0).

**As-is on Debian:** forky/sid YES (Debian 0.56.2 = Arch 0.56.2); trixie NO
(0.55.2 in backports); resolute NO (0.53.3, predates Lua config).

**Port steps:**

_forky / sid:_

1. `apt install hyprland hyprland-dev hyprland-guiutils xdg-desktop-portal-hyprland hyprpolkitagent hyprsunset hypridle hyprpicker hyprcursor-util`.
2. Debian's `version.h` carries the real upstream commit and library versions
   (checked in `hyprland-dev_0.56.2+ds-3`:
   `GIT_COMMIT_HASH "efb50993780079460b0cbed1363e2166a2de1d9f"`,
   `GIT_TAG "v0.56.2"`, `AQUAMARINE_VERSION "0.15.0"`,
   `HYPRUTILS_VERSION "0.14.2"`, ...), so the ABI receipts and `commit_pins`
   lookups work unchanged.
3. Debian's headers are multiarch: `/usr/include/x86_64-linux-gnu/hyprland/...`
   with `hyprland.pc` at `/usr/lib/x86_64-linux-gnu/pkgconfig/hyprland.pc`
   (`prefix=/usr/include/x86_64-linux-gnu`). Every Ryoku lookup goes through
   `pkg-config --variable=prefix hyprland` (`release/packages/*/PKGBUILD`
   `_abi()`, `ryoku/wm/hyprland/config_plugins_tier.go:265-270`), so it
   resolves. Only the no-pkg-config fallback
   `/usr/include/hyprland/src/version.h` (`config_plugins_tier.go:272`) is wrong
   on Debian; edit it to try the multiarch path too.
4. `ryoku-desktop-hyprland` deb: `Depends: hyprland (>= 0.56.0), ...`; install
   the QML to `/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku/Wm/Hyprland`.

_trixie (nothing usable in the archive; two recipes, pick one under
"Questions"):_

Recipe T1, rebuild Debian's own forky sources against trixie + trixie-backports.
All hypr libraries Hyprland 0.56.2 needs are already in trixie-backports at the
right versions (aquamarine 0.15.1, hyprutils 0.14.2, hyprlang 0.6.8, hyprcursor
0.1.13, hyprgraphics 0.5.1, hyprwire 0.3.1, hyprwayland-scanner 0.4.6,
hyprland-protocols 0.7.1, libglaze-dev 8.4.0, libxkbcommon 1.13.1,
libudis86-dev). What is missing:

1. In a clean trixie build chroot (mmdebstrap/sbuild, never the host) with
   trixie-backports enabled and `deb-src` for forky:
   `apt-get source wayland-protocols/forky lua5.5/forky libinput/forky hyprland/forky hyprland-plugins/forky`.
2. Build and add to a local repo, in this order:
   1. `wayland-protocols` 1.49-1 (arch all, header/XML only).
   2. `lua5.5` 5.5.1-1 (produces `liblua5.5-0`, `liblua5.5-dev`; new package
      names, no conflict with trixie's lua5.4).
   3. `libinput` 1.31.3-1 (replaces trixie's `libinput10` 1.28.1, same soname
      `libinput.so.10`, so it is drop-in for every other trixie consumer).
   4. A GCC 16 toolchain (see Issues: this is the hard part on trixie).
   5. `hyprland` 0.56.2+ds-3 with `CC=gcc-16 CXX=g++-16`. Debian's packaging
      keeps its patch series (`gcc-port.patch`, `libcpp-port.patch`,
      `Relax-glaze-version-requirement.patch`,
      `Move-hyprland.pc-into-libdir.patch`,
      `Update-hyprland.pc-requires-to-include-lua.patch`,
      `hyprpm-global-headers.patch`,
      `Add-dumpabiver-abi-helper-to-main-CMakeLists.txt.patch`, ...) and
      `debian/rules`
      (`-DBUILD_TESTING=OFF -DBUILD_HYPRTESTER=OFF -DCMAKE_INSTALL_INCLUDEDIR=include/${DEB_HOST_MULTIARCH}`,
      the `debian-abi-helper` Provides). The `+ds` orig tarball already contains
      a `version.h` input with the upstream commit (verified above), so nothing
      extra is needed for the ABI string.
   6. `hyprland-plugins` 0.56.0-1 only if Debian's hyprbars/hyprfocus are used
      (see the plugins section).
3. Take everything else from trixie-backports: `xdg-desktop-portal-hyprland`
   1.4.1, `hypridle` 0.1.8, `hyprpicker` 0.4.7, `hyprsunset` 0.4.0,
   `hyprland-guiutils` 0.2.2, `hyprpolkitagent` 0.1.3 (0.2.0 needs
   `libhyprtoolkit-dev` 0.6.0; bpo has 0.5.3), `hyprcursor-util`.

Recipe T2, a from-git stack. It ignores Debian's hypr packaging and builds
upstream release tags with cmake/meson into hand-made debs in a debootstrapped
buildroot under `work/`:

- Order:
  `wayland wayland-protocols xkbcommon libinput lua hyprwayland-scanner hyprutils hyprlang hyprcursor hyprgraphics hyprland-protocols hyprwire aquamarine hyprland hyprtoolkit hyprland-guiutils hyprlock hypridle`
  (then its own extras swww hyprdim wdisplays uwsm walker elephant, which Ryoku
  does not use), xdph last and best-effort. Ryoku additionally needs hyprsunset,
  hyprpicker and hyprpolkitagent in that table.
- Compiler: `CC=gcc-16 CXX=g++-16` from a pinned sid source; the pin allows
  sid's `libc6`/`libstdc++6`/gcc runtime family at priority 500.
- Lua: built as a static PIC `liblua.a` with a generated `lua.pc` (Version
  5.5.x, satisfies `lua>=5.5`) and a `lua.hpp` shim, so Hyprland carries no
  runtime Lua dependency.
- Debian libs replaced: `DEB_SUPERSEDES` emits versioned `Provides` plus
  arch-qualified `Conflicts`/`Replaces` for libwayland*, libxkbcommon*,
  libinput* (`:122-126`, `:536-547`); unqualified Conflicts once removed
  Hyprland when the NVIDIA i386 closure pulled `libwayland-client0:i386`
  (`:539-546`).
- xdph needs `-DSYSTEMD_SERVICES=ON` or D-Bus activation has no unit
  (`:98-102`).
- Depends come from `dpkg-shlibdeps` inside the buildroot plus a soname
  Provides/Depends scheme between stack debs (`:297-330`, `:416-433`), and two
  link-coherence gates fail the build on unresolved NEEDED (`:769-791`).
- Upstream's `hyprland.pc` and headers land at
  `/usr/share/pkgconfig/hyprland.pc` and `/usr/include/hyprland` (upstream CMake
  defaults), i.e. the same paths as Arch.
- `fetch_source` clones with git (`:272-277`), so CMake records the real
  `GIT_COMMIT_HASH`; a tarball build writes `unknown` (upstream
  `CMakeLists.txt:175-178`) and breaks the ABI machinery (see the provider
  section).

_resolute:_

1. Rebuild Debian forky's sources on resolute (same as T1), because resolute's
   hypr libraries are a generation behind (aquamarine 0.10.0, hyprutils 0.11.0,
   hyprgraphics 0.5.0, hyprwire 0.3.0, hyprland-protocols 0.7.0) and hyprcursor,
   hyprsunset, hyprland-guiutils are absent. Order: `wayland-protocols` 1.49 ->
   `hyprwayland-scanner` -> `hyprutils` -> `hyprlang` -> `hyprcursor` ->
   `hyprgraphics` -> `hyprland-protocols` -> `hyprwire` -> `aquamarine` ->
   `hyprland` (with `g++-16` 16-20260322 from resolute universe) ->
   `hyprland-plugins` (optional) -> `hyprtoolkit` -> `hyprland-guiutils` ->
   `hyprpolkitagent` -> `xdg-desktop-portal-hyprland` -> `hypridle` ->
   `hyprsunset` -> `hyprpicker`. resolute already has lua5.5 5.5.0, libinput
   1.31.1, xkbcommon 1.13.1, wayland 1.24.0, glaze 7.0.2, cmake 4.2.3, libeis
   1.5.0, sdbus-cpp 2.2.1.
2. Debian's runtime package names carry the soname (`libhyprutils13`,
   `libaquamarine14`, ...), so they install beside resolute's older
   `libhyprutils*`; the `-dev` packages replace resolute's.

Build-deps by Debian name (from the Debian source packages' Build-Depends):

- hyprland: cmake cpio debhelper hyprland-protocols hyprwayland-scanner
  hyprwire-scanner libaquamarine-dev libcairo-dev libdrm-dev libxkbcommon-dev
  libegl-dev libegl1-mesa-dev libeis-dev libgbm-dev libglaze-dev libgles-dev
  glslang-dev glslang-tools libhyprlang-dev libhyprcursor-dev libhyprutils-dev
  libhyprwire-dev libhyprgraphics-dev libinput-dev liblcms2-dev liblua5.5-dev
  libmuparser-dev libpango1.0-dev libpixman-1-dev libre2-dev libseat-dev
  libtomlplusplus-dev libudev-dev libudis86-dev libwayland-dev libxcb1-dev
  libxcb-render0-dev libxcb-xfixes0-dev libxcb-icccm4-dev libxcb-composite0-dev
  libxcb-res0-dev libxcb-errors-dev libssl-dev pkgconf wayland-protocols
  libxcursor-dev xwayland xxd.
- aquamarine: hwdata hyprwayland-scanner libdisplay-info-dev libdrm-dev
  libegl-dev libgbm-dev libgles-dev libhyprutils-dev libinput-dev
  libpixman-1-dev libseat-dev libudev-dev libwayland-dev wayland-protocols.
- hyprutils: libpixman-1-dev. hyprlang: libhyprutils-dev. hyprwayland-scanner:
  libpugixml-dev. hyprwire: libffi-dev libhyprutils-dev libpugixml-dev.
- hyprcursor: libcairo2-dev libhyprlang-dev librsvg2-dev libtomlplusplus-dev
  libzip-dev.
- hyprgraphics: libcairo2-dev libdrm-dev libgles-dev libheif-dev
  libhyprutils-dev libjpeg-dev libjxl-dev libmagic-dev libpango1.0-dev
  libpixman-1-dev librsvg2-dev libspng-dev libwebp-dev.
- hyprtoolkit: libabsl-dev libaquamarine-dev libcairo2-dev libdrm-dev libegl-dev
  libgbm-dev libgles-dev libgtest-dev libhyprgraphics-dev libhyprlang-dev
  libhyprutils-dev libiniparser-dev libpango1.0-dev libpixman-1-dev
  libwayland-dev libxkbcommon-dev wayland-protocols.
- hyprland-guiutils: libcairo2-dev libdrm-dev libhyprlang-dev libhyprtoolkit-dev
  libhyprutils-dev libpixman-1-dev libxkbcommon-dev.
- hyprpolkitagent 0.2.0: libdrm-dev libhyprgraphics-dev libhyprlang-dev
  libhyprtoolkit-dev libhyprutils-dev libpixman-1-dev libpolkit-agent-1-dev
  libsdbus-c++-dev libxkbcommon-dev.
- xdg-desktop-portal-hyprland: hyprland-protocols hyprwayland-scanner libdrm-dev
  libgbm-dev libhyprlang-dev libhyprutils-dev libpipewire-0.3-dev
  libsdbus-c++-dev libspa-0.2-dev libwayland-dev qt6-base-dev uuid-dev
  wayland-protocols.
- hypridle: hyprland-protocols hyprwayland-scanner libhyprlang-dev
  libhyprutils-dev libsdbus-c++-dev libwayland-dev wayland-protocols.
- hyprsunset: hyprland-protocols hyprwayland-scanner libhyprlang-dev
  libhyprutils-dev libwayland-dev wayland-protocols.
- hyprpicker: hyprwayland-scanner libcairo2-dev libhyprutils-dev libjpeg-dev
  libpango1.0-dev libwayland-dev libxkbcommon-dev wayland-protocols.

Debian file-path differences that do not affect Ryoku (no Ryoku file names these
paths, grep for `/usr/lib/xdg-desktop-portal`, `/usr/lib/hyprpolkitagent`,
`libexec` is empty): xdph is `/usr/libexec/xdg-desktop-portal-hyprland`,
hyprpolkitagent is `/usr/libexec/hyprpolkitagent`.

**Pre-release soname skew hazard:** Hyprland is only buildable against the
hyprutils/aquamarine minors it was released against, and hyprwm tags those
libraries ahead of the Hyprland release that uses them. On 2026-07-17/18
hyprutils 0.14.0 (`.so.12 -> .so.13`) and aquamarine 0.13.0 (`.so.11 -> .so.12`)
were tagged before any Hyprland release built against them; Hyprland 0.55.4 does
not compile against hyprutils 0.14, and a "latest tag" stack build produced a
golden image whose Hyprland could not load (greetd crash loop). The fix is a
tag-pin map that holds a component at a known-good tag only during such an
upstream pre-release skew window, plus a link-coherence gate. Today (2026-10-17)
there is no skew: Hyprland v0.56.2 needs hyprutils >= 0.14.0 and the newest tags
are hyprutils v0.14.2 and aquamarine v0.15.1. A Debian-source rebuild
(T1/resolute) inherits Debian's choice of library versions and is not exposed to
this, but a from-git build (T2) is.

**Complexity:** Low on forky/sid (archive packages). High on trixie (GCC 16 plus
three library backports, one of which replaces a core system library) and on
resolute (about 15 source packages rebuilt).

**Issues / risks:**

- **No GCC 16 for trixie.** Debian built Hyprland 0.56.1/0.56.2 only with GCC
  16.x (buildd logs: "CXX compiler identification is GNU 16.1.0 / 16.2.0"),
  while the trixie-backports 0.55.2 build used GCC 14.2.0. Hyprland >= 0.56 is
  C++26 and trixie's gcc-14/15 libstdc++ can't compile it. Whether 0.56.2 plus
  Debian's `gcc-port.patch` builds with gcc-14 is not verified. The available
  ways to get GCC 16 on trixie: (a) install sid's `g++-16` with an apt pin,
  which also pulls sid's `libc6` and `libstdc++6` into the build root and,
  through Hyprland's `libstdc++6 (>= 16)` dependency, into every installed
  system; (b) rebuild the forky `gcc-16` source for trixie (a multi-hour
  toolchain build whose `libstdc++6` then replaces trixie's system-wide).
- The same C++26 requirement reaches the user's machine: runtime plugin rebuilds
  (`ryoku doctor`, Hub > Plugins) compile against Hyprland's headers with the
  default `c++` (`config_plugins_tier.go:650`). Default `g++` is 14.2 on trixie,
  16.1 on forky/sid, 15.2 on resolute. hyprbars/hyprfocus/keysounds compile with
  `-std=c++2b`, dynamic-cursors with `-std=c++26`, hyprglass/imgborders with
  C++23; whether Hyprland 0.56's headers parse under g++-14/15 is not verified.
- libinput replacement on trixie: a 1.31 `libinput10` replaces the stable one
  for every consumer (Xorg, other compositors). Same soname, but it is a core
  library swap.
- resolute's `g++-16` is a pre-release snapshot (16-20260322) from universe.
- Debian's `hyprland` package installs
  `/usr/share/wayland-sessions/hyprland-uwsm.desktop` whether or not `uwsm` is
  installed (see Session files).
- Debian's `hyprland` does not pull `hyprland-guiutils` (Arch's does, as a hard
  depend); install it explicitly so Hyprland's own dialogs behave as on Arch.

**Questions for the human:**

- trixie compiler route. Options: (a) sid `g++-16` pinned into the build root:
  fastest, but every installed system then runs sid's `libc6` and `libstdc++6`;
  (b) backport `gcc-16` to trixie: clean dependency graph, a multi-hour
  toolchain build that must be repeated for each GCC point release; (c) try
  gcc-14 with Debian's patch set first and fall back to (a) or (b) only if it
  fails.
- trixie recipe. Options: T1 (Debian sources, Debian package names,
  `hyprland-abi-*` Provides, multiarch headers; least code to own) or T2
  (from-git builder, Arch-identical paths, owns every library including
  wayland/xkbcommon/libinput).

---

### Hyprland config tree (`ryoku/hyprland/*.lua`, `ryoku/hyprland/modules/`, `shaders/`)

**What it does:**

- `hyprland.lua:19-67` is the entry point: hard `require`s for env, displays,
  input, touchpad, misc, decoration, animations, binds, resize, record, ryoshot,
  lid, window_rules, autostart; `optional()` (probe with `package.searchpath`,
  then `pcall(require)`, `hyprland.lua:7-17`) for keyboard, gpu, monitors,
  monitors_user, settings (Hub output), perf_saver, private, ghosttype, user.
- Seeds: `keyboard.lua:11-17` (kb_layout us), `gpu.lua` (empty; `ryoku-gpu`
  rewrites it with `AQ_DRM_DEVICES`), `monitors.lua:4` (`highrr`, auto, scale
  1), `user.lua` (comment-only header), `monitors_user.lua.example`.
- `modules/env.lua`: cursor env (`:1-4`), NVIDIA VA-API env only when NVIDIA
  drives the panel (`:11-41`), `AQ_NO_MODIFIERS=1` otherwise (`:40`),
  Wayland-first toolkit env (`:48-51`), `GSK_RENDERER=gl` (`:58`),
  `QT_QPA_PLATFORMTHEME=qt6ct` (`:64`), `RYOKU_POLKIT_AGENT=1` (`:78`), `PATH`
  with `~/.local/bin` first (`:84`), `EDITOR/VISUAL=nvim` (`:87-88`).
- `modules/autostart.lua:2-117`: one `hl.on("hyprland.start")` that starts
  `gnome-keyring-daemon` (`:6`), sets cursor, dark color-scheme and GTK theme
  (`:7-13`), folder-icon tint (`:17`), env import + `ryoku-power-cutover` +
  portal restart (`:34`), stops hyprpolkitagent (`:39`), and runs the ryoku-*
  login helpers.
- `modules/decoration.lua`: reads `~/.cache/ryoku/hypr-colors.lua` (`:2`),
  `~/.config/ryoku/performance.json` and `shell.json` (`:20-40`), sets screen
  shader from `~/.config/hypr/shaders/<name>.glsl` (`:45`), general/decoration
  (`:48-84`), layer rules (`:94-179`).
- `modules/animations.lua`: preset loader reading `~/.config/ryoku/anim-preset`,
  13 presets under `modules/animations/`.
- `modules/binds.lua`, `rebind.lua`, `resize.lua`, `record.lua`, `ryoshot.lua`,
  `lid.lua`, `touchpad.lua`, `displays.lua`, `input.lua`, `misc.lua`,
  `window_rules.lua`, `perf_saver.lua`.
- `shaders/*.glsl`: five screen shaders named in `decoration.lua:41`.

**Arch couplings:** none in the Lua beyond the theme names and the guarded
`limine-snapper-restore` listed in the stack section. Binaries the config execs
(all exist under the same names on Debian): `hyprctl` (`binds.lua:10`), `kitty`,
`yazi` (`binds.lua:54`), `qs`, `flock`, `pkill`, `hyprpicker` (`:75`), `wpctl`
(`:121`), `playerctl` (`:122-124`), `gsettings`,
`dbus-update-activation-environment`, `systemctl`, `gnome-keyring-daemon`.
Window-rule classes (`window_rules.lua`) are upstream app IDs
(`org.gnome.Nautilus`, `hyprpolkitagent`, `xdg-desktop-portal-gtk`, `steam`,
`[Qq]emu`, ...) and are the same on Debian.

**Dependencies:** Hyprland >= 0.56.0 (stack section); `wireplumber` (`wpctl`),
`playerctl`, `libglib2.0-bin` (`gsettings`), `dbus-bin`, `util-linux` (`flock`),
`procps` (`pkill`), `gnome-keyring`, `kitty`, `yazi`, `quickshell`.

**As-is on Debian:** YES on Hyprland >= 0.56 with the theme packages present.

**Port steps:** none in the Lua. Ship the theme debs named in the Cursors and
GTK sections.

**Complexity:** Low.

**Issues / risks:**

- `env.lua:1-4` names `Bibata-Modern-Ice` for both XCursor and hyprcursor, but
  `ryoku-cursors` builds a hyprcursor manifest only for `Bibata-Modern-Classic`
  (`release/packages/ryoku-cursors/PKGBUILD:47-55`). Same on Arch: Hyprland
  falls back to the XCursor set for Ice.
- `modules/record.lua` comments say the Hub enters the submap with
  `hyprctl dispatch submap record`; under the Lua config manager
  `hyprctl keyword` is refused (`ryoku/wm/hyprland/act.go:20-24`). Behaviour is
  the same on Arch; noted because it is version-sensitive.

---

### Hyprland helper scripts (`ryoku/hyprland/scripts/`)

**What it does:** Installed to `/usr/bin` by
`ryoku-desktop-hyprland/PKGBUILD:74-77` and also present under
`~/.config/hypr/scripts/` (binds call `~/.config/hypr/scripts/ryoku-workspace`,
`modules/binds.lua:87`).

- `ryoku-monitor` (869 lines): DPI autoscale, layouts, hotplug;
  `hyprctl -j monitors`, `hyprctl eval "hl.monitor({...})"`, `jq`, `awk`,
  `systemd-detect-virt`, and `cvt` for modelines (`ryoku-monitor:575`,
  `cvt_bin="${RYOKU_MONITOR_CVT:-cvt}"`).
- `ryoku-workspace`: per-desktop workspace math over `hyprctl`.
- `ryoku-cursor-track`: `hyprctl cursorpos` + `hyprctl -j monitors | jq`
  sampler.
- `ryoku-keysounds-import` (python3): cuts Mechvibes packs with `ffmpeg`.
- `magick-policy/policy.xml`: ImageMagick policy cage activated via
  `MAGICK_CONFIGURE_PATH` by `ryoku/shell/scripts/cliphist-thumbs.sh:6`.

**Arch couplings:**

- `ryoku-keysounds-import:139`: error text
  `ffmpeg not found (pacman -S ffmpeg)`.
- `cvt`: Arch ships it in `libxcvt`; Debian ships `/usr/bin/cvt` in `xcvt`.

**Dependencies:**

| Arch pkg        | Used for (cite)                  | Debian/Ubuntu pkg                                                                  | trixie   | trixie-bpo | forky    | sid      | resolute | Min version                           |
| --------------- | -------------------------------- | ---------------------------------------------------------------------------------- | -------- | ---------- | -------- | -------- | -------- | ------------------------------------- |
| jq              | all three shell helpers          | jq                                                                                 | 1.7.1    | -          | 1.8.2    | 1.8.2    | 1.8.1    | -                                     |
| libxcvt (`cvt`) | modelines (`ryoku-monitor:575`)  | xcvt                                                                               | 0.1.3-1  | -          | 0.1.3-1  | 0.1.3-1  | 0.1.3-1  | -                                     |
| systemd         | `systemd-detect-virt`            | systemd                                                                            | 257.13   | -          | 262      | 262.1    | 259.9    | -                                     |
| ffmpeg          | `ryoku-keysounds-import:47-57`   | ffmpeg                                                                             | 7.1.5    | -          | 9.0.2    | 9.0.2    | 8.0.1    | -                                     |
| python          | importer, cursor recolor         | python3                                                                            | 3.13.5   | -          | 3.14.7   | 3.14.7   | 3.14.3   | 3.11 (`tomllib` in the Bibata recipe) |
| imagemagick     | thumbnails under the policy cage | imagemagick (IM7: `/usr/bin/magick` via update-alternatives from `magick-im7.q16`) | 7.1.1.43 | -          | 7.1.2.31 | 7.1.2.33 | 7.1.2.18 | IM7 (`magick` command)                |

**As-is on Debian:** YES.

**Port steps:** add `xcvt` to the Hyprland variant's Depends; change the string
at `ryoku-keysounds-import:139` to name `apt install ffmpeg`.

**Complexity:** Low.

---

## Part B: Hyprland compositor plugins

### Plugin packages: hyprbars + hyprfocus, dynamic-cursors, hyprglass, imgborders (`release/packages/{ryoku-hypr-plugins,hypr-dynamic-cursors,hyprglass,imgborders}`)

**What it does:**

- Each recipe clones upstream (imgborders from a vendored git bundle,
  `imgborders/PKGBUILD:38-40,55`), reads `pkg-config --modversion hyprland`,
  picks the plugin commit for that Hyprland version from the repo's
  `hyprpm.toml`
  (`grep -F "$hv" hyprpm.toml | grep -oE '[0-9a-f]{40}' | sed -n 2p`), and falls
  back to the default branch HEAD when no pin exists
  (`hypr-dynamic-cursors/PKGBUILD:45-60`, `ryoku-hypr-plugins/PKGBUILD:48-63`,
  `hyprglass/PKGBUILD:42-57`, `imgborders/PKGBUILD:54-70`).
- Build: `make all` (dynamic-cursors, `:62-65`),
  `make -C hyprbars all; make -C hyprfocus all`
  (`ryoku-hypr-plugins/PKGBUILD:65-69`), `make` (hyprglass, `:59-62`),
  `cmake -B build && cmake --build build` (imgborders, `:72-76`).
- Install: `/usr/lib/hyprland/plugins/<id>.so` plus a `<id>.abi` receipt
  (`hypr-dynamic-cursors/PKGBUILD:67-71`, `ryoku-hypr-plugins/PKGBUILD:71-80`,
  `hyprglass/PKGBUILD:64-68`, `imgborders/PKGBUILD:78-82`). The provider reads
  that dir (`ryoku/wm/hyprland/config_plugins.go:16`).
- The receipt is Hyprland's client-hash formula
  `<GIT_COMMIT_HASH>_aq_<maj.min>_hu_<maj.min>_hg_<maj.min>_hc_<maj.min>_hlg_<maj.min>`,
  read from `$(pkg-config --variable=prefix hyprland)/hyprland/src/version.h`
  (`_abi()`, e.g. `hypr-dynamic-cursors/PKGBUILD:36-43`). The live compositor
  reports the same string as `abiHash` in `hyprctl version -j`
  (`ryoku/wm/hyprland/config_plugins_tier.go:236-252`); `settings.lua` loads
  only a copy whose receipt matches (`docs/hyprland-plugins.md:35-39`).
- Three tiers: package `/usr/lib/hyprland/plugins`, user build
  `~/.local/lib/hyprland/plugins` (`config_plugins_tier.go:149-152`), hyprpm
  `~/.local/share/hyprpm` read-only (`:154-162`). `ryoku doctor`'s "Hyprland
  plugin builds" reconciler runs `plugins rebuild --stale`
  (`ryoku/cli/internal/doctor/reconcile_wm_plugins.go:76`).
- The plugins are off by default; the Hub's generated `settings.lua` emits
  `pcall(function() hl.plugin.load(<so>) ... end)` per enabled plugin
  (`config_plugins.go:125-141`).

Upstream build files (current default branches):

- hyprbars:
  `$(CXX) -shared -fPIC -std=c++2b ... pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon`;
  hyprfocus adds `pangocairo`.
- dynamic-cursors: `-std=c++26`, `pkg-config --cflags hyprland pixman-1 libdrm`.
- hyprglass: `-std=c++23`, `pkg-config --cflags hyprland pixman-1 libdrm`,
  `-Wl,-z,noexecstack`.
- imgborders: CMake 3.12, C++23,
  `pkg_check_modules(hyprland libdrm pixman-1 pangocairo)`.

`hyprpm.toml` pins exist for Hyprland 0.56.2 (commit `efb50993...`) in
hyprland-plugins (`7644cecd...`), hypr-dynamic-cursors (`5a224284...`) and
hyprglass (`84c1a5ab...`, v0.10.0). imgborders' upstream `hyprpm.toml` has the
0.56.x pins commented out (`# [... "e8e10c0d..."], # 0.56.2`) with the note
"Broken in 0.55 because Vaxry removed support for rendering tiled textures"; the
PKGBUILD's `grep -F` still matches the commented line and checks out `e8e10c0d`.

**Debian's own plugin packaging** (relevant to the port):

- Debian's `hyprland` binary
  `Provides: hyprland-abi-<sha1-7 of the client hash>, hyprland-api-<ver>` via
  `debian/dumpabiver.cpp` + `debian-abi-helper` (`override_dh_gencontrol` in
  `debian/rules`); sid's 0.56.2+ds-3 provides `hyprland-abi-825c0b8`.
- `hyprland-plugins` 0.56.0-1 builds
  `hyprland-plugin-{hyprbars,hyprfocus, borders-plus-plus,csgo-vulkan-fix}` with
  `Depends: ${hyprland:ABI}`; files are
  `/usr/lib/x86_64-linux-gnu/hyprland/plugins/libhyprbars.so` and
  `libhyprfocus.so`. No `.abi` receipt is installed.
- `README.Debian`: plugins "must match the exact Hyprland version in use ...
  load them with hyprctl plugin load /absolute/path/plugin.so".

**Arch couplings:**

- `config_plugins.go:16`: `pluginDir = "/usr/lib/hyprland/plugins"` (not
  multiarch; Debian's own plugins live elsewhere and are named `lib<id>.so`).
- `config_plugins_tier.go:686-700`: `packageVersion` runs `pacman -Q <pkg>`;
  `:31` documents `Package` as "the pacman package that ships the .so".
- `config_plugins_tier.go:272`: header fallback
  `/usr/include/hyprland/src/version.h`.
- `docs/hyprland-plugins.md:75-78,99-101`: toolchain is "base-devel and git";
  "the Arch hyprland package already ships the headers a plugin build needs".
- PKGBUILD `depends=('hyprland')` unversioned; staleness is detected by the
  receipt, not by the package manager (`docs/hyprland-plugins.md:146-149`).

**Dependencies:**

| Arch pkg                                        | Used for (cite)                                                  | Debian/Ubuntu pkg                                           | trixie                        | trixie-bpo       | forky    | sid      | resolute | Min version                                                         |
| ----------------------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------- | ----------------------------- | ---------------- | -------- | -------- | -------- | ------------------------------------------------------------------- |
| hyprland (headers)                              | all plugins                                                      | hyprland-dev                                                | -                             | 0.55.2           | 0.56.2   | 0.56.2   | 0.53.3   | exact running build                                                 |
| hyprcursor                                      | dynamic-cursors makedepends (`hypr-dynamic-cursors/PKGBUILD:29`) | libhyprcursor-dev                                           | -                             | 0.1.13           | 0.1.13   | 0.1.13   | -        | -                                                                   |
| pixman, libdrm                                  | all (`ryoku-hypr-plugins/PKGBUILD:32`, `hyprglass/PKGBUILD:26`)  | libpixman-1-dev, libdrm-dev                                 | present                       | -                | present  | present  | present  | -                                                                   |
| libinput, wayland, libxkbcommon, systemd (udev) | hyprbars/hyprfocus                                               | libinput-dev, libwayland-dev, libxkbcommon-dev, libudev-dev | (trixie libinput 1.28 < 1.29) | -                | present  | present  | present  | hyprland.pc `Requires: libinput >= 1.29`                            |
| pango, cairo                                    | hyprfocus, imgborders                                            | libpango1.0-dev, libcairo2-dev                              | present                       | -                | present  | present  | present  | -                                                                   |
| cmake                                           | imgborders, toolchain gate (`config_plugins_tier.go:650`)        | cmake                                                       | 3.31.6                        | 4.3.4            | 4.3.4    | 4.3.4    | 4.2.3    | 3.12                                                                |
| gcc, make, pkgconf, git                         | all                                                              | g++ (g++-16, see stack), make, pkgconf, git                 | gcc 14                        | -                | gcc 16   | gcc 16   | gcc 15   | C++26 for dynamic-cursors; Hyprland 0.56 headers (see stack Issues) |
| (Debian alternative)                            | hyprbars, hyprfocus                                              | hyprland-plugin-hyprbars, hyprland-plugin-hyprfocus         | -                             | 0.53.0-3~bpo13+1 | 0.56.0-1 | 0.56.0-1 | -        | built for the archive's hyprland                                    |

**As-is on Debian:** NO. Only hyprbars/hyprfocus exist, under
`/usr/lib/x86_64-linux-gnu/hyprland/plugins/lib<name>.so` without receipts, so
the provider's package tier does not see them.

**Port steps:**

1. Build each plugin as a deb from the same upstream commit selection the
   PKGBUILDs use (debian/rules runs the PKGBUILD's `prepare()` logic, then the
   `build()` command, then installs `<id>.so` + `<id>.abi` to
   `/usr/lib/hyprland/plugins/`). The `_abi()` shell function works unchanged
   because it goes through `pkg-config --variable=prefix hyprland`.
2. Build-Depends:
   `hyprland-dev, libhyprcursor-dev, libpixman-1-dev, libdrm-dev, libinput-dev, libudev-dev, libwayland-dev, libxkbcommon-dev, libpango1.0-dev, libcairo2-dev, cmake, pkgconf, git, g++-16`
   (C++ compiler per the stack decision).
3. Runtime coupling in deb terms. With a Debian-packaged (or T1-rebuilt)
   Hyprland, run `. /usr/lib/x86_64-linux-gnu/hyprland/debian-abi-helper` in
   `override_dh_gencontrol` and emit `Depends: ${hyprland:ABI}` exactly like
   Debian's `hyprland-plugins`. With a T2 (from-git) Hyprland, emit
   `Depends: hyprland (= <exact version>)` and rebuild every plugin deb in the
   same pipeline run as hyprland.
4. Either keep these packages out of `ryoku-desktop-hyprland`'s hard Depends
   (make them Recommends), or accept that every Hyprland ABI change blocks the
   upgrade (see Issues).
5. Port `packageVersion` (`config_plugins_tier.go:691`) to
   `dpkg-query -W -f='${db:Status-Abbrev} ${Version}' <pkg>`.
6. To use Debian's hyprbars/hyprfocus instead of building them: add
   `/usr/lib/x86_64-linux-gnu/hyprland/plugins` with the `lib` prefix to the
   package tier in `config_plugins.go`/`config_plugins_tier.go`, and treat a
   receipt-less copy as matching (the tier code already takes a copy with no
   receipt "on trust", `docs/hyprland-plugins.md:35-37`).
7. Update `docs/hyprland-plugins.md:75-78,99-101` for the Debian toolchain
   wording.

**Complexity:** Medium.

**Issues / risks:**

- **Hard-depend chain vs Debian ABI churn.** `ryoku-desktop-hyprland`
  hard-depends on all five plugin packages `=$pkgver` (`PKGBUILD:29-33`). On
  forky/sid every Hyprland upload or binNMU against a new
  aquamarine/hyprutils/hyprgraphics/hyprcursor/hyprlang minor changes the
  `hyprland-abi-*` virtual. A plugin deb that depends on the old one makes apt
  either hold Hyprland back (`apt upgrade`) or remove the plugins and with them
  `ryoku-desktop-hyprland` (`apt full-upgrade`), until the `[ryoku]` repo
  publishes rebuilt plugins. On Arch the same bump only stales a receipt.
- The docs name a non-existent file: `docs/hyprland-plugins.md:162-164` says the
  builder lives in `ryoku/hub/backend/hyprplugins.go` / `hyprplugins_build.go`;
  the code is `ryoku/wm/hyprland/config_plugins_build.go` and
  `config_plugins_tier.go`.
- imgborders renders limited on 0.55+ per upstream ("tiled-texture support was
  removed", `imgborders/PKGBUILD:18-21`); same on Debian.
- Runtime rebuilds clone github.com and codeberg.org on the user's machine
  (`config_plugins_tier.go:41-67`); unchanged from Arch.

**Questions for the human:**

- Plugin source. Options: (a) build all five as `[ryoku]` debs into
  `/usr/lib/hyprland/plugins` (no Go change, Ryoku owns the rebuild cadence);
  (b) use Debian's hyprbars/hyprfocus debs on forky/sid and build only the other
  three (a Go change to the package tier, fewer packages, but those two follow
  Debian's schedule and have no `.abi`).
- Dependency strength. Options: (a) keep the hard `=$pkgver` Depends (matches
  Arch; an ABI change blocks upgrades on Debian until `[ryoku]` republishes);
  (b) Recommends (upgrades never block; a stale plugin shows "Needs rebuild" in
  the Hub and the doctor rebuilds it locally, as on Arch).

---

### keysounds plugin (`ryoku/hyprland/plugins/keysounds`, `release/packages/ryoku-keysounds`)

**What it does:** Ryoku's own plugin: a libcanberra sound per key press
(`main.cpp:20-27,223-239`). `Makefile:28-29` builds
`$(CXX) -shared -fPIC -std=c++2b ... pkg-config --cflags --libs hyprland pixman-1 libdrm libcanberra`,
adds `--no-gnu-unique` for g++ (`:12-16`). `make sounds` clones Mechvibes at
commit `326252a1...` (`Makefile:21-34`) and cuts each `profiles.txt` line with
`ryoku-keysounds-import` (`:36-41`). `hyprpm.toml` is the recipe the runtime
builder runs (`build = ["make all"]`, `assets = "sounds"`). The package installs
`/usr/lib/hyprland/plugins/keysounds.so` + `.abi`, the profiles to
`/usr/share/ryoku/keysounds/`, and the source to
`/usr/share/ryoku/hypr-plugins/keysounds`
(`release/packages/ryoku-keysounds/PKGBUILD:59-69`).

**Arch couplings:** `PKGBUILD:35-36` builds from the checkout (`_repo`); the
importer's `pacman -S ffmpeg` string (helper scripts section).

**Dependencies:**

| Arch pkg            | Used for (cite)                   | Debian/Ubuntu pkg                         | trixie  | trixie-bpo | forky   | sid     | resolute | Min version   |
| ------------------- | --------------------------------- | ----------------------------------------- | ------- | ---------- | ------- | ------- | -------- | ------------- |
| libcanberra         | runtime (`PKGBUILD:30`)           | libcanberra0 (+ libcanberra-dev to build) | 0.30-18 | -          | 0.30-20 | 0.30-20 | 0.30-18  | -             |
| hyprland            | headers                           | hyprland-dev                              | -       | 0.55.2     | 0.56.2  | 0.56.2  | 0.53.3   | running build |
| python, ffmpeg, git | sample cutting (`PKGBUILD:31-32`) | python3, ffmpeg, git                      | present | -          | present | present | present  | -             |
| pixman, libdrm      | headers                           | libpixman-1-dev, libdrm-dev               | present | -          | present | present | present  | -             |

**As-is on Debian:** PARTIAL: builds unchanged where `hyprland-dev` matches the
running Hyprland.

**Port steps:** debian/rules:
`make -C ryoku/hyprland/plugins/keysounds all MECHVIBES=<pre-fetched checkout> IMPORTER=ryoku/hyprland/scripts/ryoku-keysounds-import`
(pre-fetch Mechvibes at `326252a1...` into the source package so the build is
offline); install as `PKGBUILD:59-69`; `Depends: libcanberra0, ${hyprland:ABI}`
(or the exact version, per the plugin section).

**Complexity:** Low.

---

### hyprland-preview-share-picker (`release/packages/hyprland-preview-share-picker`)

**What it does:** The screen-share source chooser xdph launches
(`ryoku/hyprland/xdph.conf:8`,
`custom_picker_binary = hyprland-preview-share-picker`). `[ryoku]` builds commit
`e2f30ff8...` (`PKGBUILD:3-5`, version `0.2.1.r9`) from
github.com/WhySoBad/hyprland-preview-share-picker with the
`lib/hyprland-protocols` submodule pointed at a separate clone (`:13-22`),
`cargo fetch --locked` (`:24`), `cargo build --frozen --release` (`:31`), and
emits `schema.json` (`:32`). Installs `/usr/bin/hyprland-preview-share-picker`
and `/usr/share/hyprland-preview-share-picker/schema.json` (`:37-38`). The
config is `ryoku/apps/hyprland-preview-share-picker/config.yaml`, copied by
`ryoku-desktop-hyprland/PKGBUILD:65-66`.

**Arch couplings:** `RUSTUP_TOOLCHAIN=stable` (`:23,29`), harmless on Debian.
`options=('!lto')` (`:12`).

**Dependencies:**

| Arch pkg                              | Used for (cite)     | Debian/Ubuntu pkg                              | trixie        | trixie-bpo | forky            | sid    | resolute | Min version (why)                             |
| ------------------------------------- | ------------------- | ---------------------------------------------- | ------------- | ---------- | ---------------- | ------ | -------- | --------------------------------------------- |
| cargo                                 | build (`:11`)       | cargo, rustc                                   | 1.85.1        | 1.96.1     | 1.96.1           | 1.97.1 | 1.93.1   | 1.85 (Cargo.toml `edition = "2024"`)          |
| gtk4                                  | UI                  | libgtk-4-dev / libgtk-4-1                      | 4.18.6        | -          | 4.24.1           | 4.24.1 | 4.22.4   | 4.8 (`gtk4` crate feature `v4_8`)             |
| gtk4-layer-shell                      | overlay             | libgtk4-layer-shell-dev / libgtk4-layer-shell0 | 1.0.4         | -          | 1.3.0            | 1.3.0  | 1.3.0    | crate `gtk4-layer-shell 0.4.0` / `-sys 0.3.0` |
| wayland                               |                     | libwayland-dev                                 | 1.23.1        | -          | 1.26.0           | 1.26.0 | 1.24.0   | -                                             |
| slurp                                 | region pick (`:10`) | slurp                                          | 1.5.0         | -          | 1.6.0really1.5.0 | same   | present  | -                                             |
| xdg-desktop-portal-hyprland, hyprland | runtime (`:10`)     | same                                           | stack section |            |                  |        |          |                                               |

**As-is on Debian:** NO (not packaged).

**Port steps:**

1. `git clone https://github.com/WhySoBad/hyprland-preview-share-picker && git checkout e2f30ff85486e557018523da45ccbc846e3a499c && git submodule update --init`.
2. `cargo vendor --locked vendor > .cargo/config.toml` once (network), then
   `cargo build --frozen --offline --release`.
3. `./target/release/hyprland-preview-share-picker schema > schema.json`.
4. Install as `PKGBUILD:37-39`. Build-Depends:
   `cargo, rustc (>= 1.85), libgtk-4-dev, libgtk4-layer-shell-dev, libwayland-dev, pkgconf, git`.
   Depends: `${shlibs:Depends}, slurp, xdg-desktop-portal-hyprland`.

**Complexity:** Low.

**Issues / risks:** upstream has since tagged v0.3.0; Ryoku pins the older
commit. The crate uses `hyprland` (hyprland-rs) `0.4.0-beta.1` for IPC;
behaviour is identical as long as Hyprland is the same version as Arch's.

---

### Portals, polkit agent, session files

**What it does:**

- Hyprland portal routing (`ryoku/hyprland/hyprland-portals.conf:3-7`):
  `default=hyprland;gtk`, ScreenCast and Screenshot to hyprland, FileChooser to
  gtk. Shipped to
  `/usr/share/ryoku/config/xdg-desktop-portal/hyprland-portals.conf`
  (`ryoku-desktop-hyprland/PKGBUILD:60-61`) and materialized into the user's
  `~/.config/xdg-desktop-portal/`, which shadows the copy Debian's `hyprland`
  installs at `/usr/share/xdg-desktop-portal/hyprland-portals.conf`.
- xdph config `ryoku/hyprland/xdph.conf:6-9`: `allow_token_by_default = true`,
  `custom_picker_binary = hyprland-preview-share-picker`. Debian's xdph also
  ships its own `/usr/bin/hyprland-share-picker`, which this setting bypasses.
- Login portal restart: `modules/autostart.lua:34`; `ryoku doctor` checks
  `xdg-desktop-portal-<backend>.service`
  (`ryoku/cli/internal/doctor/reconcile_portal_session.go:137-175`,
  `ryoku/cli/internal/doctor/report.go:53-54`).
- niri portal routing and needs: see the niri section
  (`xdg-desktop-portal-gnome` + `-gtk`).
- Polkit: the shell daemon registers as the PolicyKit agent when
  `RYOKU_POLKIT_AGENT=1` (`modules/env.lua:74-78`); `hyprpolkitagent` is
  installed (`ryoku-desktop-hyprland/PKGBUILD:34`) but stopped at every login
  (`autostart.lua:39`). `polkit` + `gnome-keyring` come from base
  (`system/packages/base.packages:128-129`).
- Session files: Hyprland's `.desktop` comes from the `hyprland` package; the
  provider prints a fallback entry (`ryoku/wm/hyprland/apply.go:197-201`,
  `Exec=Hyprland`) that `ryoku/lockscreen/sddm/setup:134-157` writes to
  `/usr/share/wayland-sessions/<id>.desktop` only when none exists. niri's
  provider prints `Exec=niri-session` (`ryoku/wm/niri/wayland_session.go:8-13`).
- uwsm: not used. qylock filters any `uwsm` session out of its session list
  (`ryoku/lockscreen/qylock/themes/clockwork/orbital/Main.qml:565-566`).

**Arch couplings:** none in these files.

**Dependencies:**

| Arch pkg                          | Used for (cite)                         | Debian/Ubuntu pkg      | trixie | trixie-bpo | forky  | sid    | resolute | Min version                |
| --------------------------------- | --------------------------------------- | ---------------------- | ------ | ---------- | ------ | ------ | -------- | -------------------------- |
| xdg-desktop-portal 1.22.1         | frontend                                | xdg-desktop-portal     | 1.20.3 | -          | 1.22.1 | 1.22.1 | 1.21.1   | >= 1.17 (`*-portals.conf`) |
| xdg-desktop-portal-gtk 1.15.3     | FileChooser (`hyprland-portals.conf:7`) | xdg-desktop-portal-gtk | 1.15.3 | -          | 1.15.3 | 1.15.3 | 1.15.3   | -                          |
| xdg-desktop-portal-hyprland 1.4.1 | ScreenCast/Screenshot                   | same                   | -      | 1.4.1      | 1.4.1  | 1.4.1  | 1.3.11   | 1.3.9                      |
| xdg-desktop-portal-gnome 51.0     | niri ScreenCast                         | same                   | 48.0   | -          | 50.0   | 50.0   | 50.0     | see niri                   |
| polkit                            | auth                                    | polkitd                | 126    | -          | 127    | 128    | 127      | -                          |
| gnome-keyring                     | secrets                                 | gnome-keyring          | 48.0   | -          | 51.1   | 51.1   | 50.0     | -                          |
| hyprpolkitagent                   | fallback agent (stopped)                | hyprpolkitagent        | -      | 0.1.3      | 0.2.0  | 0.2.0  | 0.1.3    | -                          |
| uwsm 0.27.1                       | not used by Ryoku                       | uwsm                   | -      | 0.26.7     | 0.27.0 | 0.27.0 | 0.25.2   | -                          |

**As-is on Debian:** PARTIAL.

**Port steps:**

1. Hyprland variant Depends:
   `xdg-desktop-portal, xdg-desktop-portal-gtk, xdg-desktop-portal-hyprland (>= 1.3.9), hyprland-preview-share-picker`.
2. Session entry: Debian's `hyprland` installs
   `/usr/share/wayland-sessions/hyprland.desktop` with
   `Exec=/usr/bin/start-hyprland` (upstream `example/hyprland.desktop.in` at
   v0.56.2) and `hyprland-uwsm.desktop` (upstream installs it unless `NO_UWSM`,
   `CMakeLists.txt:409-419`; Debian's rules do not set it). Either divert it
   away in the Ryoku variant's preinst
   (`dpkg-divert --package ryoku-desktop-hyprland --rename --divert /usr/share/wayland-sessions/hyprland-uwsm.desktop.ryoku-disabled /usr/share/wayland-sessions/hyprland-uwsm.desktop`),
   or build Hyprland with `-DNO_UWSM=ON` (T1/T2), or install `uwsm`, so SDDM
   does not offer a session whose `uwsm` binary is absent.
3. The provider's fallback `Exec=Hyprland` (`apply.go:200`) bypasses Hyprland's
   `start-hyprland` launcher; it is only written when the package ships no
   entry, which Debian's always does.

**Complexity:** Low.

**Issues / risks:**

- trixie's `xdg-desktop-portal` 1.20.3 and `xdg-desktop-portal-gnome` 48 are
  older than Arch's 1.22.1/51.0; Ryoku pins no minimum.

---

## Part C: niri, xwayland-satellite and the window-manager seam

### niri compositor and config tree (`ryoku/niri/`, `release/packages/ryoku-desktop-niri`)

**What it does:**

- `ryoku/niri/config.kdl:18-38` is the only file niri reads. It does nothing
  except `include` the other files, in override order: autostart, lid, keyboard,
  gpu, monitors, monitors_user, then the generated settings.kdl and rebinds.kdl,
  then user.kdl.
- `autostart.kdl:13-79` is the session bootstrap, written as `spawn-at-startup`
  and `spawn-sh-at-startup` lines.
- `lid.kdl:4-11` routes the native `switch-events` lid-close and lid-open to
  `ryoku-clamshell`.
- The variant package installs the tree to `/usr/share/ryoku/config/niri`
  (`PKGBUILD:56-57`) and the portal routing to
  `/usr/share/ryoku/config/xdg-desktop-portal/niri-portals.conf`
  (`PKGBUILD:63-64`).
- It builds and installs `/usr/bin/ryoku-wm-niri` (`PKGBUILD:71-73`).
- It installs the `niri.service.d/ryoku-bootstrap.conf` drop-in, which orders
  `ryoku-bootstrap.service` before niri.service (`PKGBUILD:76-77`;
  `ryoku/shell/systemd/user/niri.service.d/ryoku-bootstrap.conf:7-8`).
- Depends: `ryoku-desktop=$pkgver`, `niri`, `xwayland-satellite`,
  `xdg-desktop-portal-gnome`, `gammastep` (`PKGBUILD:23-38`). Provides the
  `ryoku-desktop-compositor` virtual (`PKGBUILD:39`). It is deliberately not
  exclusive with the Hyprland variant (`PKGBUILD:40-41`).

**Minimum niri version: 26.04** (upstream `niri-wm/niri`, tag `v26.04`, released
2026-04-25; the current latest release). Each config or IPC feature Ryoku uses,
with the niri release that added it:

| Feature Ryoku uses                                                              | Cite                                                                                                          | niri release that added it                                                                                |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `include "file.kdl"`                                                            | `ryoku/niri/config.kdl:18-38`                                                                                 | 25.11 ("Config includes"). 26.04 added _optional_ includes, which Ryoku does not use (`config.kdl:6-10`). |
| `spawn-sh-at-startup`                                                           | `ryoku/niri/autostart.kdl:22-79`; also written by `ryoku/wm/niri/config_misc.go` (`"spawn-sh-at-startup %s"`) | 25.08                                                                                                     |
| `recent-windows { off }`                                                        | `ryoku/wm/niri/config_misc.go:35`                                                                             | 25.11                                                                                                     |
| window-rule `background-effect { blur true/false }` and `{ xray true }`         | `ryoku/wm/niri/config_rules.go:50-52,164-169,231-233`                                                         | **26.04** (blur in mainline)                                                                              |
| `hotkey-overlay { hide-not-bound }`                                             | `config_misc.go:24-25`                                                                                        | 25.08                                                                                                     |
| layer-rule `place-within-backdrop`, `baba-is-float`, `tab-indicator`, `mod-key` | config_rules / config_layout writers                                                                          | 25.05                                                                                                     |
| IPC event `ConfigLoaded`                                                        | `ryoku/wm/niri/watch.go:177`                                                                                  | 25.08                                                                                                     |
| IPC `layout` / `window_size` on windows, event `WindowLayoutsChanged`           | `watch.go:50-51,273`                                                                                          | 25.08                                                                                                     |
| IPC window `focus_timestamp`                                                    | `watch.go:48`                                                                                                 | 25.11                                                                                                     |
| IPC event `OverviewOpenedOrClosed`, action `ToggleOverview`                     | `watch.go:322`, `act.go:191`                                                                                  | 25.05                                                                                                     |

The code names 26.04 itself in `ryoku/wm/niri/window_layout.go:5`,
`ryoku/wm/niri/apply.go:160` and `ryoku/wm/niri/config_store.go:26` ("niri
26.04's window blur renders translucent windows opaque"). The PKGBUILD does not
version-bound `niri` (`PKGBUILD:26`).

The niri IPC requests the provider uses are `Version`, `Windows`, `Workspaces`,
`Outputs`, `KeyboardLayouts`, `EventStream` and `Output`
(`ryoku/wm/niri/caps.go:115`, `act.go:679,691,708`, `outputs.go:399,576`,
`watch.go:136`). The actions it sends are FocusWindow, CloseWindow,
FullscreenWindow, ToggleWindowFloating, MoveWindowToWorkspace, FocusWorkspace,
MoveWorkspaceToMonitor, Quit, PowerOn/OffMonitors, SwitchLayout and
ToggleOverview (`act.go:75-191,553`). It reads the socket path from
`$NIRI_SOCKET` (`session.go:29-35`).

**Arch couplings:**

- `autostart.kdl:19`: `gsettings set ... gtk-theme adw-gtk3-dark`. `adw-gtk3` is
  absent from every Debian and Ubuntu suite (pkgver: `-` everywhere). This is
  theming scope; noted here because the niri tree hardcodes it.
- `autostart.kdl:61`: `limine-snapper-restore --notify`. This is an Arch-side
  limine-snapper-sync tool, guarded by `command -v`, so on Debian the line
  silently does nothing.
- `autostart.kdl:75,79`, `ryoku/wm/niri/config_binds.go:49`: the QML path is
  `$HOME/.local/lib/qt6/qml`. That is a user path, not the system multiarch
  path, so it is not affected by the Debian QML directory (FYI).
- `PKGBUILD:12-13,44`: makepkg runs from a checkout
  (`_repo="$startdir/../../.."`). The Debian equivalent is a debian/ dir at the
  repo root, or a per-package source tree.
- No `pacman` calls, `/usr/lib` paths or os-release checks inside `ryoku/niri/`.

**Dependencies:**

| Arch pkg                 | Used for (cite)                                                              | Debian/Ubuntu pkg             | trixie           | trixie-bpo       | forky       | sid         | resolute                                                                                   | Min version Ryoku needs (why, cite)                                                                          |
| ------------------------ | ---------------------------------------------------------------------------- | ----------------------------- | ---------------- | ---------------- | ----------- | ----------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| niri (extra 26.04-1)     | compositor (`PKGBUILD:26`)                                                   | none, build it (see below)    | -                | -                | -           | -           | - (third-party PPA ppa:avengemedia/danklinux only, per niri docs Getting-Started.md:18-22) | 26.04 (background-effect, table above)                                                                       |
| xwayland-satellite       | X11 bridge niri spawns (`PKGBUILD:31`; `autostart.kdl:6-9`)                  | none, build it (next section) | -                | -                | -           | -           | -                                                                                          | >= 0.8.3, or upstream commit add2795 (`xwayland-satellite/PKGBUILD:18-20`)                                   |
| xdg-desktop-portal-gnome | ScreenCast/Screenshot backend (`PKGBUILD:32-34`; `ryoku/wm/niri/caps.go:99`) | xdg-desktop-portal-gnome      | 48.0-2           | -                | 50.0-1      | 50.0-1      | 50.0-0ubuntu1                                                                              | none pinned by Ryoku. Arch ships 51.0.                                                                       |
| xdg-desktop-portal-gtk   | FileChooser routed to gtk (`ryoku/niri/niri-portals.conf:8-9`)               | xdg-desktop-portal-gtk        | 1.15.3-1         | -                | 1.15.3-2+b1 | 1.15.3-2+b1 | 1.15.3-2ubuntu1                                                                            | portals.conf support needs xdg-desktop-portal >= 1.17 (met everywhere)                                       |
| xdg-desktop-portal       | frontend, try-restarted at login (`autostart.kdl:30`)                        | xdg-desktop-portal            | 1.20.3+ds-1      | -                | 1.22.1+ds-1 | 1.22.1+ds-1 | 1.21.1+ds-1ubuntu3.1                                                                       | >= 1.17 (portals.conf)                                                                                       |
| gammastep                | night light, `gammastep -m wayland -O <K>` (`ryoku/wm/niri/act.go:194`)      | gammastep                     | 2.0.9-1+b2       | -                | 2.0.11-1    | 2.0.11-1    | 2.0.9-2                                                                                    | needs the wayland method; Debian builds with libwayland-dev (debian/control Build-Depends), so it is present |
| gnome-keyring            | `gnome-keyring-daemon --start` (`autostart.kdl:13`)                          | gnome-keyring                 | 48.0-1           | -                | 51.1-3      | 51.1-3      | 50.0-1                                                                                     | -                                                                                                            |
| glib2 (gsettings)        | `autostart.kdl:15,19`                                                        | libglib2.0-bin                | 2.84.4-3~deb13u5 | -                | 2.90.1-2    | 2.90.1-2    | 2.88.0-1ubuntu0.1                                                                          | -                                                                                                            |
| dbus                     | `dbus-update-activation-environment` (`autostart.kdl:30`)                    | dbus-bin                      | 1.16.2-2         | -                | 1.16.2-8    | 1.16.2-8    | 1.16.2-2ubuntu4                                                                            | -                                                                                                            |
| util-linux               | `flock` (`autostart.kdl:75,79`)                                              | util-linux                    | 2.41.5           | -                | 2.42.4-1    | 2.42.4-1    | 2.41.3                                                                                     | -                                                                                                            |
| procps, bash             | upstream `niri-session` uses `ps` and bash                                   | procps                        | 2:4.0.4-9        | -                | 2:4.0.7-1   | 2:4.0.7-1   | 2:4.0.4-9ubuntu1                                                                           | -                                                                                                            |
| libwayland-server        | dlopened by niri, so shlibdeps misses it (niri Packaging-niri.md)            | libwayland-server0            | 1.23.1-3         | -                | 1.26.0-1    | 1.26.0-1    | 1.24.0-2                                                                                   | -                                                                                                            |
| go (makedepends)         | builds ryoku-wm-niri (`PKGBUILD:22,71`)                                      | golang-go                     | 2:1.24~2         | 2:1.27~1~bpo13+1 | 2:1.27~1    | 2:1.27~1    | 2:1.26~1                                                                                   | 1.22 (`ryoku/wm/go.mod:3`)                                                                                   |

niri build deps (Debian names, from niri `docs/wiki/Getting-Started.md`
"Building", Arch `depends`, and the v26.04 Cargo.lock):

| Build dep                                      | trixie                   | trixie-bpo | forky                    | sid         | resolute                 | Need (why)                                                                                                                                                                                                                                                      |
| ---------------------------------------------- | ------------------------ | ---------- | ------------------------ | ----------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| rustc / cargo                                  | 1.85.1                   | 1.96.1     | 1.96.1                   | 1.97.1      | 1.93.1                   | MSRV 1.85 (niri Cargo.toml `rust-version = "1.85"`; smithay rev ff5fa7d is also 1.85). The max `rust-version` among Linux-built lockfile crates is 1.85 (checked against the crates.io index; the 1.87 crates are wasm-only). trixie's 1.85.1 meets it exactly. |
| clang, libclang-dev                            | 1:19.0-63                | -          | 1:21.1.8-74              | 1:21.1.8-74 | 1:21.1.6-71              | bindgen                                                                                                                                                                                                                                                         |
| gcc, pkgconf                                   | 1.8.1-4                  | -          | 2.5.1-4                  | 2.5.1-4     | 2.5.1-4                  | -                                                                                                                                                                                                                                                               |
| libudev-dev                                    | 257.13                   | -          | 262-1                    | 262.1-1     | 259.9                    | -                                                                                                                                                                                                                                                               |
| libgbm-dev                                     | 25.0.7                   | 26.1.6     | 26.1.6                   | 26.2.5      | 26.0.8                   | -                                                                                                                                                                                                                                                               |
| libxkbcommon-dev                               | 1.7.0-2                  | 1.13.1     | 1.13.1                   | 1.13.1      | 1.13.1                   | xkbcommon crate 0.9                                                                                                                                                                                                                                             |
| libegl-dev (libegl1-mesa-dev is transitional)  | 1.7.0-1+b2               | -          | 1.7.0-3+b1               | 1.7.0-3+b1  | 1.7.0-3                  | -                                                                                                                                                                                                                                                               |
| libwayland-dev                                 | 1.23.1-3                 | -          | 1.26.0-1                 | 1.26.0-1    | 1.24.0-2                 | -                                                                                                                                                                                                                                                               |
| libinput-dev                                   | 1.28.1                   | -          | 1.31.3                   | 1.31.3      | 1.31.1                   | >= 1.21 (Cargo.toml `features=["libinput_1_21"]`). >= 1.30 turns on niri's libinput plugin-system cfg (niri build.rs); trixie builds without it.                                                                                                                |
| libdbus-1-dev                                  | 1.16.2-2                 | -          | 1.16.2-8                 | 1.16.2-8    | 1.16.2-2ubuntu4          | `dbus` feature (default)                                                                                                                                                                                                                                        |
| libsystemd-dev                                 | 257.13                   | -          | 262-1                    | 262.1-1     | 259.9                    | `systemd` feature (default)                                                                                                                                                                                                                                     |
| libseat-dev                                    | 0.9.1-1                  | -          | 0.9.3-1                  | 0.9.3-1     | 0.9.2-2                  | -                                                                                                                                                                                                                                                               |
| libpipewire-0.3-dev                            | 1.4.2-1                  | 1.6.9      | 1.6.9                    | 1.6.9       | 1.6.2                    | >= 0.3.33 (`features=["v0_3_33"]`); `xdp-gnome-screencast` feature (default)                                                                                                                                                                                    |
| libpango1.0-dev, libcairo2-dev, libglib2.0-dev | 1.56.3 / 1.18.4 / 2.84.4 | -          | 1.58.2 / 1.18.4 / 2.90.1 | same        | 1.57.0 / 1.18.4 / 2.88.0 | pango >= 1.44 (`features=["v1_44"]`)                                                                                                                                                                                                                            |
| libpixman-1-dev                                | 0.44.0-3                 | -          | 0.46.4                   | 0.46.4      | 0.46.4                   | smithay `renderer_pixman` (pixman-sys)                                                                                                                                                                                                                          |
| libdisplay-info-dev                            | 0.2.0-2                  | -          | 0.3.0-1+b1               | 0.3.0-1+b1  | 0.3.0-1                  | libdisplay-info-sys 0.3.0 accepts `>= 0.1, < 0.4` and auto-selects the v0_2 API on trixie. A trixie build against 0.2 is NOT verified.                                                                                                                          |

**As-is on Debian:** NO. niri is in no suite. Only `rust-niri-ipc` 25.8.0
exists, in forky and sid. xwayland-satellite is in no suite.

**Port steps:**

1. Build niri v26.04 into a deb (vendored-crates build; dh-cargo with
   Debian-packaged crates is not viable, see Issues):

   ```sh
   git clone --branch v26.04 https://github.com/niri-wm/niri && cd niri
   mkdir -p .cargo && cargo vendor --locked --versioned-dirs vendor > .cargo/config.toml   # needs network once; makes the tree offline-buildable (includes the smithay git dep)
   export NIRI_BUILD_COMMIT=$(git rev-parse --short HEAD)       # else `niri --version` says "unknown commit" (Packaging-niri.md)
   cargo build --release --frozen --offline                     # default features: dbus, systemd, xdp-gnome-screencast. NEVER --all-features.
   ```

   Install map (niri `docs/wiki/Packaging-niri.md`): `target/release/niri` ->
   `/usr/bin/niri`; `resources/niri-session` -> `/usr/bin/niri-session`;
   `resources/niri.desktop` -> `/usr/share/wayland-sessions/niri.desktop`;
   `resources/niri-portals.conf` ->
   `/usr/share/xdg-desktop-portal/niri-portals.conf`; `resources/niri.service`
   and `resources/niri-shutdown.target` -> `/usr/lib/systemd/user/`. Do not
   package the `niri-visual-tests` crate.
   - deb `Depends:` `${shlibs:Depends}`, `libwayland-server0` (stated explicitly
     because it is dlopened), `procps`.
   - deb `Recommends:` `xwayland-satellite (>= 0.8.3)`,
     `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk`, `gnome-keyring`.
   - Build-Depends: the build-dep table above, plus `debhelper (>= 13)`.
   - Check with `niri panic` that backtraces symbolize (Packaging-niri.md
     "Panics").

2. Build `ryoku-desktop-niri` as a deb:
   - Copy `ryoku/niri/.` to `/usr/share/ryoku/config/niri/`.
   - Install `ryoku/niri/niri-portals.conf` to
     `/usr/share/ryoku/config/xdg-desktop-portal/niri-portals.conf`.
   - Build the provider:
     `cd ryoku/wm/niri && go build -trimpath -buildmode=pie -o ryoku-wm-niri .`.
     The vendor/ dir is used automatically; go.mod says `go 1.22` with no
     toolchain line, so nothing is downloaded. Install it to
     `/usr/bin/ryoku-wm-niri`.
   - Install the drop-in to
     `/usr/lib/systemd/user/niri.service.d/ryoku-bootstrap.conf`. The path is
     the same on Debian.
   - `Depends: ryoku-desktop (= ${binary:Version}), niri (>= 26.04), xwayland-satellite (>= 0.8.3), xdg-desktop-portal-gnome, xdg-desktop-portal-gtk, gammastep`
     (`PKGBUILD:23-38`, with version bounds added).
   - `Provides: ryoku-desktop-compositor`. No `Conflicts:` (`PKGBUILD:40-41`).
3. Stop xdg-desktop-portal-gnome's Recommends from pulling GNOME Shell (Issues).
   Do one of: install with `--no-install-recommends`; set
   `APT::Install-Recommends "false"` in the installer chroot; or add
   `gnome-shell`/`gnome-settings-daemon` to an apt preferences pin at priority
   -1.
4. Ship `adw-gtk3` (`autostart.kdl:19`); recipe in the Icons/GTK section.
5. Keep `ryoku/wm/niri/caps.go:72-81` (`compositorPackages`) aligned with the
   Debian Depends list. The names are identical on Debian, and caps_test reads
   the PKGBUILD (see the wm-core section).

**Complexity:** Medium. One Rust project of about 476 registry crates plus a
smithay git dep. The work is a vendored cargo build and a short install map,
with no patches.

**Issues / risks:**

- **Debian `xdg-desktop-portal-gnome` Recommends GNOME Shell.** The 48.0-2
  control file has
  `Recommends: gnome-shell (>= 48~) | budgie-desktop, gnome-settings-daemon`;
  50.0-1 adds `papers`. A default `apt install` pulls the whole GNOME Shell. It
  also hard `Depends: nautilus (>= 47~beta)`, `xdg-desktop-portal-gtk`,
  `gsettings-desktop-schemas`. Arch's package has nautilus as its only heavy
  dep.
- trixie ships xdg-desktop-portal-gnome 48, against Arch's 51 (forky and
  resolute ship 50). niri's screencast path is xdg-desktop-portal-gnome over
  PipeWire (Screencasting.md). No minimum version is documented; screencast on
  trixie's 48 with niri 26.04 is not verified.
- trixie rustc 1.85.1 equals the MSRV, with zero headroom: any niri release that
  raises `rust-version` needs trixie-backports rustc (1.96.1). forky, sid and
  resolute have headroom.
- trixie libinput 1.28 is below 1.30, so niri builds without
  `have_libinput_plugin_system` (niri build.rs). That is a niri feature
  difference between trixie and forky; Ryoku's config does not reference it.
- trixie libdisplay-info 0.2.0 selects the v0_2 API (libdisplay-info-sys
  build.rs). Building niri against it is not verified; forky, sid and resolute
  have 0.3.0.
- The vendored build violates Debian policy for official archive uploads, which
  wants crates from `librust-*-dev`. Debian ships only `rust-niri-ipc` 25.8.0,
  and smithay is a git pin (`rev=ff5fa7d`) unpublished on crates.io. This only
  matters if the goal is an upload to the Debian archive; for a private
  `[ryoku]` apt repo it does not.
- Ryoku's `niri-portals.conf` (`ryoku/niri/niri-portals.conf:7-9`) routes only
  `default=gnome;gtk` and `FileChooser=gtk`. Upstream niri's own file (installed
  to `/usr/share/xdg-desktop-portal/niri-portals.conf`) also routes
  `Access=gtk`, `Notification=gtk` and `Secret=gnome-keyring`. Ryoku's copy,
  deployed via `/usr/share/ryoku/config/xdg-desktop-portal/`, shadows upstream's
  for the user. That behaviour is identical on Arch.
- Docs disagree with the code: `docs/compositors.md:302` says a variant package
  is "mutually exclusive with the others", while `PKGBUILD:40-41` says
  "deliberately not exclusive". The PKGBUILD is the behaviour, so emit no
  `Conflicts:`.
- Docs disagree on the verb count: `docs/compositors.md:22` says "eleven verbs";
  `docs/compositors.md:289` and `docs/adding-a-window-manager.md:48` say "ten".
- `ryoku/wm/niri/config_binds.go:167` binds the color picker to `hyprpicker -a`
  on niri. hyprpicker comes from the umbrella package
  (`release/packages/ryoku-desktop/PKGBUILD:199`), so a niri-only box still
  needs hyprpicker (trixie-backports/forky/sid 0.4.7, resolute 0.4.6) and its
  hyprutils library.

**Questions for the human:**

- niri runs on two Debian bases. Options: (a) trixie with trixie's rustc 1.85.1,
  libinput 1.28 and libdisplay-info 0.2. That is a zero-margin MSRV, no libinput
  plugin system, and an unverified 0.2 build. (b) trixie with backports rustc
  1.96 in the build chroot. That gives MSRV headroom but keeps the same C
  libraries. (c) forky or resolute, which have every dependency at the newer
  level.

---

### xwayland-satellite (`release/packages/xwayland-satellite/PKGBUILD`)

**What it does:** The rootless Xwayland bridge niri spawns on demand. niri
creates the X11 sockets, exports `$DISPLAY` and restarts the bridge if it dies
(`ryoku/niri/autostart.kdl:6-9`; niri 25.08 release notes need >= 0.7).

- `[ryoku]` builds commit `add2795` (`PKGBUILD:96-98`) for the override-redirect
  popup focus fix, upstream #494 (`PKGBUILD:81-89`).
- Build: `cargo build --frozen --release --features systemd` (`PKGBUILD:120`).
- The upstream unit's `/usr/local` is sed'd to `/usr` (`PKGBUILD:111`).
- Installs `/usr/bin/xwayland-satellite` and the user unit (`PKGBUILD:125-126`).

**Arch couplings:** `RUSTUP_TOOLCHAIN=stable` (`PKGBUILD:112,118`). The variable
is harmless with Debian's rustc but irrelevant there. No other couplings.

**Dependencies:**

| Arch pkg        | Used for (cite)                                                                                              | Debian/Ubuntu pkg                               | trixie      | trixie-bpo | forky       | sid         | resolute        | Min version (why)                                                                                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------- | ----------- | ---------- | ----------- | ----------- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (self)          | bridge                                                                                                       | none, build it                                  | -           | -          | -           | -           | -               | **v0.8.3** (2026-09-24). It contains add2795 (GitHub compare: add2795 is 2 commits behind v0.8.3, 0 ahead). Arch extra now ships 0.8.3-1, which supersedes Ryoku's build as `PKGBUILD:87-89` anticipated. |
| xorg-xwayland   | runtime                                                                                                      | xwayland                                        | 2:24.1.6-1  | -          | 2:24.1.14-1 | 2:24.1.14-1 | 2:24.1.10-1     | >= 23.1 (upstream README)                                                                                                                                                                                 |
| xcb-util-cursor | links libxcb-cursor (xcb-util-cursor-sys build.rs: pkg-config `xcb-cursor` + bindgen)                        | libxcb-cursor-dev (build), libxcb-cursor0 (run) | 0.1.5-1     | -          | 0.1.6-1     | 0.1.6-1     | 0.1.6-1         | -                                                                                                                                                                                                         |
| libxcb          | xcb crate 1.7 links only `xcb` (`src/ffi/base.rs`); extensions are Rust-side; default feature `libxcb_v1_14` | libxcb1-dev                                     | 1.17.0-2+b1 | -          | 1.17.0-2+b2 | 1.17.0-2+b2 | 1.17.0-2ubuntu1 | >= 1.14                                                                                                                                                                                                   |
| cargo, clang    | build (`PKGBUILD:104`)                                                                                       | cargo, rustc, clang, libclang-dev               | 1.85.1 / 19 | 1.96.1     | 1.96.1 / 21 | 1.97.1 / 21 | 1.93.1 / 21     | MSRV 1.85.0 and edition 2024 (Cargo.toml). The highest lockfile crate rust-version is 1.82, so trixie works.                                                                                              |
| git             | `vergen-gitcl` describe in build.rs                                                                          | git                                             | 2.47.3      | -          | 2.53        | 2.55        | 2.53            | build from a git clone                                                                                                                                                                                    |

**As-is on Debian:** NO. It is not packaged anywhere.

**Port steps:**

1. Build and install:

   ```sh
   git clone --branch v0.8.3 https://github.com/Supreeeme/xwayland-satellite && cd xwayland-satellite
   mkdir -p .cargo && cargo vendor --locked vendor > .cargo/config.toml
   sed -i 's|/usr/local|/usr|' resources/xwayland-satellite.service   # v0.8.3 unit still says ExecStart=/usr/local/bin/xwayland-satellite
   cargo build --release --frozen --offline --features systemd
   install -Dm755 target/release/xwayland-satellite debian/xwayland-satellite/usr/bin/xwayland-satellite
   install -Dm644 resources/xwayland-satellite.service -t debian/xwayland-satellite/usr/lib/systemd/user/
   ```

2. Package metadata:
   - deb `Depends: ${shlibs:Depends}, xwayland (>= 2:23.1)`.
   - Build-Depends:
     `cargo, rustc (>= 1.85), clang, libclang-dev, pkgconf, libxcb1-dev, libxcb-cursor-dev, git`.

**Complexity:** Low.

**Issues / risks:**

- The user unit is `WantedBy=graphical-session.target`. Do not enable it under
  niri: niri spawns the binary itself, and a manual start races that
  (`autostart.kdl:6-9`). Ship the unit disabled, with no postinst
  `systemctl --global enable`.

---

### ryoku-wm-niri provider (`ryoku/wm/niri/`)

**What it does:** The niri half of the seam (`main.go:135-147`). It has eleven
verbs: caps, act, watch, apply, outputs, state, defaults, session, schema, binds
and environment (`main.go:161-183`).

- It dials `$NIRI_SOCKET` (`session.go:29-35,82,138`).
- It writes `settings.kdl` and `rebinds.kdl` into `$XDG_CONFIG_HOME/niri`
  (`session.go:165-171`; generator `config_kdl.go:272-286`).
- It starts night light with `gammastep -m wayland -O` (`act.go:194`).
- It sends notifications with `notify-send` (`act.go:381`).
- It prints the wayland-session entry `Exec=niri-session`, `DesktopNames=niri`
  (`wayland_session.go:8-13`), byte-identical to upstream
  `resources/niri.desktop`.

**Arch couplings:**

- `caps.go:64-81`: `compositorPackages` holds pacman package names
  (`ryoku-desktop-niri`, `niri`, `xwayland-satellite`,
  `xdg-desktop-portal-gnome`, `gammastep`). The same names are valid on Debian
  when the self-built debs keep them.
- `caps_test.go:20-40`: the test parses
  `release/packages/ryoku-desktop-niri/PKGBUILD` `depends=( )`. It skips when
  the file is absent (see the hyprland caps_test).
- Otherwise none. There are no `/usr/lib` paths, and the only `/proc` reads are
  `act.go:671-680` and `session.go:174`.

**Dependencies:** golang-go >= 1.22 (`ryoku/wm/go.mod:3`). The vendored
dependency `github.com/BurntSushi/toml v1.6.0` (`ryoku/wm/vendor/modules.txt`)
is unused by niri. Runtime: niri >= 26.04, gammastep, libnotify-bin, and
quickshell `qs`, `kitty`, `wpctl` (wireplumber), `playerctl`, `hyprpicker`
(spawned from binds, `config_binds.go:138-177`).

**As-is on Debian:** YES for the binary. Runtime needs niri >= 26.04.

**Port steps:** Port no code. Point the caps_test at the Debian control file, or
keep the PKGBUILD as the reference (see wm core).

**Complexity:** Low.

---

### wm seam core (`ryoku/wm/*.go`)

**What it does:** This is the neutral contract.

- `detect.go:15-19` defines the provider names.
- `detect.go:41-49,211-258` detects the provider from `RYOKU_WM`, live
  `HYPRLAND_INSTANCE_SIGNATURE`/`NIRI_SOCKET` sockets, or `XDG_CURRENT_DESKTOP`.
- `detect.go:84-87` maps each provider to its config dir.
- `client.go:55-69` resolves the provider binary `ryoku-wm-<name>` by
  `exec.LookPath`.
- `reclaim.go` computes what a compositor switch can remove.
- This module is vendored into five consumers: `ryoku/cli/vendor/ryoku-wm`,
  `ryoku/hub/backend/vendor/ryoku-wm`, `ryoku/rashin/backend/vendor/ryoku-wm`,
  `ryoku/shell/ipc/vendor/ryoku-wm` and
  `ryoku/shell/ryogami/daemon/vendor/ryoku-wm`.

**Arch couplings:**

- `reclaim.go:204-206`: `pacman -Q <name>` is the installed check.
- `reclaim.go:247-267`:
  `pacman -Rs --print --print-format %n --assume-installed ryoku-desktop-compositor,1 <targets>`
  produces the removal plan. It parses pacman's `removing X breaks dependency`
  lines (`reclaim.go:217,225-236`) to drop blocked targets and re-plan
  (`reclaim.go:120-134`).
- `reclaim.go:271-292`: `pacman -Qi` "Installed Size" is parsed in KiB, MiB and
  GiB (`reclaim.go:307-324`).
- `reclaim.go:143-161`: `VerifyRemoval` re-runs the pacman plan right before
  removal.
- `caps.go:130-137`: `Caps.Packages` is documented as "the pacman packages".
- Callers outside this slice:
  - `ryoku/cli/wm.go:408` (Reclaim) then `ryoku/cli/wm.go:439`
    `pacman -Rns --noconfirm <targets>`.
  - `ryoku/cli/wm.go:300` `pacman -Rdd --noconfirm`.
  - `ryoku/hub/backend/wm.go:155` (Reclaim preview).

**Dependencies:** golang-go >= 1.22 (`go.mod:3`). `BurntSushi/toml` is vendored,
so `golang-github-burntsushi-toml-dev` is not needed.

**As-is on Debian:** PARTIAL. Detection, client and caps are portable. On a box
without pacman, Reclaim always fails: `pacmanInstalled` is false, so the targets
list is empty and Reclaim reports "nothing removable".

**Port steps (reclaim.go -> dpkg/apt):**

1. `pacmanInstalled(name)` becomes `dpkg-query -W -f='${db:Status-Abbrev}' name`
   and checks that the output equals `ii`.
2. `pacmanRemovalOnce(targets)` becomes a simulation of the whole switch
   transaction.
   - Run
     `apt-get -s -q -o Debug::NoLocking=1 install --autoremove ryoku-desktop-<incoming> <t1>- <t2>- ...`.
     The `-` suffix removes a target in the same transaction, and listing the
     incoming variant replaces `--assume-installed` (apt has no equivalent
     flag).
   - Collect the `Remv <pkg> [...]` lines as the set.
   - Blocked equivalent: apt does not refuse when a survivor depends on a
     target. It removes the dependent too. So a `Remv` package that is neither a
     target nor auto-installed (`apt-mark showauto`) is a cascade, and the
     target that dragged it in is "blocked". `parseRemovalPlan`
     (`reclaim.go:225-236`) must be rewritten for the apt transcript.
3. `pacmanInstalledSizes` becomes
   `dpkg-query -W -f='${Installed-Size}\n' <names>`. The value is an integer in
   KiB, so sum and multiply by 1024. `parseSize` becomes unnecessary.
4. `ryoku/cli/wm.go:439`: `pacman -Rns --noconfirm` becomes
   `apt-get purge --autoremove -y <targets>`. `-n` (nosave) maps to purge.
5. Re-vendor `ryoku-wm` into the five consumer modules listed above
   (`go mod vendor` in each). Otherwise the hub and cli keep the pacman copy.
6. `hyprland/caps_test.go:16` and `niri/caps_test.go:20-40` parse
   `release/packages/ryoku-desktop-<name>/PKGBUILD`. Point them at
   `debian/control` (the `Depends:` of `Package: ryoku-desktop-<name>`).
   Otherwise they `t.Skip` when the file is absent
   (`hyprland/caps_test.go:17-18`).

**Complexity:** Medium. The logic is small, but apt's cascade semantics differ
from pacman's refuse semantics, so the reviewed-set guarantee (`VerifyRemoval`)
has to be re-derived and re-tested.

**Issues / risks:**

- `apt-get --autoremove` also removes orphans that existed before the switch.
  pacman `-Rs` only removes dependencies orphaned by this transaction. Without
  filtering, the reviewed set would include unrelated leftover auto packages.
  Filter the set by first running `apt-get -s autoremove` and subtracting its
  result.
- Virtual `ryoku-desktop-compositor`: an unversioned `Provides` is fine.
  `ryoku-desktop` must `Depends: ryoku-desktop-compositor` (unversioned) or name
  the variants with `ryoku-desktop-hyprland | ryoku-desktop-niri`.

---

### ryoku-wm-hyprland provider (`ryoku/wm/hyprland/`)

**What it does:** The Hyprland half of the seam, including the `plugins` verb
(`config_plugins.go:19-37`).

- It runs `hyprctl` (`session.go:108-116`) against
  `$XDG_RUNTIME_DIR/hypr/<sig>/.socket.sock`, falling back to `/tmp/hypr`
  (`session.go:39,85-93`).
- It streams socket2 events (`watch.go:75-99`).
- It writes `settings.lua` and `rebinds.lua` and pushes live changes through
  `hyprctl eval` (`config_plugins.go:78-83`, `act.go:20-24`).
- It manages Hyprland plugins in three tiers (`config_plugins_tier.go:15-21`):
  - package `/usr/lib/hyprland/plugins` (`config_plugins.go:16`);
  - user build `~/.local/lib/hyprland/plugins`
    (`config_plugins_tier.go:149-152`);
  - hyprpm's `~/.local/share/hyprpm`, read-only
    (`config_plugins_tier.go:154-162`). It never runs `hyprpm`.
- Night light: `hyprsunset -t <K>` (`act.go:278`).
- Displays: `ryoku-monitor` (`outputs.go:133`).
- The QML module `ryoku/wm/hyprland/qml/` is installed by the Hyprland variant
  to `/usr/lib/qt6/qml/Ryoku/Wm/Hyprland`
  (`release/packages/ryoku-desktop-hyprland/PKGBUILD:87-88`).

**Hyprland version this provider needs: >= 0.56.0.**

- `hyprctl eval`, `hyprctl dispatch <lua-expr>` and the `hl.*` API exist only on
  Hyprland with Lua config. Lua config first appears in v0.55.0 (2026-05-09),
  per the release notes. `act.go:20-24` notes that `hyprctl keyword` is refused
  under the Lua parser.
- `hl.get_loaded_plugins()` is emitted in every `settings.lua` that enables a
  plugin (`config_plugins.go:113-118,168`). It was added in **v0.56.0**
  ("config/lua: add get_loaded_plugins (#14582)"). On 0.55.x the guard call
  errors inside `pcall`, so enabled plugins' config is silently skipped.
- `config_plugins.go:244-245`: hyprfocus keys are mapped to "the 0.56 plugin"
  names.
- `config_store.go:253` and `config_plugins.go:279`: the scrolling layout is
  "Hyprland core (0.54+)".
- `hl.*` APIs generated: `hl.config`, `hl.bind`, `hl.unbind`, `hl.animation`,
  `hl.curve`, `hl.env`, `hl.window_rule`, `hl.layer_rule`, `hl.workspace_rule`,
  `hl.monitor`, `hl.device`, `hl.gesture`, `hl.on`, `hl.exec_cmd`,
  `hl.dispatch`,
  `hl.dsp.{focus,exec_cmd,dpms,submap,exit,window.{move,close,float,fullscreen},workspace.{move,toggle_special}}`,
  `hl.plugin.load`, `hl.plugin.hyprbars.add_button`, `hl.get_loaded_plugins`
  (grep over `ryoku/wm/hyprland/*.go`).
- hyprctl commands: `version -j`, `dispatch`, `animations`, `eval`,
  `switchxkblayout`, `monitors`, `reload [config-only]`, `getoption -j`,
  `setcursor`, `workspaces`, `clients`, `activeworkspace`, `devices`,
  `plugins list -j`, `plugin load|unload`.
- socket2 events: `activewindow(v2)`, `windowtitle(v2)`, `openwindow`,
  `movewindowv2`, `workspace(v2)`, `focusedmonv2`, `createworkspacev2`,
  `destroyworkspacev2`, `activespecialv2`, `moveworkspacev2`,
  `monitoradded(v2)`, `activelayout` (`watch.go:80-99`). All predate 0.55, so
  none pins further.

**Arch couplings:**

- `config_plugins_tier.go:686-700`: `packageVersion` runs `pacman -Q <pkg>` to
  show the package tier's version.
- `config_plugins_tier.go:31`: `pluginDef.Package` is "the pacman package that
  ships the .so". The packages are `ryoku-hypr-plugins`, `hyprglass`,
  `imgborders`, `hypr-dynamic-cursors` and `ryoku-keysounds`
  (`config_plugins_tier.go:37-87`).
- `caps.go:59-82`: `compositorPackages` holds the Arch names. The list includes
  `hyprpolkitagent`, `xdg-desktop-portal-hyprland`,
  `hyprland-preview-share-picker`, `hypridle`, `hyprpicker` and `hyprsunset`;
  all must keep those names as self-built debs.
- `config_plugins_tier.go:83`: the Docs URL points at
  `github.com/ryoku-dev/ryoku-arch`. Cosmetic.
- Runtime plugin build (`config_plugins_build.go`) does the following:
  - It runs `git clone`/`git fetch` of the upstream repos into
    `~/.cache/ryoku/hypr-plugins-src` (`config_plugins_build.go:111-171`). The
    repos are `github.com/hyprwm/hyprland-plugins`,
    `github.com/hyprnux/hyprglass`, `codeberg.org/zacoons/imgborders` and
    `github.com/VirtCode/hypr-dynamic-cursors` (`config_plugins_tier.go:41-67`).
  - It checks out the commit that the upstream `hyprpm.toml` `commit_pins` maps
    to the **Hyprland git commit read from the installed headers**
    (`config_plugins_build.go:84-91,176-193,364-367`).
  - It runs the manifest's `build` steps through `sh -c` with
    `MAKEFLAGS=-j$(nproc)` (`config_plugins_build.go:250-264`).
  - It runs `strip --strip-unneeded` on the result and writes the `.so` plus a
    `<id>.abi` receipt atomically into the user tier
    (`config_plugins_build.go:267-282`).
  - The toolchain gate requires the binaries `git make c++ pkg-config cmake` and
    that `pkg-config --exists hyprland` succeeds
    (`config_plugins_tier.go:648-659`).
- Headers lookup: `pkg-config --variable=prefix hyprland` +
  `/hyprland/src/version.h`, falling back to
  `/usr/include/hyprland/src/version.h` (`config_plugins_tier.go:265-273`).
  Upstream `hyprland.pc.in` sets `prefix=@PREFIX@/@INCLUDEDIR@`; Debian's rules
  set the include dir to `include/x86_64-linux-gnu`, so the prefix is
  `/usr/include/x86_64-linux-gnu` and the pkg-config path still resolves.
- ABI receipt format:
  `<GIT_COMMIT_HASH>_aq_<maj.min>_hu_<maj.min>_hg_<maj.min>_hc_<maj.min>_hlg_<maj.min>`,
  parsed by the regex `^([0-9a-f]+)_aq_...` (`config_plugins_tier.go:179`). The
  build side reads it from version.h `GIT_COMMIT_HASH` and `*_VERSION`
  (`config_plugins_tier.go:288-302`). The live side reads it from
  `hyprctl version -j` `abiHash` (`config_plugins_tier.go:236-252`).

**Dependencies:**

| Need                                     | Used for (cite)                                                                      | Debian pkg                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | trixie                                                                     | trixie-bpo          | forky                                                    | sid         | resolute                                                 | Min (why)                                                            |
| ---------------------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------- | -------------------------------------------------------- | ----------- | -------------------------------------------------------- | -------------------------------------------------------------------- |
| Go                                       | build                                                                                | golang-go                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | 1.24                                                                       | 1.27                | 1.27                                                     | 1.27        | 1.26                                                     | 1.22 (`go.mod:3`)                                                    |
| Hyprland + hyprctl                       | everything                                                                           | hyprland (stack section)                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | -                                                                          | 0.55.2+ds-1~bpo13+1 | 0.56.2+ds-3                                              | 0.56.2+ds-3 | 0.53.3+ds-4                                              | >= 0.56.0 (`hl.get_loaded_plugins`)                                  |
| Hyprland headers + .pc                   | plugin rebuild, ABI target (`config_plugins_tier.go:265-273,655`)                    | `hyprland-dev` (Debian: headers under `/usr/include/x86_64-linux-gnu/hyprland/`, `hyprland.pc` in the multiarch libdir; Depends on the stack's -dev debs (aquamarine, hyprutils, hyprlang, hyprcursor, hyprgraphics) plus `libdrm-dev libegl-dev libcairo2-dev libxkbcommon-dev libinput-dev libwayland-dev libpixman-1-dev libudev-dev libpango1.0-dev` (hyprland.pc `Requires:`, hyprbars Makefile `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon`) | -                                                                          | 0.55.2              | 0.56.2                                                   | 0.56.2      | 0.53.3                                                   | same commit as the running Hyprland                                  |
| git, make, c++, pkg-config, cmake, strip | runtime plugin rebuild (`config_plugins_tier.go:650`, `config_plugins_build.go:270`) | git, make, g++ (provides `c++`), pkgconf, cmake, binutils                                                                                                                                                                                                                                                                                                                                                                                                                                      | 2.47 / 4.4.1 / gcc-14 default (gcc-defaults 1.220) / 1.8.1 / 3.31.6 / 2.44 | cmake 4.3.4         | 2.53 / 4.4.1 / gcc-defaults 1.233 / 2.5.1 / 4.3.4 / 2.47 | same        | 2.53 / 4.4.1 / gcc-defaults 1.230 / 2.5.1 / 4.2.3 / 2.46 | a compiler able to parse the installed Hyprland headers (see Issues) |
| hyprsunset                               | night light (`act.go:278`)                                                           | hyprsunset                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | -                                                                          | 0.4.0               | 0.4.0                                                    | 0.4.0       | - (build)                                                | -                                                                    |
| libnotify-bin                            | `notify-send` (`act.go:522`)                                                         | libnotify-bin                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | 0.8.6-1                                                                    | -                   | 0.8.8-1+b1                                               | 0.8.8-1+b1  | 0.8.8-1                                                  | -                                                                    |

**As-is on Debian:** PARTIAL. IPC, apply and act are portable once Hyprland >=
0.56 is installed. `packageVersion` returns "" without pacman, so package-tier
rows show no version. Plugin ABI verification and rebuild depend on how the
Hyprland deb is built.

**Port steps:**

1. `config_plugins_tier.go:686-700`: replace `exec.Command("pacman", "-Q", pkg)`
   with `dpkg-query -W -f='${db:Status-Abbrev} ${Version}' pkg`. Return the
   version only when the status starts with `ii`.
2. **The Hyprland deb must be built with the real upstream commit hash.**
   Hyprland's CMake takes `GIT_COMMIT_HASH` from `$ENV{GIT_COMMIT_HASH}` or
   `git rev-parse HEAD`. Otherwise it writes the literal `unknown` (upstream
   CMakeLists.txt:177-180,225-227). `unknown` fails `abiRe`
   (`config_plugins_tier.go:179`), which has two effects:
   - `buildPlugins` refuses every rebuild with "Hyprland headers not found"
     (`config_plugins_build.go:330-336`);
   - `pickCopy` loads the first copy unverified
     (`config_plugins_tier.go:361-362`). Upstream `hyprpm.toml` `commit_pins`
     are keyed by upstream Hyprland commit, so the hash must also be the
     _upstream tag's_ commit, with Debian patches applied as quilt patches and
     not as new commits. A git-clone build has it. For a tarball build, export
     `GIT_COMMIT_HASH=<40-hex tag commit>` in debian/rules. Debian's own
     `hyprland-dev` 0.56.2+ds-3 already carries
     `GIT_COMMIT_HASH "efb50993780079460b0cbed1363e2166a2de1d9f"` (the v0.56.2
     tag commit) and the real library versions in `version.h` (checked by
     extracting the deb), so forky/sid need nothing here.
3. Keep the package plugin dir `/usr/lib/hyprland/plugins`
   (`config_plugins.go:16`) in the plugin debs. It is a private, non-multiarch
   dir, which Debian policy allows.
4. Headers: Debian's `hyprland-dev` installs them multiarch
   (`-DCMAKE_INSTALL_INCLUDEDIR=include/${DEB_HOST_MULTIARCH}`; `hyprland.pc`
   has `prefix=/usr/include/x86_64-linux-gnu`). The pkg-config lookup
   (`config_plugins_tier.go:267-270`) resolves that; only the fallback
   `/usr/include/hyprland/src/version.h` (`:272`) needs a second, multiarch
   candidate.
5. For runtime rebuilds, make the "toolchain" a Recommends of the plugin-manager
   package: `git, make, g++, pkgconf, cmake, binutils, hyprland-dev`.

**Complexity:** Medium. The code edit is one function. The real coupling is that
Hyprland's build must preserve the upstream commit and that a matching C++
compiler exists on the user's machine.

**Issues / risks:**

- Hyprland >= 0.56 is C++26; trixie's gcc-14/15 libstdc++ can't compile it, so
  it builds with `g++-16` from pinned sid.
  - Debian's default `c++` is g++ 14.2 on trixie (gcc-defaults 1.220), g++ 16.1
    on forky and sid (`g++ 4:16.1.0-3`), and g++ 15.2 on resolute.
  - gcc-16 is in forky and sid as 16.2.0-3 and in resolute universe as a
    snapshot (16-20260322).
  - Runtime plugin rebuilds compile against Hyprland's headers with the default
    `c++`. hyprbars uses `-std=c++2b` (hyprland-plugins `hyprbars/Makefile`).
  - Whether those headers compile with g++-14 or g++-15 is **not verified**. If
    they do not, `ryoku-wm-hyprland plugins rebuild` fails on every Debian suite
    unless `CXX=g++-16` is exported into the build env
    (`config_plugins_build.go:258`) and g++-16 is installed.
- Every Hyprland upgrade changes `GIT_COMMIT_HASH`, which stales every plugin's
  `.abi`. Package-tier plugin debs must be rebuilt in lockstep with
  `Depends: hyprland (= <exact version>)`. (The plugin-packaging section covers
  this; this provider only detects the mismatch, in `abiDiff`,
  `config_plugins_tier.go:190-207`.)
- Runtime rebuild clones from github.com and codeberg.org on the user's machine
  (`config_plugins_tier.go:41-67`). This is unchanged from Arch. An offline box
  cannot rebuild.

---

---

## Part D: App configs (`ryoku/apps/`) and the preinstalled list

### Delivery of app configs (`release/packages/ryoku-desktop/PKGBUILD`, `ryoku/cli/internal/updater/materialize.go`)

**What it does:** `package()` copies each app config into
`/usr/share/ryoku/config/<app>`
(`release/packages/ryoku-desktop/PKGBUILD:369-441`), `ryoku materialize` copies
that tree into `~/.config` (`ryoku/apps/README.md:92-110`, `PKGBUILD:269`). Some
files are seeded once and never overwritten: `fastfetch/config.jsonc`,
`kitty/current-theme.conf`, `ghostty/config`, `ghostty/ryoku-colors` and the
whole `nvim/` tree (`ryoku/cli/internal/updater/materialize.go:41-65`). A loop
over `ryoku/apps/*/` installs any app holding `quickshell/` or `CMakeLists.txt`:
QML tree to `/usr/share/ryoku/config/quickshell/<name>`, `bin/*` to `/usr/bin`,
every `*/go.mod` built with `go build` to `/usr/bin/<module>`, `*.desktop` to
`/usr/share/applications`, icon to hicolor (`PKGBUILD:283-320`). System-wide
drops: `ryoku-nvim.desktop`, `compress-video.desktop`, `install-app.desktop`,
vendor `mimeapps.list` in `/usr/share/applications` (`PKGBUILD:415-435`),
`ryoku-fastfetch` to `/usr/bin` (`PKGBUILD:533`), the Nautilus extension to
`/usr/share/nautilus-python/extensions` (`PKGBUILD:560`). `~/.npmrc` is not
packaged; the installer seeds it (`installation/backend/lib/deploy.sh:307`,
`ryoku-shell-installer/engine.go:1289`). The share-picker config ships from the
Hyprland variant (`release/packages/ryoku-desktop-hyprland/PKGBUILD:65-66`). Dev
checkouts seed via `ryoku/shell/deploy.sh:890-892`.

**Arch couplings:**

- `PKGBUILD` itself (makepkg);
  `makedepends=('go' 'cmake' 'ninja' 'qt6-base' 'qt6-declarative')`
  (`PKGBUILD:19`).
- Apps are deliberately optdepends (`PKGBUILD:214-242`), installed once by
  `ryoku doctor`'s shipped-apps reconciler using `pacman -Qdq`,
  `sudo pacman -S --needed`, `pacman -D --asexplicit`
  (`ryoku/cli/internal/doctor/reconcile_shipped_apps.go:72-86`); on a box
  without pacman it returns "not a pacman box; shipped apps are the installer's
  business" (`reconcile_shipped_apps.go:88-93`), so on Debian apps added in a
  later release never reach existing machines.
- The shipped-app table uses Arch names: `nautilus-python` (Debian
  `python3-nautilus`), `blesh` (Debian `ble.sh`),
  `yazi`/`waifu2x-ncnn-vulkan`/`songrec`/`gamescope` (not in trixie)
  (`ryoku/cli/internal/ryokumanifest/manifest.go:161-179`).
- Ryoku.Ui QML module (imported by both Quickshell apps) is installed to
  `/usr/lib/qt6/qml/Ryoku/Ui` (`PKGBUILD:331-332`); Debian's QML dir is
  `/usr/lib/x86_64-linux-gnu/qt6/qml`.

**As-is on Debian:** NO, the packaging is makepkg-only and app delivery on
update is pacman-only.

**Port steps:**

1. In the `ryoku-desktop` deb, reproduce `PKGBUILD:369-441,533,560` as
   `debian/ryoku-desktop.install` lines (paths unchanged:
   `/usr/share/ryoku/config/...`, `/usr/share/applications/...`,
   `/usr/share/nautilus-python/extensions/...`, `/usr/bin/ryoku-fastfetch`).
2. Reproduce the app loop (`PKGBUILD:283-320`) in `debian/rules`
   `override_dh_auto_build`/`override_dh_auto_install`: for `ryostore`, `ryovm`
   copy `quickshell/` to `/usr/share/ryoku/config/quickshell/<name>/`, install
   `bin/*` to `/usr/bin`, build `ryostore/backend` -> `/usr/bin/ryostore`,
   `ryovm/fetch` -> `ryovm-fetch`, `ryovm/mon` -> `ryovm-mon`, `ryovm/remote` ->
   `ryossh` (module names in each `go.mod:1`), install `*.desktop` and
   `quickshell/logo.svg` as `/usr/share/icons/hicolor/scalable/apps/<name>.svg`.
3. Install Ryoku.Ui to `/usr/lib/x86_64-linux-gnu/qt6/qml/Ryoku/Ui` (Debian QML
   path).
4. Rewrite `reconcile_shipped_apps.go` against dpkg/apt: "installed" =
   `dpkg-query -W -f='${Status}' <pkg>` contains `install ok installed`;
   "installed as dependency" = `apt-mark showauto <pkg>`; install =
   `sudo apt-get install -y --no-install-recommends <pkgs>`; mark explicit =
   `sudo apt-mark manual <pkgs>`; replace the `hasPacman` gate with a `dpkg`
   check. Map the names in `manifest.go:161-179` to Debian names (table in the
   preinstalled section below).

**Complexity:** Medium. Mechanical file mapping plus one reconciler rewrite.

**Issues / risks:**

- The `go build` in the loop runs with network unless vendored or
  `GOTOOLCHAIN=local`/`GOFLAGS=-mod=vendor`; the modules are stdlib-only
  (`ryostore/backend/go.mod`, `ryovm/{fetch,mon,remote}/go.mod` carry no
  `require`), so only the toolchain version matters (see RyoStore).
- `ryostore/quickshell/lib/store.test.mjs` is copied into the installed QML tree
  by `cp -a` (`PKGBUILD:290`); harmless, same on Debian.

---

### kitty (`ryoku/apps/kitty`)

**What it does:** terminal config: font, beam cursor with `cursor_trail`,
margins, copy/paste/zoom maps, `include current-theme.conf` (matugen palette),
`include current-font.conf` (daemon-written font, SIGUSR1 reload),
`globinclude user.conf` (`ryoku/apps/kitty/kitty.conf:2-39`). Palette seed
(`ryoku/apps/kitty/current-theme.conf:1-35`). The font file is written by
`writeKittyFont` (`ryoku/shell/ipc/matugen.go:1680-1690`).

**Arch couplings:** none in the file.

**Dependencies:**

| Arch pkg               | Used for (cite)                                                                                                                                            | Debian/Ubuntu pkg                        | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                 |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ------ | ---------- | ------ | ------ | -------- | --------------------------------------- |
| kitty (0.49.2 on Arch) | the terminal (`PKGBUILD:214`, `base.packages:165`)                                                                                                         | kitty                                    | 0.41.1 | -          | 0.48.2 | 0.48.2 | 0.45.0   | 0.37.0 (`cursor_trail`, `kitty.conf:7`) |
| (none)                 | `font_family SpaceMono Nerd Font` (`kitty.conf:2`), also qt6ct and Ryoku.Ui mono (`ryoku/shell/qt6ct/qt6ct.conf:10`, `ryoku/ui/Singletons/Tokens.qml:107`) | none (`fonts-space-mono` does not exist) | -      | -          | -      | -      | -        | Nerd Fonts `SpaceMono` (release v3.5.1) |

**As-is on Debian:** YES (trixie's 0.41.1 parses every option used).

**Port steps:**

1. Install `kitty` (Debian ships `/usr/bin/kitty` and `/usr/bin/kitten`, the
   latter used by Ryoport `kitten ssh`,
   `ryoku/apps/ryovm/remote/ryossh.go:926-928`).
2. Package the SpaceMono Nerd Font: download `SpaceMono.tar.xz` from
   `https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.1`, install
   `*.ttf` to `/usr/share/fonts/truetype/ryoku-nerd/`, run `fc-cache` from a
   dpkg trigger (fontconfig's trigger on `/usr/share/fonts` already fires).

**Complexity:** Low.

**Issues / risks:**

- No package in `system/packages/*.packages` or any PKGBUILD installs "SpaceMono
  Nerd Font" (grep for `space-mono`/`spacemono` finds only references, no
  provider). On Arch kitty and qt6ct fall back to a fontconfig match; the Debian
  port inherits the same gap unless the font is packaged.
- `ryoku/apps/README.md:8` says JetBrains Mono Nerd Font; the config uses
  SpaceMono (`kitty.conf:2`). Doc is stale.

---

### fish (`ryoku/apps/fish`)

**What it does:** PATH/GOBIN/CARGO_INSTALL_ROOT/EDITOR, fixed syntax colours,
runs `ryoku-fastfetch`, inits starship, zoxide (`--cmd cd`), mise, fzf
(`fzf --fish`), sets fzf commands when `fd` exists, eza aliases, sources
`user.fish` (`ryoku/apps/fish/config.fish:4-80`). `conf.d/rashin.fish` wires
`ryoku-rashin` with `bind alt-r` (fish 4) falling back to `\er` (fish 3)
(`ryoku/apps/fish/conf.d/rashin.fish:45-51`).

**Arch couplings:**

- `command -v fd` (`config.fish:58`): Debian's fd-find installs
  `/usr/bin/fdfind` and `/usr/lib/cargo/bin/fd`, not `/usr/bin/fd`, so the
  fzf/fd wiring is skipped silently.

**Dependencies:**

| Arch pkg          | Used for (cite)                                                            | Debian/Ubuntu pkg         | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                                                |
| ----------------- | -------------------------------------------------------------------------- | ------------------------- | ------ | ---------- | ------ | ------ | -------- | ---------------------------------------------------------------------- |
| fish (4.9.3)      | shell (`base.packages:240`)                                                | fish                      | 4.0.2  | -          | 4.9.3  | 4.9.3  | 4.2.1    | 3.2 (`fish_add_path`, `config.fish:5`); 4.x preferred for `bind alt-r` |
| fzf               | `fzf --fish` (`config.fish:66`)                                            | fzf                       | 0.60.3 | -          | 0.74.4 | 0.74.4 | 0.67.0   | 0.48.0 (first release with `--fish/--bash/--zsh`)                      |
| zoxide            | `zoxide init fish --cmd cd` (`config.fish:49`)                             | zoxide                    | 0.9.7  | -          | 0.10.0 | 0.10.0 | 0.9.8    | 0.8                                                                    |
| starship          | prompt (`config.fish:43`)                                                  | starship                  | 1.22.1 | -          | 1.26.0 | 1.26.0 | 1.22.1   | see starship                                                           |
| mise (2026.10.12) | `mise activate fish` (`config.fish:54`), dev toolchain (`dev.packages:11`) | none                      | -      | -          | -      | -      | -        | any                                                                    |
| eza               | aliases (`config.fish:71-74`)                                              | eza                       | 0.21.0 | -          | 0.23.5 | 0.23.5 | 0.23.4   | `--icons=auto` form (eza >= 0.16)                                      |
| fd                | fzf walker (`config.fish:58-61`)                                           | fd-find (binary `fdfind`) | 10.2.0 | -          | 10.5.0 | 10.5.0 | 10.3.0   | any                                                                    |

**As-is on Debian:** PARTIAL: everything works except the fd-backed fzf
commands, and mise is absent.

**Port steps:**

1. Ship `/usr/bin/fd -> fdfind` as a symlink in a Ryoku compat deb (no Debian
   package owns `/usr/bin/fd`; `/usr/local` must not be dpkg-owned). Alternative
   edit: `config.fish:58` `command -v fd` ->
   `command -v fd; or command -v fdfind` and use the found name.
2. Package mise: upstream binary `mise-v<ver>-linux-x64.tar.gz` from
   `https://github.com/jdx/mise/releases` -> `/usr/bin/mise`, or add upstream's
   apt repo `https://mise.jdx.dev/deb`.
3. Set fish as login shell: Debian's fish postinst adds `/usr/bin/fish` to
   `/etc/shells`; the Hub validates against `/etc/shells`
   (`ryoku/hub/backend/shellpref.go:37-54`).

**Complexity:** Low.

---

### bash + ble.sh (`ryoku/apps/bash`)

**What it does:** sources `~/.config/ryoku-terminal/env.sh`, then for
interactive shells runs fastfetch, zoxide, mise, `fzf --bash`, bash-completion,
ble.sh with Ryoku faces, starship, eza aliases, rashin and `user.bash`
(`ryoku/apps/bash/ryoku.bash:5-57`). `rashin.bash` binds `\er` and a
PROMPT_COMMAND hook (`ryoku/apps/bash/rashin.bash:30-52`). The Hub appends
`[ -r "$HOME/.config/bash/ryoku.bash" ] && . ...` as the last line of
`~/.bashrc` and `~/.bash_profile` (`ryoku/hub/backend/shellpref.go:14,63-66`).

**Arch couplings:**

- `/usr/share/blesh/ble.sh` (`ryoku.bash:18-19`) from Ryoku's own `blesh`
  package (`release/packages/blesh/PKGBUILD:1-16`, tarball
  `ble-0.4.0-devel3-2.tar.xz` unpacked into `/usr/share/blesh`). Debian
  forky/sid/resolute `ble.sh` uses the same path `/usr/share/blesh/ble.sh`.
- Hub writes `~/.bash_profile` (`shellpref.go:65`). Arch skel ships a
  `~/.bash_profile` that sources `~/.bashrc`; Debian skel ships `~/.profile`
  instead. Creating `~/.bash_profile` on Debian makes bash login shells stop
  reading `~/.profile` (bash reads only the first of `.bash_profile`,
  `.bash_login`, `.profile`), dropping Debian's `~/.profile` (umask,
  `~/bin`/`~/.local/bin` PATH, sourcing `.bashrc`).
- `/usr/share/bash-completion/bash_completion` (`ryoku.bash:17`): same path on
  Debian.

**Dependencies:**

| Arch pkg                       | Used for (cite)                                       | Debian/Ubuntu pkg | trixie | trixie-bpo | forky             | sid               | resolute          | Min version Ryoku needs           |
| ------------------------------ | ----------------------------------------------------- | ----------------- | ------ | ---------- | ----------------- | ----------------- | ----------------- | --------------------------------- |
| bash                           | shell                                                 | bash              | (base) |            |                   |                   |                   | 5.x                               |
| blesh (Ryoku pkg 0.4.0_devel3) | line editor (`ryoku.bash:18-40`, `base.packages:234`) | ble.sh            | -      | -          | 0.4.0~git20250806 | 0.4.0~git20250806 | 0.4.0~git20250806 | 0.4.0-devel3 (`blesh/PKGBUILD:2`) |
| bash-completion                | completions (`ryoku.bash:17`)                         | bash-completion   | 2.16.0 | -          | 2.16.0            | 2.16.0            | 2.16.0            | any                               |
| fzf                            | `fzf --bash` (`ryoku.bash:15`)                        | fzf               | 0.60.3 | -          | 0.74.4            | 0.74.4            | 0.67.0            | 0.48.0                            |

**As-is on Debian:** PARTIAL: no ble.sh on trixie; `~/.bash_profile` shadowing;
fd (via env.sh).

**Port steps:**

1. trixie: build a `ble.sh` deb from Ryoku's recipe:
   `curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3-2.tar.xz`
   (sha256 `bdcdcfff216495403adf82a701fe41675f64b64644dc77caabd3e015871ebd61`,
   `blesh/PKGBUILD:10-11`), install contents to `/usr/share/blesh/`. Name it
   `ble.sh` with a version below Debian's so forky's package supersedes it.
   forky/sid/resolute: use Debian's `ble.sh`.
2. In `shellpref.go:63-66`, when `~/.bash_profile` does not exist and
   `~/.profile` does, write the loader into `~/.profile` instead (or create
   `~/.bash_profile` containing `[ -f ~/.profile ] && . ~/.profile` before the
   loader).

**Complexity:** Low.

---

### zsh + plugins + oh-my-zsh (`ryoku/apps/zsh`)

**What it does:** sources env.sh, fastfetch, optional oh-my-zsh from
`${ZSH:-/usr/share/oh-my-zsh}` with updater disabled, starship (or omz theme),
zoxide, mise, `fzf --zsh`, compinit with a cache dump, then autosuggestions,
history-substring-search, syntax-highlighting, Ryoku highlight styles, key
binds, eza aliases, rashin and `user.zsh` (`ryoku/apps/zsh/ryoku.zsh:4-96`).
Loader appended to `~/.zshrc` by the Hub (`shellpref.go:15,68`).

**Arch couplings:**

- `/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh`
  (`ryoku.zsh:45-46`); Debian path
  `/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh`.
- `/usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh`
  (`ryoku.zsh:47-48`); no Debian/Ubuntu package exists.
- `/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`
  (`ryoku.zsh:49-50`); Debian path
  `/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh`.
- `/usr/share/oh-my-zsh` (`ryoku.zsh:15-16`) from `ryoku-oh-my-zsh`, ohmyzsh
  commit `4b657407c98bbc8830ae66c2ac7ff3d737c55a83`
  (`release/packages/ryoku-oh-my-zsh/PKGBUILD:24-30`), hard depend of
  ryoku-desktop (`PKGBUILD:31`). Not in Debian.
- The three plugins are hard depends of ryoku-desktop (`PKGBUILD:96-99`).
- Ubuntu only: `/etc/zsh/zshrc` runs a global `compinit` when `/etc/os-release`
  ID is ubuntu (Debian zsh `debian/zshrc:106-113`), before `~/.zshrc`;
  `ryoku.zsh:37-43` (or oh-my-zsh) runs compinit again.

**Dependencies:**

| Arch pkg                     | Used for (cite)              | Debian/Ubuntu pkg                                             | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs |
| ---------------------------- | ---------------------------- | ------------------------------------------------------------- | ------ | ---------- | ------ | ------ | -------- | ----------------------- |
| zsh                          | shell (`PKGBUILD:96`)        | zsh                                                           | 5.9    | -          | 5.9.2  | 5.9.2  | 5.9      | 5.x                     |
| zsh-autosuggestions          | `ryoku.zsh:45`               | zsh-autosuggestions                                           | 0.7.1  | -          | 0.7.1  | 0.7.1  | 0.7.1    | any                     |
| zsh-syntax-highlighting      | `ryoku.zsh:49`               | zsh-syntax-highlighting                                       | 0.8.0  | -          | 0.8.0  | 0.8.0  | 0.8.0    | any                     |
| zsh-history-substring-search | `ryoku.zsh:47,77-82`         | none (build: `zsh-users/zsh-history-substring-search` v1.1.0) | -      | -          | -      | -      | -        | any                     |
| ryoku-oh-my-zsh              | `ryoku.zsh:15-28`            | none (build from pinned commit)                               | -      | -          | -      | -      | -        | commit `4b65740`        |
| fzf                          | `fzf --zsh` (`ryoku.zsh:35`) | fzf                                                           | 0.60.3 | -          | 0.74.4 | 0.74.4 | 0.67.0   | 0.48.0                  |

**As-is on Debian:** PARTIAL: loads, but all three plugins and oh-my-zsh are
silently skipped (every source is guarded by `[[ -r ... ]]`).

**Port steps:**

1. Edit `ryoku.zsh:45-50` to try the Debian path first, e.g.
   `for _p in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do [[ -r $_p ]] && { source $_p; break; }; done`
   (same for syntax-highlighting).
2. Package `zsh-history-substring-search` as a deb:
   `git clone --branch v1.1.0 https://github.com/zsh-users/zsh-history-substring-search`,
   install `zsh-history-substring-search.zsh` to
   `/usr/share/zsh/plugins/zsh-history-substring-search/` (keeps `ryoku.zsh:47`
   unchanged).
3. Package `ryoku-oh-my-zsh` as a deb:
   `git clone https://github.com/ohmyzsh/ohmyzsh && git -C ohmyzsh checkout 4b657407c98bbc8830ae66c2ac7ff3d737c55a83`,
   copy to `/usr/share/oh-my-zsh/`, LICENSE to
   `/usr/share/doc/ryoku-oh-my-zsh/copyright`.
4. resolute: ship `skip_global_compinit=1` in `/etc/zsh/zshenv.d`-equivalent
   (Ubuntu reads `$ZDOTDIR/.zshenv`; write it into `~/.zshenv` alongside the
   loader in `shellpref.go`).

**Complexity:** Low.

---

### terminal-shell env (`ryoku/apps/terminal-shell/env.sh`)

**What it does:** POSIX env shared by bash and zsh: `~/.local/bin` on PATH,
GOBIN, CARGO_INSTALL_ROOT, EDITOR/VISUAL=nvim, fzf commands via `fd`
(`ryoku/apps/terminal-shell/env.sh:2-16`). Installed to `ryoku-terminal/env.sh`
(`PKGBUILD:372`).

**Arch couplings:** `command -v fd` (`env.sh:12`), Debian binary is `fdfind`.

**As-is on Debian:** PARTIAL (fd branch skipped).

**Port steps:** same fd shim as fish step 1, or edit `env.sh:12-16` to
`for _fd in fd fdfind; do command -v "$_fd" >/dev/null 2>&1 && break; done` and
use `$_fd` in the three exports.

**Complexity:** Low.

---

### starship (`ryoku/apps/starship/starship.toml`)

**What it does:** prompt with `palette = "mythos"`, `[palettes.mythos]`, Nerd
Font pill caps, directory/git_branch/cmd_duration/character modules, package
module off (`ryoku/apps/starship/starship.toml:1-46`). Installed to
`~/.config/starship.toml` (`PKGBUILD:382`).

**Arch couplings:** none.

**Dependencies:** starship: trixie 1.22.1, forky 1.26.0, sid 1.26.0, resolute
1.22.1, Arch 1.27.0. Minimum: the release that added `palette`/`[palettes.*]`
(1.11 era); every listed version qualifies. Needs a Nerd Font for glyphs
(`starship.toml:25-38`).

**As-is on Debian:** YES.

**Port steps:** install `starship`.

**Complexity:** Low.

---

### fastfetch (`ryoku/apps/fastfetch`)

**What it does:** `config.jsonc` draws the emblem with `"type": "kitty-direct"`
from `~/.config/fastfetch/fastfetch-emblem.png`, truecolor keys,
`percent.color`, gpu `detectionMethod: pci`, `command` modules calling
`ryoku version`, `packages`, `colors` with `symbol: circle`
(`ryoku/apps/fastfetch/config.jsonc:3-52`). `ryoku-fastfetch` wrapper: kitty ->
`--pipe false`, else `--logo-type chafa` if chafa exists, else no logo
(`ryoku/apps/fastfetch/ryoku-fastfetch:15-24`). Emblem shipped beside the config
(`PKGBUILD:392-393`).

**Arch couplings:**

- Readout text "RYOKU · 力 · a hand-built Arch desktop" (`config.jsonc:25`).
- `AGE` uses `stat -c %W /` (`config.jsonc:46`): works with Debian coreutils
  (statx).

**Dependencies:**

| Arch pkg           | Used for (cite)                          | Debian/Ubuntu pkg      | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                                                                                                                                                          |
| ------------------ | ---------------------------------------- | ---------------------- | ------ | ---------- | ------ | ------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fastfetch (2.70.0) | readout (`base.packages:238`)            | fastfetch              | 2.40.4 | -          | 2.69.0 | 2.69.0 | 2.57.1   | <= 2.40.4: every key used (`kitty-direct`, `detectionMethod`, `percent.color`, `paddingLeft`, `symbol`) exists in the 2.40.4 JSON schema; `percent.color` exists since <= 2.20.0 |
| chafa              | non-kitty logo (`ryoku-fastfetch:20-21`) | chafa (pulls libchafa) | 1.14.5 | -          | 1.18.2 | 1.18.2 | 1.18.1   | any; Debian builds fastfetch with `libchafa-dev` (`debian/control` 2.40.4)                                                                                                       |

**As-is on Debian:** YES.

**Port steps:**

1. Install `fastfetch chafa`.
2. Edit `config.jsonc:25` "a hand-built Arch desktop" -> the Debian wording
   (string only).

**Complexity:** Low.

**Issues / risks:** fastfetch's `packages` module counts dpkg + flatpak on
Debian instead of pacman (cosmetic).

---

### btop (`ryoku/apps/btop/btop.conf`)

**What it does:** `color_theme = "ryoku"`, `theme_background = False`,
`truecolor = True`, `vim_keys = True` (`ryoku/apps/btop/btop.conf:4-11`); the
theme is rendered by matugen to `~/.config/btop/themes/ryoku.theme`
(`ryoku/shell/matugen/config.toml:20-21`).

**Arch couplings:** none. Header comment says btop 1.4 (`btop.conf:1`).

**Dependencies:** btop: trixie 1.3.2, forky 1.4.7, sid 1.4.7, resolute 1.4.6.
All four keys exist in 1.3.x.

**As-is on Debian:** YES.

**Port steps:** install `btop`.

**Complexity:** Low.

---

### ghostty (`ryoku/apps/ghostty`)

**What it does:** user-owned seed that includes the matugen palette
`ryoku-colors` and optional `?user.conf` (`ryoku/apps/ghostty/config:9-12`,
`ryoku/apps/ghostty/ryoku-colors:4-25`). Seeded once (`materialize.go:45-46`),
migrated by `reconcileGhostty`
(`ryoku/cli/internal/doctor/reconcile_ghostty.go:14-110`). Ghostty is not
preinstalled (absent from every `system/packages/*.packages`); it is one choice
in the Hub terminal picker (`ryoku/hub/backend/apps.go:43`).

**Arch couplings:** none.

**Dependencies:** ghostty: Debian trixie/forky/sid none; resolute 1.3.0~us1;
Arch 1.3.1. Minimum: 1.0.0 (`config-file = ?path` optional prefix is parsed in
v1.0.0 `src/config/Config.zig:4134`).

**As-is on Debian:** NO package on Debian; config is inert until ghostty is
installed. resolute: YES.

**Port steps (Debian):**

1. Build ghostty v1.3.1 from source: requires zig >= 0.15.2 (`build.zig.zon:6`
   at v1.3.1); Debian has no zig package (resolute: `zig0.15` 0.15.2~us1). Use
   the upstream zig tarball
   `https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz`.
2. Build deps:
   `libgtk-4-dev libadwaita-1-dev gettext libxml2-utils blueprint-compiler pkg-config`.
   `zig build -Doptimize=ReleaseFast -Dcpu=baseline --prefix /usr` then package
   `DESTDIR` output.

**Complexity:** Medium (optional app; skip unless the terminal picker must offer
it).

---

### Neovim / LazyVim (`ryoku/apps/nvim`)

**What it does:** LazyVim starter: leaders (`ryoku/apps/nvim/init.lua:2-5`),
lazy.nvim bootstrap by `git clone --filter=blob:none --branch=stable`
(`ryoku/apps/nvim/lua/config/lazy.lua:1-24`), `LazyVim/LazyVim` + local plugins,
colorscheme tokyonight/habamax, checker on (`lazy.lua:26-53`), options incl.
`smoothscroll` (`lua/config/options.lua:11`), yank highlight via
`vim.highlight.on_yank` (`lua/config/autocmds.lua:4`), palette-following
tokyonight from `~/.cache/ryoku/colors.json` (`lua/plugins/ryoku.lua:7-77`),
snacks dashboard header (`lua/plugins/ryoku-dashboard.lua:1-40`).
`ryoku-nvim.desktop` runs `kitty -e nvim %F` with `Icon=nvim`
(`ryoku/apps/nvim/ryoku-nvim.desktop:6-8`). The tree is seeded once
(`materialize.go:59-65`).

**Arch couplings:** none in the files.

**Dependencies:**

| Arch pkg                        | Used for (cite)                                                                             | Debian/Ubuntu pkg                    | trixie                                     | trixie-bpo | forky                             | sid     | resolute                          | Min version Ryoku needs                                                  |
| ------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------ | ---------- | --------------------------------- | ------- | --------------------------------- | ------------------------------------------------------------------------ |
| neovim (0.12.6)                 | editor (`base.packages:249`)                                                                | neovim                               | 0.10.4                                     | -          | 0.12.4                            | 0.12.4  | 0.11.6                            | 0.11.2 (LazyVim v16.0.1 README "Neovim >= 0.11.2", built with LuaJIT)    |
| (git)                           | lazy.nvim bootstrap (`lazy.lua:5-12`)                                                       | git                                  | 2.47.3                                     | -          | 2.53.0                            | 2.55.0  | 2.53.0                            | 2.19.0 (LazyVim README)                                                  |
| (gcc)                           | nvim-treesitter parser builds                                                               | build-essential                      | 12.12                                      | -          | 12.12                             | 12.12   | 12.12                             | any C compiler                                                           |
| tree-sitter-cli                 | nvim-treesitter `main` (LazyVim tracks it on nvim >= 0.12, pins commit `7caec27` on < 0.12) | tree-sitter-cli                      | 0.22.6                                     | -          | 0.26.11                           | 0.26.11 | 0.25.9                            | 0.26.1 (nvim-treesitter README, also at the pinned commit)               |
| ripgrep, fd, lazygit, fzf, curl | LazyVim/snacks pickers, lazygit integration                                                 | ripgrep, fd-find, lazygit, fzf, curl | 14.1.1 / 10.2.0 / 0.50.0 / 0.60.3 / 8.14.1 |            | 15.2.0 / 10.5.0 / 0.57.0 / 0.74.4 |         | 15.1.0 / 10.3.0 / 0.57.0 / 0.67.0 | any; snacks picker accepts `fdfind` (`snacks/picker/source/files.lua:8`) |

**As-is on Debian:** NO on trixie (0.10.4 < 0.11.2); YES on forky/sid/resolute.

**Port steps (trixie):**

1. Package upstream Neovim >= 0.11.2: either repackage the release tarball
   `https://github.com/neovim/neovim/releases/download/v0.12.x/nvim-linux-x86_64.tar.gz`
   into `/usr` as a deb named `neovim` with `Provides: neovim, neovim-runtime`
   and `Conflicts/Replaces: neovim, neovim-runtime`, or build:
   `apt build-dep`-equivalent deps
   `cmake ninja-build gettext curl build-essential unzip`, then
   `make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=/usr && make install DESTDIR=...`.
2. With nvim 0.12 on trixie, also package tree-sitter-cli >= 0.26.1 (upstream
   binary `tree-sitter-linux-x64.gz` from
   `https://github.com/tree-sitter/tree-sitter/releases`), since trixie's is
   0.22.6.
3. Icon: Debian's `neovim-runtime` ships
   `/usr/share/icons/hicolor/128x128/apps/nvim.png`, so `Icon=nvim` resolves; a
   repackaged upstream tarball must ship the icon too.

**Complexity:** Medium (trixie only).

**Issues / risks:**

- resolute (0.11.6) runs LazyVim on the pinned nvim-treesitter commit; its
  README states tree-sitter-cli >= 0.26.1 and resolute has 0.25.9. Parser builds
  on resolute need a newer tree-sitter-cli (not validated here).
- `vim.highlight` is deprecated since 0.11 (`runtime/doc/deprecated.txt` v0.12.0
  line 111), still present in 0.12; `autocmds.lua:4` will break on the release
  that removes it.
- First launch clones from GitHub (`lazy.lua:4-12`); offline installs get an
  error screen, same as Arch.

---

### yazi (`ryoku/apps/yazi/yazi.toml`)

**What it does:** `[mgr] show_hidden`, an `edit` opener running `nvim` with
`block = true`, `[open] prepend_rules` using `mime` and `url` matchers
(`ryoku/apps/yazi/yazi.toml:7-27`). The matugen yazi theme template also uses
`[mgr]` and `url` filetype rules
(`ryoku/shell/matugen/templates/yazi.toml:6,82-91`).

**Arch couplings:** comment mentions "slim Arch+Ryoku box" (`yazi.toml:4`), no
code coupling.

**Dependencies:**

| Arch pkg                                                     | Used for (cite)                               | Debian/Ubuntu pkg                                                            | trixie                | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                                                                                                                 |
| ------------------------------------------------------------ | --------------------------------------------- | ---------------------------------------------------------------------------- | --------------------- | ---------- | ------ | ------ | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| yazi (26.9.1)                                                | file manager (`base.packages:270`)            | none                                                                         | -                     | -          | -      | -      | -        | 25.12.29: `url =` in open/filetype rules first appears in the v25.12.29 preset (v25.5.31 still uses `name =`); `[mgr]` needs >= 25.5.28 |
| (rustc/cargo to build)                                       | yazi MSRV 1.95.0 (`Cargo.toml:13` at v26.9.1) | rustc, cargo                                                                 | 1.85.1                | 1.96.1     | 1.96.1 | 1.97.1 | 1.93.1   | 1.95.0                                                                                                                                  |
| fd, rg, 7zip, ffmpeg, poppler, chafa, imagemagick, resvg, jq | yazi previewers/search                        | fd-find, ripgrep, 7zip, ffmpeg, poppler-utils, chafa, imagemagick, resvg, jq | all present in trixie |            |        |        |          | any                                                                                                                                     |

**As-is on Debian:** NO (no package in any suite).

**Port steps:**

1. Easiest: repackage upstream's own deb `yazi-x86_64-unknown-linux-gnu.deb`
   from `https://github.com/sxyazi/yazi/releases/tag/v26.9.1` (upstream
   publishes gnu and musl `.deb` assets).
2. Or build: rustc >= 1.95 (trixie-bpo/forky/sid; resolute 1.93 is too old, use
   rustup), `cargo build --release --locked -p yazi-fm -p yazi-cli`, install
   `target/release/{yazi,ya}` to `/usr/bin`.
3. Recommends:
   `ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick chafa resvg`.

**Complexity:** Low.

**Issues / risks:** yazi's built-in search calls `fd`; on Debian that is
`fdfind` unless the fd shim (fish step 1) is shipped.

---

### Nautilus extension (`ryoku/apps/nautilus`)

**What it does:** `nautilus-python` MenuProvider adding "Install with Ryoku" /
"Compress with Ryoku" that run `~/.config/hypr/scripts/stash-install.sh` /
`stash-compress.sh` (`ryoku/apps/nautilus/ryoku-stash-menu.py:5,23-25,61-100`).
Installed system-wide (`PKGBUILD:560-561`).

**Arch couplings:**

- Helper path is under `~/.config/hypr/scripts` (`ryoku-stash-menu.py:25`), the
  Hyprland config dir name.
- The install action's target `stash-install.sh` routes `.pkg.tar.*` to
  `pkexec pacman -U` and `.deb` to a payload extract into `~/.local`
  (`ryoku/shell/scripts/stash-install.sh:40-50,303-350`).

**Dependencies:**

| Arch pkg        | Used for (cite)                        | Debian/Ubuntu pkg                                                       | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                                   |
| --------------- | -------------------------------------- | ----------------------------------------------------------------------- | ------ | ---------- | ------ | ------ | -------- | --------------------------------------------------------- |
| nautilus (51.1) | file manager (`base.packages:168`)     | nautilus                                                                | 48.3   | -          | 51.0.1 | 51.0.1 | 50.2.2   | 43 (nautilus-python 4 API: `get_file_items(self, files)`) |
| nautilus-python | extension loader (`base.packages:170`) | python3-nautilus                                                        | 4.0.1  | -          | 4.1.0  | 4.1.0  | 4.1.0    | 4.0                                                       |
| (gir)           | `from gi.repository import Nautilus`   | gir1.2-nautilus-4.0 (trixie) / gir1.2-nautilus-4.1 (forky/sid/resolute) | 48.3   | -          | 51.0.1 | 51.0.1 | 50.2.2   |                                                           |

**As-is on Debian:** YES. nautilus-python searches
`$XDG_DATA_DIRS/nautilus-python/extensions` (upstream README "Running
Extensions"), so `/usr/share/nautilus-python/extensions/` works unchanged.

**Port steps:** install `nautilus python3-nautilus`; ship the `.py` at the same
path.

**Complexity:** Low.

**Issues / risks:** On Debian, "Install with Ryoku" on a `.deb` extracts the
payload into `~/.local` instead of `apt install`; owned by the shell scripts'
port (`stash-install.sh`).

---

### npm rc (`ryoku/apps/npm/npmrc`)

**What it does:** `prefix=${HOME}/.local` so `npm i -g` works without root
(`ryoku/apps/npm/npmrc:5`). Seeded to `~/.npmrc` by the installers only if
absent (`installation/backend/lib/deploy.sh:307`,
`ryoku-shell-installer/engine.go:1289`).

**Arch couplings:** none.

**Dependencies:** npm: trixie 9.2.0, forky 12.2.0, sid 12.2.0, resolute 9.2.0;
nodejs: trixie 20.19.2, forky 24.21.0, sid 24.22.0, resolute 22.22.1. npm
expands `${HOME}` in npmrc in all of these.

**As-is on Debian:** YES.

**Port steps:** none beyond installing `nodejs npm`.

**Complexity:** Low.

---

### pip.conf (`ryoku/apps/pip/pip.conf`)

**What it does:** `[global] break-system-packages = true` so
`pip install --user` works under PEP 668 (`ryoku/apps/pip/pip.conf:5-6`), laid
at `~/.config/pip/pip.conf` (`PKGBUILD:412`).

**Arch couplings:** comment says "pacman-owned" (`pip.conf:4`), no code
coupling.

**Dependencies:** python3-pip: trixie 25.1.1, forky 26.1.2, sid 26.1.2, resolute
25.1.1 (option exists since pip 23.0.1). Debian/Ubuntu ship
`/usr/lib/python3.*/EXTERNALLY-MANAGED`, so the setting has the same effect.

**As-is on Debian:** YES.

**Port steps:** install `python3-pip pipx`.

**Complexity:** Low.

---

### WirePlumber Bluetooth policy (`ryoku/apps/wireplumber`)

**What it does:** WirePlumber 0.5 SPA-JSON drop-in: SBC-XQ, mSBC, hw volume,
codec order `[ ldac aptx_hd aptx sbc_xq aac sbc ]`, native HFP backend
(`ryoku/apps/wireplumber/wireplumber.conf.d/51-ryoku-bluetooth.conf:20-26`) and
`bluetooth.autoswitch-to-headset-profile = true`
(`51-ryoku-bluetooth.conf:41-43`). Materialized; only `NN-ryoku-*.conf` drop-ins
are converged (`materialize.go:19-25`).

**Arch couplings:** none in syntax. Codec availability differs:

- Debian's pipewire is built with `-Dbluez5-codec-aac=disabled` (salsa
  `utopia-team/pipewire` `debian/rules:68`), aptx/ldac/lc3/opus enabled; Ubuntu
  resolute builds `-Dbluez5-codec-aac=enabled`; Arch links libfdk-aac.

**Dependencies:**

| Arch pkg                          | Used for (cite)             | Debian/Ubuntu pkg    | trixie | trixie-bpo | forky  | sid    | resolute | Min version Ryoku needs                 |
| --------------------------------- | --------------------------- | -------------------- | ------ | ---------- | ------ | ------ | -------- | --------------------------------------- |
| wireplumber                       | policy (`base.packages:69`) | wireplumber          | 0.5.8  | 0.5.12     | 0.5.18 | 0.5.18 | 0.5.13   | 0.5.0 (SPA-JSON `wireplumber.settings`) |
| pipewire-audio (bluez SPA plugin) | codecs                      | libspa-0.2-bluetooth | 1.4.2  | 1.6.9      | 1.6.9  | 1.6.9  | 1.6.2    | any 1.x                                 |

**As-is on Debian:** PARTIAL on Debian (the `aac` entry is a no-op; AAC-only
devices fall to `sbc_xq`/`sbc`); YES on resolute.

**Port steps:**

1. Install `wireplumber pipewire-audio libspa-0.2-bluetooth`.
2. AAC on Debian requires rebuilding `pipewire` with
   `-Dbluez5-codec-aac=enabled` against `libfdk-aac-dev` (Debian `non-free`):
   rebuild source `pipewire` with that one flag flipped and `libfdk-aac-dev`
   added to Build-Depends.

**Complexity:** Low (without AAC), Medium (with AAC rebuild).

**Questions for the human:**

- AAC on Debian: (a) accept no AAC (AirPods-class devices use SBC-XQ/SBC; the
  per-device codec override in Settings has nothing to select); (b) carry a
  rebuilt `pipewire` with fdk-aac from non-free in the Ryoku repo (exact Arch
  behaviour, a forked core audio package to track every pipewire update).

---

### mimeapps.list (`ryoku/apps/mimeapps.list`)

**What it does:** vendor-layer default handlers: text/code types ->
`ryoku-nvim.desktop`, common video/audio -> `mpv.desktop`
(`ryoku/apps/mimeapps.list:1-31`). Installed to
`/usr/share/applications/mimeapps.list` (`PKGBUILD:434-435`).

**Arch couplings:** none.

**Desktop IDs checked against Debian file lists:**

| ID in file           | Debian provider                                   | Present |
| -------------------- | ------------------------------------------------- | ------- |
| `ryoku-nvim.desktop` | Ryoku (`PKGBUILD:415`)                            | yes     |
| `mpv.desktop`        | `mpv` ships `/usr/share/applications/mpv.desktop` | yes     |

No other IDs appear in the file (no Nautilus, Chromium or Firefox entries). No
Debian package owns `/usr/share/applications/mimeapps.list` (contents search,
sid, all sections: no hits), so no dpkg file conflict.

**As-is on Debian:** YES.

**Port steps:** install `mpv`; ship the file at the same path.

**Complexity:** Low.

---

### chromium-flags.conf (`ryoku/apps/chromium-flags.conf`)

**What it does:** `--password-store=gnome-libsecret` and
`--ozone-platform=wayland` (`ryoku/apps/chromium-flags.conf:1,6`), laid as
`~/.config/chromium-flags.conf` and `~/.config/chrome-flags.conf`
(`PKGBUILD:440-441`).

**Arch couplings:**

- `~/.config/chromium-flags.conf` is read by Arch's chromium launcher. Debian's
  `/usr/bin/chromium` wrapper resets `CHROMIUM_FLAGS=""` and only sources
  `/etc/chromium.d/*` (salsa `chromium-team/chromium`
  `debian/scripts/chromium:13,76-78`); the user file is ignored.
- `~/.config/chrome-flags.conf` is an Arch AUR google-chrome launcher feature;
  Google's own deb wrapper was not read in this pass.
- Ubuntu resolute has no chromium deb: `chromium-browser` is a transitional
  package to the snap (`2:1snap1-0ubuntu4`).

**Dependencies:** chromium: trixie 150.0.7871.181, forky 154.0.8037.92, sid
155.0.8059.79, resolute none (snap only).

**As-is on Debian:** NO (flags silently not applied).

**Port steps:**

1. Ship `/etc/chromium.d/ryoku` in a Ryoku deb:

   ```sh
   export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --password-store=gnome-libsecret --ozone-platform=wayland"
   ```

2. Stop laying `chromium-flags.conf` on Debian or keep it (harmless).

**Complexity:** Low.

**Issues / risks:** Debian's wrapper adds
`--disable-extensions-except=<--load-extension list>` unless
`--enable-remote-extensions` is set (`debian/scripts/chromium:121-124`);
Debian's own `/etc/chromium.d/extensions` sets `--enable-remote-extensions`, so
web-store extensions and the Ryoku browser theme work as long as that file
stays.

**Questions for the human:**

- Browser on resolute: (a) chromium snap (flags and native-messaging host paths
  for the Ryoku theme extension live inside snap confinement); (b) a non-snap
  chromium build/PPA; (c) a different default browser.

---

### hyprland-preview-share-picker config (`ryoku/apps/hyprland-preview-share-picker/config.yaml`)

**What it does:** stylesheet `../../.cache/ryoku/share-picker.css`,
`default_page: outputs`, `hide_token_restore: true`, `image.resize_size: 320`,
single-click windows/outputs, output labels
(`ryoku/apps/hyprland-preview-share-picker/config.yaml:7-25`). Shipped by the
Hyprland variant (`release/packages/ryoku-desktop-hyprland/PKGBUILD:65-66`).

**Arch couplings:** none. All keys are documented in the upstream README at the
commit Ryoku builds (`e2f30ff85486e557018523da45ccbc846e3a499c`,
`release/packages/hyprland-preview-share-picker/PKGBUILD:5`).

**As-is on Debian:** YES for the file; the picker binary is not packaged in
Debian (built in the compositor section: cargo, `gtk4` crate feature `v4_8`,
`gtk4-layer-shell` crate 0.4.0; Debian `libgtk-4-dev` 4.18.6 and
`libgtk4-layer-shell-dev` 1.0.4 in trixie).

**Port steps:** ship the file at
`/usr/share/ryoku/config/hyprland-preview-share-picker/config.yaml`.

**Complexity:** Low.

---

### tools launchers (`ryoku/apps/tools`)

**What it does:** "Install app" runs `ryoku-shell install`, "Compress video"
runs `ryoku-shell compress` (`ryoku/apps/tools/install-app.desktop:6`,
`ryoku/apps/tools/compress-video.desktop:6`), installed to
`/usr/share/applications` (`PKGBUILD:419-422`).

**Arch couplings:** `Keywords=` includes `pacman` (`install-app.desktop:10`,
cosmetic). The install path ends in `stash-install.sh` (pacman for `.pkg.tar.*`,
payload extract for `.deb`, `stash-install.sh:40-50`).

**As-is on Debian:** PARTIAL (AppImage, tarball, Flatpak paths work; native
package path is pacman).

**Port steps:** none in these files; the `.deb` branch of `stash-install.sh`
becomes `pkexec apt-get install -y ./file.deb` (shell scripts' port).
`ryoku-shell compress` needs `ffmpeg`.

**Complexity:** Low.

---

### RyoStore (`ryoku/apps/ryostore`)

**What it does:** Quickshell app (`qs -c ryostore`, single-instance via flock,
`ryoku/apps/ryostore/ryostore.desktop:6`) over a Go backend `ryostore` (module
`ryostore`, `ryoku/apps/ryostore/backend/go.mod:1-3`). Catalogue from
`https://raw.githubusercontent.com/ryoku-dev/ryostore/main`
(`backend/paths.go:16`). Providers: themes, decor, locks, rices, bars,
fastfetch, plugins, bundles. Calls `ryoku wm status`
(`backend/window_manager.go:26`), `ryoku version` (`backend/paths.go:85`),
`ryoku-plugins-place` (`backend/provider_plugins.go:93`,
`backend/extras_assets.go:329-334`), `ryoku-shell barstyle`
(`backend/provider_bars.go:36`), `flock ... qs -c` (`backend/routing.go:60-68`),
and runs bundle installs as
`kitty --class ryostore -e ryostore-install install bundle <id>`
(`backend/provider_bundles.go:205-220`) with status from
`ryostore-install status` (`backend/provider_bundles.go:179`). QML imports:
QtQuick, QtQuick.Controls, QtQuick.Effects, Quickshell, Quickshell.Io, Ryoku.Ui
(grep of `ryostore/quickshell`).

**Arch couplings:**

- Bundle actuator `system/extras/ryostore-install` is pacman/AUR: `pacman -Qq`,
  `pacman -Si`, `ryoku-pkg-add`/`ryoku-pkg-aur-add`/`ryoku-pkg-remove`, multilib
  and CachyOS enablers
  (`system/extras/ryostore-install:85-100,250-258,283-349,462-479`).
- The live remote bundle registry (`bundles/registry.json` on ryoku-dev/ryostore
  main, fetched 2026-10-17) lists Arch package names: `steam`, `lib32-vkd3d`,
  `lib32-gamemode`, `heroic-games-launcher-bin`, `vesktop-bin`, `rpcs3-bin`,
  `obs-vkcapture`, `v4l2loopback-dkms`, `linux-headers`, `losslesscut-bin`,
  `base-devel`, `github-cli`, `fd`, `rustup`, `jdk-openjdk`,
  `visual-studio-code-bin`, `firefox-developer-edition`, `brave-bin`,
  `zen-browser-bin`, `mullvad-vpn-bin`, `cloudflare-warp-bin`, `linux-cachyos`,
  `cachyos-settings`, `scx-scheds`, `proton-cachyos-native`, `pipes.sh`,
  `ryotunes`, among others (11 bundles).
- `go 1.26` (`backend/go.mod:3`).

**Dependencies:**

| Arch pkg         | Used for (cite)                                     | Debian/Ubuntu pkg                                                                                             | trixie          | trixie-bpo                | forky  | sid    | resolute | Min version Ryoku needs |
| ---------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------- | ------------------------- | ------ | ------ | -------- | ----------------------- |
| go               | build backend (`PKGBUILD:19,300-306`)               | golang-go / golang-1.26                                                                                       | 1.24            | 1.27 (golang-1.26 1.26.9) | 1.27   | 1.27   | 1.26     | 1.26 (`go.mod:3`)       |
| quickshell       | runtime (`PKGBUILD:87`)                             | quickshell                                                                                                    | -               | 0.3.0                     | 0.3.2  | 0.3.2  | -        | per shell section       |
| qt6-declarative  | QtQuick/Controls/Effects                            | qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-effects, qml6-module-qtquick-templates | 6.8.2           | -                         | 6.11.2 | 6.11.2 | 6.10.2   | per shell section       |
| qt6-imageformats | WebP previews (`PKGBUILD:44-49`)                    | qt6-image-formats-plugins                                                                                     | (shell section) |                           |        |        |          |                         |
| util-linux       | `flock`                                             | util-linux                                                                                                    | base            |                           |        |        |          | any                     |
| kitty            | bundle install terminal (`provider_bundles.go:214`) | kitty                                                                                                         | 0.41.1          | -                         | 0.48.2 | 0.48.2 | 0.45.0   | any                     |

**As-is on Debian:** PARTIAL: browsing and content installs (themes, rices,
locks, plugins, fastfetch layouts) are file operations and work; bundles do not
(pacman actuator + Arch package names).

**Port steps:**

1. Build with Go >= 1.26: trixie-bpo `golang-1.26` (or `golang-go` 1.27),
   forky/sid `golang-go`, resolute `golang-go` 1.26. Debian's `go.env` sets
   `GOTOOLCHAIN=auto` (golang-1.24 `go.env`), so building with trixie's 1.24
   silently downloads go1.26 from proxy.golang.org; set `GOTOOLCHAIN=local` in
   `debian/rules` so a too-old toolchain fails instead.
2. Rewrite `ryostore-install` (system/extras section) on apt: `pkg_installed` ->
   `dpkg-query -W`, `pkg_official` ->
   `apt-cache policy <pkg> | grep -q Candidate:` with a non-`(none)` candidate,
   the AUR branch -> unsupported or a per-item recipe.
3. Bundles need a Debian name map. Either add a `debian` name field to each
   component in the upstream `ryoku-dev/ryostore` registry (out-of-repo change),
   or keep a local map in `ryostore-install` (e.g. `github-cli`->`gh`,
   `fd`->`fd-find`, `base-devel`->`build-essential`,
   `jdk-openjdk`->`default-jdk`, `python-pip`->`python3-pip`, `lib32-*`->`:i386`
   multiarch names) and mark `-bin`/AUR/CachyOS items unavailable.

**Complexity:** High (registry content is Arch-shaped and lives outside the
repo).

**Questions for the human:**

- Bundle catalogue on Debian: (a) hide the Bundles tab on Debian; (b) map names
  locally and drop items with no Debian equivalent (CachyOS layer, most `-bin`
  items); (c) publish a Debian-specific registry in ryoku-dev/ryostore (a second
  catalogue to maintain).

---

### Ryoport / ryovm (`ryoku/apps/ryovm`)

**What it does:** Quickshell app (`qs -c ryovm`,
`ryoku/apps/ryovm/ryovm.desktop:6`) over `bin/ryovm` (1474-line bash engine
wrapping quickemu/quickget), `bin/ryoport` alias, Go helpers `ryovm-fetch`
(downloads), `ryovm-mon` (live VM control over quickemu sockets), `ryossh`
(remotes) (`ryovm/fetch/go.mod:1`, `ryovm/mon/go.mod:1`,
`ryovm/remote/go.mod:1`). Capabilities probe checks `quickemu`, `quickget`,
`qemu-system-x86_64`, readable `/dev/kvm`, `spicy` or `remote-viewer`
(`ryoku/apps/ryovm/bin/ryovm:124-138`). Uses `quickget --list-json`, `--url`,
`--create-config` (`bin/ryovm:165,299,310`),
`quickemu --status-quo/--kill/--delete-disk/--delete-vm` (`bin/ryovm:880-1101`),
`qemu-img convert` (`bin/ryovm:812`), python3 for the QMP powerdown
(`bin/ryovm:986-987`), genisoimage/xorriso/mkisofs for cloud-init seeds
(`bin/ryovm:691-706`), curl. Passthrough lane delegates to `ryoku-hub gpu vm`
(`bin/ryovm:1419-1436`). `ryossh` shells out to `ssh`, `ssh-add`, `ssh-keygen`,
`ssh-copy-id`, `secret-tool`, and `kitten ssh` when the terminal is kitty
(`ryovm/remote/ryossh.go:268,575,924-967,1009-1176`). QML uses `zenity` file
picker and `wl-copy`, `xdg-open`, `nautilus sftp://`
(`ryovm/quickshell/IsoPanel.qml:178`,
`ryovm/quickshell/Singletons/Vm.qml:228,718`,
`ryovm/quickshell/Singletons/Remotes.qml:191-194`).

**Arch couplings:**

- `cmd_setup`:
  `ryoku-pkg-add --needed spice-gtk libisoburn || sudo pacman -S --needed --noconfirm spice-gtk libisoburn`,
  then quickemu via `ryoku-pkg-aur-add`, `yay` or `paru` (`bin/ryovm:139-157`);
  comment "quickemu is AUR-only" (`bin/ryovm:141`). Debian ships quickemu in
  main.
- Error text "install xorriso: sudo pacman -S libisoburn" (`bin/ryovm:722`).
- Windows VMs force `secureboot="off"` because "Arch's edk2 has no MS-key vars"
  (`bin/ryovm:400-409`); Debian's `ovmf` ships MS-key vars
  (`OVMF_VARS_4M.ms.fd`), behaviour unchanged if left off.
- OVMF paths are not hardcoded by Ryoku; quickemu 4.9.7 probes
  `${SHARE_PATH}/OVMF/OVMF_CODE_4M.secboot.fd` and others itself (`quickemu`
  4.9.7 lines 666-669).
- `go 1.26` in all three helper modules.

**Dependencies:**

| Arch pkg             | Used for (cite)                          | Debian/Ubuntu pkg                            | trixie  | trixie-bpo    | forky    | sid       | resolute | Min version Ryoku needs                                                                                                                                  |
| -------------------- | ---------------------------------------- | -------------------------------------------- | ------- | ------------- | -------- | --------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| quickemu (AUR 4.9.9) | VM engine (`PKGBUILD:240`)               | quickemu                                     | 4.9.7   | -             | 4.9.9    | 4.9.9     | 4.9.7    | 4.9.7: `--list-json`, `--url`, `--create-config`, `--status-quo`, `extra_args`, `preallocation`, `--delete-disk/--delete-vm/--kill` all present in 4.9.7 |
| qemu-desktop         | `qemu-system-x86_64` (`bin/ryovm:128`)   | qemu-system-x86, qemu-system-gui, qemu-utils | 10.0.13 | 11.0.2        | 11.1.2   | 11.1.2    | 10.2.1   | any quickemu-supported                                                                                                                                   |
| edk2-ovmf            | UEFI (`base.packages:177`)               | ovmf                                         | 2025.02 | -             | 2026.08  | 2026.08   | 2025.11  | any                                                                                                                                                      |
| spice-gtk            | `spicy` (`bin/ryovm:962-967`)            | spice-client-gtk (ships `/usr/bin/spicy`)    | 0.42    | -             | 0.42     | 0.42      | 0.42     | any                                                                                                                                                      |
| (virt-viewer)        | `remote-viewer` fallback                 | virt-viewer                                  | 11.0    | -             | 11.0     | 11.0      | 11.0     | any                                                                                                                                                      |
| libisoburn           | `xorriso` seed ISO (`bin/ryovm:698-699`) | xorriso (or genisoimage, tried first)        | 1.5.6   | -             | 1.5.8    | 1.5.8     | 1.5.6    | any                                                                                                                                                      |
| swtpm                | Windows 11 TPM (`PKGBUILD:238`)          | swtpm, swtpm-tools                           | 0.7.1   | -             | 0.10.2   | 0.10.2    | 0.10.1   | any                                                                                                                                                      |
| libsecret            | `secret-tool` (`ryossh.go:967-1010`)     | libsecret-tools                              | 0.21.7  | -             | 0.21.8.2 | 0.21.8.2  | 0.21.7   | any                                                                                                                                                      |
| openssh              | ssh, ssh-copy-id, ssh-keygen             | openssh-client                               | 10.0p1  | 10.3p1        | 10.6p1   | 10.6p1    | 10.2p1   | any                                                                                                                                                      |
| looking-glass        | passthrough client (`PKGBUILD:239`)      | looking-glass-client                         | -       | -             | -        | B7 (0+b7) | -        | Hub/GPU section                                                                                                                                          |
| python               | QMP powerdown (`bin/ryovm:986`)          | python3                                      | 3.13.5  | -             | 3.14.7   | 3.14.7    | 3.14.3   | 3                                                                                                                                                        |
| zenity               | ISO picker (`IsoPanel.qml:178`)          | zenity                                       | present |               |          |           |          | any                                                                                                                                                      |
| go                   | helpers                                  | golang-1.26 / golang-go                      | 1.24    | 1.26.9 / 1.27 | 1.27     | 1.27      | 1.26     | 1.26                                                                                                                                                     |

**As-is on Debian:** PARTIAL: everything except `ryovm setup` works once the
packages are installed; `/dev/kvm` on Debian is `root:kvm 0660` with a `uaccess`
tag (`/usr/lib/udev/rules.d/50-udev-default.rules:111`, `70-uaccess.rules:50`),
so the seat user can read it as on Arch.

**Port steps:**

1. Replace `bin/ryovm:139-157` with an apt path:
   `ryoku-pkg-add quickemu spice-client-gtk xorriso` (once `ryoku-pkg-add` is
   the apt wrapper) or
   `pkexec apt-get install -y quickemu spice-client-gtk xorriso`; drop the AUR
   branch.
2. Change the error string `bin/ryovm:722` to `sudo apt install xorriso`.
3. Build the three helpers with Go >= 1.26 and `GOTOOLCHAIN=local` (see RyoStore
   step 1).
4. Recommends for the deb:
   `quickemu qemu-system-x86 qemu-system-gui qemu-utils ovmf swtpm swtpm-tools spice-client-gtk virt-viewer xorriso genisoimage libsecret-tools openssh-client zenity python3 jq curl`.

**Complexity:** Medium.

**Issues / risks:** Looking Glass client exists only in sid (no
trixie/forky/resolute) and the kvmfr module is not packaged; owned by the Hub
GPU-passthrough section.

---

### preinstalled.md inventory (`docs/preinstalled.md`)

**What it does:** human-readable list of what lands on a box; the source of
truth is `system/packages/*.packages` and the umbrella PKGBUILD
(`docs/preinstalled.md:33-35`).

**Doc vs code discrepancies:**

- Lists `ryostore`, `ryowalls`, `ryovm` as packages
  (`docs/preinstalled.md:53-55`); there are no such packages: `ryostore` and
  `ryovm` are built inside `ryoku-desktop` by the app loop (`PKGBUILD:283-320`,
  no `release/packages/ryostore` or `ryovm` dir), and ryowalls "was sunset"
  (`ryoku/apps/README.md:49`).

**Debian mapping (apps, CLI, runtime helpers, toolchains, fonts;
core/boot/network/graphics are listed for completeness, owned by other
sections):**

| Arch (preinstalled.md line)                                                     | Debian/Ubuntu name                                                                                                                      | trixie                                   | trixie-bpo          | forky                                      | sid                       | resolute                                      |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- | ------------------- | ------------------------------------------ | ------------------------- | --------------------------------------------- |
| chromium (132)                                                                  | chromium                                                                                                                                | 150.0.7871.181                           | -                   | 154.0.8037.92                              | 155.0.8059.79             | snap only                                     |
| kitty (133)                                                                     | kitty                                                                                                                                   | 0.41.1                                   | -                   | 0.48.2                                     | 0.48.2                    | 0.45.0                                        |
| mpv, mpv-mpris (134)                                                            | mpv, mpv-mpris                                                                                                                          | 0.40.0, 0.7.1                            | -, 1.2              | 0.41.0, 1.3                                | 0.41.0, 1.3               | 0.41.0, 1.2                                   |
| nautilus, nautilus-python (135)                                                 | nautilus, python3-nautilus                                                                                                              | 48.3, 4.0.1                              | -                   | 51.0.1, 4.1.0                              | 51.0.1, 4.1.0             | 50.2.2, 4.1.0                                 |
| fish (150)                                                                      | fish                                                                                                                                    | 4.0.2                                    | -                   | 4.9.3                                      | 4.9.3                     | 4.2.1                                         |
| bash, zsh (151)                                                                 | bash, zsh                                                                                                                               | base, 5.9                                | -                   | 5.9.2                                      | 5.9.2                     | 5.9                                           |
| blesh (152)                                                                     | ble.sh                                                                                                                                  | -                                        | -                   | 0.4.0~git20250806                          | same                      | same                                          |
| zsh-autosuggestions, -syntax-highlighting (153)                                 | same names                                                                                                                              | 0.7.1, 0.8.0                             | -                   | 0.7.1, 0.8.0                               | same                      | same                                          |
| zsh-history-substring-search (153)                                              | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| starship (154)                                                                  | starship                                                                                                                                | 1.22.1                                   | -                   | 1.26.0                                     | 1.26.0                    | 1.22.1                                        |
| bash-completion (155)                                                           | bash-completion                                                                                                                         | 2.16.0                                   | -                   | 2.16.0                                     | 2.16.0                    | 2.16.0                                        |
| bat (156)                                                                       | bat (binary `batcat`)                                                                                                                   | 0.25.0                                   | -                   | 0.26.1                                     | 0.26.1                    | 0.25.0                                        |
| eza (157)                                                                       | eza                                                                                                                                     | 0.21.0                                   | -                   | 0.23.5                                     | 0.23.5                    | 0.23.4                                        |
| fd (158)                                                                        | fd-find (binary `fdfind`, also `/usr/lib/cargo/bin/fd`)                                                                                 | 10.2.0                                   | -                   | 10.5.0                                     | 10.5.0                    | 10.3.0                                        |
| fzf (159)                                                                       | fzf                                                                                                                                     | 0.60.3                                   | -                   | 0.74.4                                     | 0.74.4                    | 0.67.0                                        |
| ripgrep (160)                                                                   | ripgrep                                                                                                                                 | 14.1.1                                   | -                   | 15.2.0                                     | 15.2.0                    | 15.1.0                                        |
| zoxide (161)                                                                    | zoxide                                                                                                                                  | 0.9.7                                    | -                   | 0.10.0                                     | 0.10.0                    | 0.9.8                                         |
| fastfetch (162)                                                                 | fastfetch                                                                                                                               | 2.40.4                                   | -                   | 2.69.0                                     | 2.69.0                    | 2.57.1                                        |
| git, github-cli (163)                                                           | git, gh                                                                                                                                 | 2.47.3, 2.46.0                           | -                   | 2.53.0, **absent**                         | 2.55.0, 2.46.0            | 2.53.0, 2.46.0                                |
| jq (164)                                                                        | jq                                                                                                                                      | 1.7.1                                    | -                   | 1.8.2                                      | 1.8.2                     | 1.8.1                                         |
| btop (165)                                                                      | btop                                                                                                                                    | 1.3.2                                    | -                   | 1.4.7                                      | 1.4.7                     | 1.4.6                                         |
| lazygit (166)                                                                   | lazygit                                                                                                                                 | 0.50.0                                   | -                   | 0.57.0                                     | 0.57.0                    | 0.57.0                                        |
| neovim (167)                                                                    | neovim                                                                                                                                  | 0.10.4                                   | -                   | 0.12.4                                     | 0.12.4                    | 0.11.6                                        |
| yazi (168)                                                                      | none (upstream .deb)                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| pciutils (169)                                                                  | pciutils                                                                                                                                | 3.13.0                                   | -                   | 3.15.0                                     | 3.15.0                    | 3.14.0                                        |
| quickshell (177)                                                                | quickshell                                                                                                                              | -                                        | 0.3.0               | 0.3.2                                      | 0.3.2                     | -                                             |
| cava (178)                                                                      | cava                                                                                                                                    | 0.10.4                                   | -                   | 1.0.0                                      | 1.0.0                     | 0.10.7                                        |
| cliphist (179)                                                                  | cliphist                                                                                                                                | 0.5.0                                    | -                   | 0.5.0                                      | 0.5.0                     | 0.5.0                                         |
| hyprpicker (180)                                                                | hyprpicker                                                                                                                              | -                                        | 0.4.7               | 0.4.7                                      | 0.4.7                     | 0.4.6                                         |
| imagemagick (181)                                                               | imagemagick                                                                                                                             | 7.1.1.43                                 | -                   | 7.1.2.31                                   | 7.1.2.33                  | 7.1.2.18                                      |
| waifu2x-ncnn-vulkan (182)                                                       | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| openrgb (183)                                                                   | openrgb                                                                                                                                 | -                                        | -                   | 1.0                                        | 1.0                       | 0.9+git                                       |
| ddcutil (185)                                                                   | ddcutil                                                                                                                                 | 2.2.0                                    | 2.2.7               | 2.2.7                                      | 2.2.7                     | 2.2.5                                         |
| ffmpeg, yt-dlp (186)                                                            | ffmpeg, yt-dlp                                                                                                                          | 7.1.5, 2025.04.30                        | -, 2026.08.19       | 9.0.2, 2026.08.19                          | same                      | 8.0.1, 2026.08.19                             |
| curl, libnotify, xdg-utils, desktop-file-utils, python (187)                    | curl, libnotify-bin, xdg-utils, desktop-file-utils, python3                                                                             | 8.14.1, 0.8.6, 1.2.1, 0.28, 3.13.5       |                     | 8.22.0, 0.8.8, 1.2.1, 0.28, 3.14.7         |                           | 8.18.0, 0.8.8, 1.2.1, 0.28, 3.14.3            |
| tesseract, tesseract-data-eng (195)                                             | tesseract-ocr, tesseract-ocr-eng                                                                                                        | 5.5.0, 4.1.0                             | -                   | 5.5.0                                      | 5.5.0                     | 5.5.0                                         |
| zbar (196)                                                                      | zbar-tools                                                                                                                              | 0.23.93                                  | -                   | 0.23.93                                    | 0.23.93                   | 0.23.93                                       |
| gpu-screen-recorder (197)                                                       | gpu-screen-recorder                                                                                                                     | -                                        | -                   | 5.13.8                                     | 5.13.8                    | -                                             |
| wf-recorder (197)                                                               | wf-recorder                                                                                                                             | 0.5.0                                    | -                   | 0.6.0                                      | 0.6.0                     | 0.6.0                                         |
| hyprsunset (198)                                                                | hyprsunset                                                                                                                              | -                                        | 0.4.0               | 0.4.0                                      | 0.4.0                     | -                                             |
| wtype (199)                                                                     | wtype                                                                                                                                   | 0.4                                      | -                   | 0.4                                        | 0.4                       | 0.4                                           |
| libqalculate (200)                                                              | libqalculate (qalc for CLI)                                                                                                             | 5.5.2                                    | -                   | 5.13.2                                     | 5.13.2                    | 5.9.0                                         |
| songrec (201)                                                                   | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| go (209)                                                                        | golang-go                                                                                                                               | 1.24                                     | 1.27                | 1.27                                       | 1.27                      | 1.26                                          |
| nodejs, npm (210)                                                               | nodejs, npm                                                                                                                             | 20.19.2, 9.2.0                           | -                   | 24.21.0, 12.2.0                            | 24.22.0, 12.2.0           | 22.22.1, 9.2.0                                |
| python, python-pip, python-pipx (211)                                           | python3, python3-pip, pipx                                                                                                              | 3.13.5, 25.1.1, 1.7.1                    | -                   | 3.14.7, 26.1.2, 1.15.0                     | same                      | 3.14.3, 25.1.1, 1.8.0                         |
| mise (212)                                                                      | none (upstream binary / apt repo)                                                                                                       | -                                        | -                   | -                                          | -                         | -                                             |
| gamescope (218)                                                                 | gamescope                                                                                                                               | -                                        | -                   | -                                          | -                         | 3.16.20                                       |
| gamemode (219)                                                                  | gamemode                                                                                                                                | 1.8.2                                    | -                   | 1.8.2                                      | 1.8.2                     | 1.8.2                                         |
| mangohud (220)                                                                  | mangohud                                                                                                                                | 0.7.2                                    | -                   | 0.8.4                                      | 0.8.4                     | 0.8.2~rc2                                     |
| qemu-desktop, edk2-ovmf, virglrenderer (221)                                    | qemu-system-x86 + qemu-system-gui + qemu-utils, ovmf, libvirglrenderer1                                                                 | 10.0.13, 2025.02, 1.1.0                  | 11.0.2              | 11.1.2, 2026.08, 1.3.0                     | same                      | 10.2.1, 2025.11, 1.2.0                        |
| libvirt, looking-glass, swtpm, quickemu (223-224)                               | libvirt-daemon-system, looking-glass-client, swtpm, quickemu                                                                            | 11.3.0, -, 0.7.1, 4.9.7                  |                     | 12.8.0, -, 0.10.2, 4.9.9                   | 12.8.0, B7, 0.10.2, 4.9.9 | 12.0.0, -, 0.10.1, 4.9.7                      |
| localsend-bin (264, AUR)                                                        | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| matugen (119)                                                                   | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| brightnessctl, hypridle (120-121)                                               | brightnessctl, hypridle                                                                                                                 | 0.5.1, -                                 | -, 0.1.8            | 0.5.1, 0.1.8                               | same                      | 0.5.1, 0.1.7                                  |
| upower, power-profiles-daemon (122)                                             | same                                                                                                                                    | 1.90.9, 0.30                             | -                   | 1.91.5, 0.30                               | same                      | 1.91.1, 0.30                                  |
| fuzzel, grim, slurp, playerctl, wl-clipboard (123-126)                          | same names                                                                                                                              | 1.12.0, 1.4.0, 1.5.0, 2.4.1, 2.2.1       | wl-clipboard 2.3.0  | 1.15.0, 1.5.0, 1.5.0, 2.4.1, 2.3.0         | same                      | 1.12.0, 1.4.0, 1.6.0, 2.4.1, 2.2.1            |
| hyprland, xorg-xwayland (96)                                                    | hyprland, xwayland                                                                                                                      | -, 24.1.6                                | 0.55.2, -           | 0.56.2, 24.1.14                            | same                      | 0.53.3, 24.1.10                               |
| hyprpolkitagent (97)                                                            | hyprpolkitagent                                                                                                                         | -                                        | 0.1.3               | 0.2.0                                      | 0.2.0                     | 0.1.3                                         |
| xdg-desktop-portal-hyprland, -gtk (98)                                          | same                                                                                                                                    | -, 1.15.3                                | 1.4.1, -            | 1.4.1, 1.15.3                              | same                      | 1.3.11, 1.15.3                                |
| xdg-user-dirs (99)                                                              | xdg-user-dirs                                                                                                                           | 0.18                                     | -                   | 0.20                                       | 0.20                      | 0.19                                          |
| adwaita-icon-theme, gnome-themes-extra, papirus-icon-theme (102)                | same                                                                                                                                    | 48.1, 3.28, 20250501                     | -                   | 51.0, 3.28, 20260801                       | same                      | 50.0, 3.28, 20250501+git                      |
| vimix-cursors (103)                                                             | none                                                                                                                                    | -                                        | -                   | -                                          | -                         | -                                             |
| flatpak (104)                                                                   | flatpak                                                                                                                                 | 1.16.6                                   | -                   | 1.18.4                                     | 1.18.4                    | 1.16.6                                        |
| sddm, polkit, gnome-keyring (110-111)                                           | sddm, polkitd, gnome-keyring                                                                                                            | 0.21.0+git20250502, 126, 48.0            | -                   | git20260819, 127, 51.1                     | git20260819, 128, 51.1    | git20250502, 127, 50.0                        |
| inter-font, noto-fonts, noto-fonts-cjk, noto-fonts-emoji (273-274)              | fonts-inter, fonts-noto-core, fonts-noto-cjk, fonts-noto-color-emoji                                                                    | 4.1, 20201225, 20240730, 2.051           | -                   | same                                       | same                      | same                                          |
| ttf-jetbrains-mono-nerd, ttf-firacode-nerd, ttf-hack-nerd (274-275)             | none as Nerd Font (plain fonts-jetbrains-mono 2.304, fonts-firacode 6.2, fonts-hack 3.003 exist)                                        | -                                        | -                   | -                                          | -                         | -                                             |
| ttf-material-symbols-variable (275)                                             | none (`fonts-material-design-icons-iconfont` is the old icon font, not Material Symbols)                                                | -                                        | -                   | -                                          | -                         | -                                             |
| otf-space-grotesk (59), ttf-fraunces-variable (269)                             | fonts-space-grotesk (Ubuntu only); Fraunces none                                                                                        | -                                        | -                   | -                                          | -                         | 2.0.0-0ubuntu2 (Space Grotesk)                |
| pipewire stack, wireplumber, alsa-utils, rtkit (87-89)                          | pipewire, pipewire-alsa, pipewire-pulse, pipewire-audio, libspa-0.2-bluetooth, wireplumber, alsa-utils, rtkit                           | 1.4.2, 0.5.8, 1.2.14, 0.13               | 1.6.9, 0.5.12       | 1.6.9, 0.5.18, 1.2.16, 0.14                | same                      | 1.6.2, 0.5.13, 1.2.15.2, 0.14                 |
| networkmanager, iwd, wpa_supplicant, wireless-regdb, iw, bluez(-utils) (84-86)  | network-manager, iwd, wpasupplicant, wireless-regdb, iw, bluez (bluetoothctl is in `bluez`)                                             | 1.52.1, 3.8, 2.10, 2026.05.30, 6.9, 5.82 | -                   | 1.58.1, 3.12, 2.10, 2026.09.03, 6.17, 5.87 | same                      | 1.54.3, 3.10, 2.11, 2026.05.30, 6.17, 5.85    |
| base-devel, linux-headers, dkms, rust (71-74)                                   | build-essential, linux-headers-amd64, dkms, rustc + cargo                                                                               | 12.12, 6.12.107, 3.2.2, 1.85.1           | -, 7.2.6, -, 1.96.1 | 12.12, 7.2.11, 3.2.2, 1.96.1               | same, 1.97.1              | 12.12, (linux-generic 7.0.0), 3.2.2, 1.93.1   |
| btrfs-progs, cryptsetup, dosfstools, efibootmgr, plymouth, snapper (76-78)      | same names                                                                                                                              | 6.14, 2.7.5, 4.2, 18, 24.004.60, 0.10.6  | btrfs-progs 7.1     | 7.1, 2.8.8, 4.2, 18, 26.134.222, 0.10.6    | same                      | 6.17.1, 2.8.4, 4.2, 18, 24.004.60+git, 0.10.6 |
| limine (77), snap-pac (78), mkinitcpio (74)                                     | limine: none in any suite; snap-pac: Debian `snapper` carries its own apt hook; mkinitcpio -> initramfs-tools (0.148.4) or dracut (106) |                                          |                     |                                            |                           |                                               |
| mesa, vulkan-icd-loader (95)                                                    | libgl1-mesa-dri + mesa-vulkan-drivers, libvulkan1                                                                                       | 25.0.7, 1.4.309                          | 26.1.6              | 26.1.6, 1.4.363                            | 26.2.5                    | 26.0.8, 1.4.341                               |
| qt6-wayland, qt6ct, qt6-declarative, qt6-5compat, qt6-svg, qt6-multimedia (100) | qt6-wayland, qt6ct, qml6-module-*, qml6-module-qt5compat-graphicaleffects, libqt6svg6, libqt6multimedia6 + qml6-module-qtmultimedia     | 6.8.2, 0.10                              | -                   | 6.11.2, 0.11                               | same                      | 6.10.2, 0.11                                  |
| gst-plugins-base/good/bad/ugly, gst-libav (101)                                 | gstreamer1.0-plugins-{base,good,bad,ugly}, gstreamer1.0-libav                                                                           | 1.26.x                                   | -                   | 1.28.8                                     | 1.28.8                    | 1.28.2                                        |

**As-is on Debian:** PARTIAL. No Debian package in any suite for: yazi, mise,
matugen, zsh-history-substring-search, waifu2x-ncnn-vulkan, songrec, localsend,
limine, vimix-cursors, the three Nerd Fonts, Material Symbols, Space Grotesk
(except resolute's `fonts-space-grotesk` 2.0.0), Fraunces; additionally absent
from trixie (present in bpo/forky): quickshell, hyprland, hyprpicker, hypridle,
hyprsunset, hyprpolkitagent, xdg-desktop-portal-hyprland, gpu-screen-recorder,
openrgb, gamescope (resolute only), ble.sh; `gh` is absent from forky.

**Complexity:** High (aggregate).

---

---

## Part E: Fonts, cursors, icons, GTK/Qt themes, assets

### Fonts (`release/packages/{otf-space-grotesk,ttf-maple-mono-nf}`, `system/packages/{base,aur}.packages`)

**What it does:**

- Brand type stack (`docs/ui-ux.md:208-217`): Fraunces for headlines
  (`Tokens.display`), Space Grotesk for UI (`Tokens.ui`), "SpaceMono Nerd Font"
  for tabular data (`Tokens.mono`, `ryoku/ui/Singletons/Tokens.qml:107`), Noto
  Sans CJK JP for seals.
- Files referencing each family (grep over `ryoku/`
  QML/JS/conf/toml/json/lua/go/css/yaml/kdl): Space Grotesk 70, Fraunces 79,
  Material Symbols 56, `"Inter` 50, JetBrainsMono Nerd 13, Noto Sans 17, Maple
  Mono 2, FiraCode Nerd 1.
- Sources on Arch: `system/packages/base.packages:305-323` (noto-fonts,
  noto-fonts-cjk, inter-font, noto-fonts-emoji, ttf-jetbrains-mono-nerd,
  ttf-firacode-nerd, ttf-hack-nerd, ttf-material-symbols-variable,
  otf-space-grotesk, ttf-maple-mono-nf);
  `release/packages/ryoku-desktop/PKGBUILD:168-173` repeats six of them as hard
  depends; `system/packages/aur.packages:52` `ttf-fraunces-variable` (AUR,
  post-install, online-only, best-effort, `aur.packages:1-4`).
- `[ryoku]` font recipes: `otf-space-grotesk` 2.0.0 installs the release zip's
  OTFs to `/usr/share/fonts/OTF`
  (`release/packages/otf-space-grotesk/PKGBUILD:17-31`); `ttf-maple-mono-nf` 7.9
  installs `MapleMono-NF.zip`'s TTFs to `/usr/share/fonts/maple-mono-nf`
  (`release/packages/ttf-maple-mono-nf/PKGBUILD:13-25`).
- Configs that name fonts: `ryoku/shell/qt6ct/qt6ct.conf:9-10` (Space Grotesk,
  SpaceMono Nerd Font), `ryoku/shell/gtk-3.0/settings.ini:14` and
  `gtk-4.0/settings.ini` (Space Grotesk 10), `ryoku/apps/kitty/kitty.conf:2`
  (SpaceMono Nerd Font), `ryoku/shell/ipc/matugen.go:1645` (mono fallback).

**Arch couplings:**

- Arch font dirs `/usr/share/fonts/OTF`, `/usr/share/fonts/TTF`. Debian's
  convention is `/usr/share/fonts/opentype/<name>/` and
  `/usr/share/fonts/truetype/<name>/`; fontconfig scans `/usr/share/fonts`
  recursively, so either path renders.
- **"SpaceMono Nerd Font" is installed by no Ryoku package list or PKGBUILD**
  (grep for `space-mono`/`spacemono` in `system/packages/*.packages` and
  `release/packages/*/PKGBUILD` finds nothing). On Arch it would be
  `ttf-space-mono-nerd` (extra, 3.5.1-2). Arch boxes render a fontconfig
  fallback for the mono role today.

**Dependencies:**

| Arch pkg                                  | Used for (cite)                                                 | Debian/Ubuntu pkg                                                                      | trixie     | trixie-bpo | forky         | sid           | resolute         | Min version / note                                                                            |
| ----------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ---------- | ---------- | ------------- | ------------- | ---------------- | --------------------------------------------------------------------------------------------- |
| noto-fonts 2026.10.01                     | Noto Sans UI fallback                                           | fonts-noto-core                                                                        | 20201225-2 | -          | 20201225-6    | 20201225-6    | 20201225-2build1 | Debian's Noto snapshot is from 2020                                                           |
| noto-fonts-cjk 20240730                   | `Tokens.jp` seals                                               | fonts-noto-cjk                                                                         | 1:20240730 | -          | 1:20240730    | 1:20240730    | 1:20240730       | same upstream                                                                                 |
| noto-fonts-emoji 2.051                    | emoji                                                           | fonts-noto-color-emoji                                                                 | 2.051      | -          | 2.051         | 2.051         | 2.051            | same upstream                                                                                 |
| inter-font 4.1                            | "Inter"                                                         | fonts-inter (static OTF in `/usr/share/fonts/opentype/inter/`); fonts-inter-variable   | 4.1        | -          | 4.1           | 4.1           | 4.1              | same upstream                                                                                 |
| ttf-jetbrains-mono-nerd 3.5.1             | "JetBrainsMono Nerd Font" (13 files)                            | none (fonts-jetbrains-mono 2.304 is unpatched)                                         | -          | -          | -             | -             | -                | Nerd Fonts v3.5.1                                                                             |
| ttf-firacode-nerd, ttf-hack-nerd 3.5.1    | Global font picker choices (`system/packages/CHANGELOG.md:146`) | none (fonts-firacode 6.2, fonts-hack 3.003 are unpatched)                              | -          | -          | -             | -             | -                | Nerd Fonts v3.5.1                                                                             |
| (none; ttf-space-mono-nerd 3.5.1 on Arch) | `Tokens.mono`, kitty, qt6ct                                     | none                                                                                   | -          | -          | -             | -             | -                | Nerd Fonts v3.5.1 `SpaceMono`                                                                 |
| ttf-material-symbols-variable 2.874       | icon glyphs (56 files)                                          | none (fonts-material-design-icons-iconfont 6.7.0 is the older Material _Icons_ family) | -          | -          | -             | -             | -                | the three `MaterialSymbols{Outlined,Rounded,Sharp}[FILL,GRAD,opsz,wght].ttf` (Arch file list) |
| otf-space-grotesk 2.0.0 ([ryoku])         | UI sans                                                         | fonts-space-grotesk (Ubuntu universe only)                                             | -          | -          | -             | -             | 2.0.0-0ubuntu2   | 2.0.0                                                                                         |
| ttf-maple-mono-nf 7.9 ([ryoku])           | terminal/code option                                            | none                                                                                   | -          | -          | -             | -             | -                | 7.9                                                                                           |
| ttf-fraunces-variable (AUR)               | display serif                                                   | none                                                                                   | -          | -          | -             | -             | -                | upstream latest release 1.000                                                                 |
| (Debian only)                             | Nerd symbols without a patched family                           | fonts-nerd-symbols                                                                     | -          | -          | 3.4.0+dfsg1-1 | 3.4.0+dfsg1-1 | -                | not a substitute for the patched families                                                     |

**As-is on Debian:** PARTIAL. Noto, Noto CJK, Noto Emoji and Inter are packaged;
seven families (Space Grotesk outside resolute, Maple Mono NF,
JetBrainsMono/FiraCode/Hack Nerd, Material Symbols, Fraunces) plus SpaceMono
Nerd Font are not.

**Port steps:** (one arch-all deb per family, same model as the two `[ryoku]`
recipes; fontconfig's own dpkg trigger on `/usr/share/fonts` runs `fc-cache`, so
no postinst)

1. Archive: `fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji fonts-inter`.
2. Space Grotesk:
   `curl -LO https://github.com/floriankarsten/space-grotesk/releases/download/2.0.0/SpaceGrotesk-2.0.0.zip`
   (sha256 `53b415577d4139248555300710bea0d268c7a5be67b93de53b716a9736cabffd`,
   `otf-space-grotesk/PKGBUILD:25`),
   `install -Dm644 SpaceGrotesk-2.0.0/otf/*.otf -t /usr/share/fonts/opentype/space-grotesk/`.
   On resolute `fonts-space-grotesk` 2.0.0 is the same upstream release (family
   name equality not checked in this pass).
3. Maple Mono NF:
   `https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.zip`
   (sha256 `59098b87c895d871635d37680e88000ae2b2b25b55428195b228ec589e35fb89`),
   all `*.ttf` to `/usr/share/fonts/truetype/maple-mono-nf/`.
4. Nerd Fonts v3.5.1 (the version of Arch's split packages): for
   `JetBrainsMono FiraCode Hack SpaceMono`, fetch
   `https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/<name>.tar.xz`
   and install its `*.ttf` to `/usr/share/fonts/truetype/nerd-fonts-<name>/`.
5. Material Symbols: the three variable TTFs from
   `github.com/google/material-design-icons` (`variablefont/`), at the revision
   Arch packages as 2.874, to `/usr/share/fonts/truetype/material-symbols/`.
   License Apache-2.0.
6. Fraunces:
   `https://github.com/undercasetype/Fraunces/releases/download/1.000/UnderCaseType_Fraunces_1.000.zip`,
   variable TTFs to `/usr/share/fonts/truetype/fraunces/`. Which file set the
   AUR `ttf-fraunces-variable` installs was not read in this pass.

**Complexity:** Low.

**Issues / risks:**

- Debian `fonts-noto-core` is the 20201225 snapshot (all suites) against Arch's
  2026.10.01: coverage and metrics differ, so text that falls back to Noto Sans
  can render differently.
- Shipping Fraunces as a hard-installed deb differs from Arch, where it is an
  AUR best-effort install that an offline Arch install never gets.
- All families are OFL-1.1 (Space Grotesk, Maple, Fraunces, Nerd Fonts' patched
  OFL fonts) or Apache-2.0 (Material Symbols), so they fit Debian `main` terms.

**Questions for the human:**

- SpaceMono Nerd Font. Options: (a) ship it (the design's documented mono
  renders, `docs/ui-ux.md:216`; Debian then looks different from today's Arch
  boxes, which fall back); (b) do not ship it (identical to Arch behaviour, mono
  role on a fallback face).
- Fraunces delivery. Options: (a) hard-installed deb (always present; differs
  from Arch offline installs); (b) optional, matching Arch's best-effort AUR
  semantics.

---

### Cursors (`release/packages/{ryoku-cursors,ryoku-cursor-material}`, `system/packages/*.packages`)

**What it does:**

- Default theme `Bibata-Modern-Ice` size 24
  (`ryoku/hyprland/modules/env.lua:1-4`, `modules/autostart.lua:7`,
  `ryoku/shell/gtk-3.0/settings.ini:13`).
- `ryoku-cursors` 2.0.7: unpacks Bibata's `Bibata.tar.xz` release (all six
  Modern/Original x Amber/Classic/Ice variants) to `/usr/share/icons/` and adds
  a hyprcursor manifest for `Bibata-Modern-Classic` built with
  `hyprcursor-util --extract`/`--create`
  (`release/packages/ryoku-cursors/PKGBUILD:27-72`).
  `provides/conflicts/replaces` the AUR `bibata-cursor-theme(-bin)` (`:35-37`).
  Hard depend of `ryoku-desktop` (`release/packages/ryoku-desktop/PKGBUILD:80`).
- `ryoku-cursor-material` 1.0.0: vendored recipe from
  SakibShahariar/material-bibata-cursor (`themes.json`,
  `compile_bibata_material.fish`, `metadata_generator.py`) over
  `rtgiskard/bibata_cursor` at `f4ccfe8a...` (`PKGBUILD:35-43`); builds
  `Bibata-Material-Ryoku` (`:44-56`), ships it, the Bibata SVG source to
  `/usr/share/ryoku-cursor-material/bibata` and
  `/usr/bin/ryoku-cursor-material-recolor` (`:58-69`). The recolor tool
  (python3) runs on every palette change, rebuilds the theme into
  `~/.local/share/icons` (`ryoku-cursor-material-recolor:32-38`), and applies it
  with `ryoku wm act cursor.set` (`:150-152`). The Bibata `cursor_utils.py` it
  runs imports `tomllib` and shells out to `rsvg-convert` and `xcursorgen`.
- `vimix-cursors` from Arch extra (`system/packages/base.packages:112-114`).
- AUR best-effort extras: `phinger-cursors`, `catppuccin-cursors-mocha`,
  `apple_cursor` (`system/packages/aur.packages:19,24,27`).

**Arch couplings:** Arch makedepends/depends names: `xorg-xcursorgen` -> Debian
`x11-apps` (ships `/usr/bin/xcursorgen`); `librsvg` -> `librsvg2-bin`
(`rsvg-convert`); `hyprcursor` -> `hyprcursor-util`; `python` -> `python3`
(`ryoku-cursors/PKGBUILD:42`, `ryoku-cursor-material/PKGBUILD:31,34`). No paths
differ (`/usr/share/icons` on both).

**Dependencies:**

| Arch pkg                                                      | Used for (cite)                           | Debian/Ubuntu pkg                                                              | trixie        | trixie-bpo | forky         | sid     | resolute      | Min version                                          |
| ------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------ | ------------- | ---------- | ------------- | ------- | ------------- | ---------------------------------------------------- |
| ryoku-cursors (Bibata 2.0.7)                                  | default pointer                           | bibata-cursor-theme (no hyprcursor manifest; 0 `manifest.hl` in its file list) | 2.0.6-1       | -          | 2.0.6-1       | 2.0.6-1 | 2.0.6-1build1 | 2.0.7 + hyprcursor for Modern-Classic                |
| hyprcursor (hyprcursor-util)                                  | build (`ryoku-cursors/PKGBUILD:42,52-54`) | hyprcursor-util                                                                | -             | 0.1.13     | 0.1.13        | 0.1.13  | -             | -                                                    |
| xcur2png                                                      | build (`:42`)                             | xcur2png                                                                       | 0.7.1         | -          | 0.7.1         | 0.7.1   | 0.7.1         | -                                                    |
| xorg-xcursorgen                                               | material build + runtime                  | x11-apps                                                                       | 7.7+11        | -          | 7.7+11        | 7.7+11  | 7.7+11        | -                                                    |
| librsvg                                                       | material build + runtime                  | librsvg2-bin                                                                   | 2.60.0        | -          | 2.63.2        | 2.63.2  | 2.61.3        | -                                                    |
| python                                                        | material runtime                          | python3                                                                        | 3.13.5        | -          | 3.14.7        | 3.14.7  | 3.14.3        | 3.11 (`tomllib`)                                     |
| fish, jq, git                                                 | material build                            | fish, jq, git                                                                  | 4.0.2 / 1.7.1 | -          | 4.9.3 / 1.8.2 | same    | 4.2.1 / 1.8.1 | -                                                    |
| vimix-cursors 2020_02_24                                      | picker choice                             | none (Debian `vimix` is an unrelated video mixer)                              | -             | -          | -             | -       | -             | upstream tag 2020-02-24                              |
| phinger-cursors, catppuccin-cursors-mocha, apple_cursor (AUR) | picker choices                            | none                                                                           | -             | -          | -             | -       | -             | phinger v2.2, catppuccin v2.0.0, apple_cursor v2.0.1 |

**As-is on Debian:** PARTIAL: Debian's `bibata-cursor-theme` gives the XCursor
set at 2.0.6 without the hyprcursor manifest and without the Material variant.

**Port steps:**

1. `ryoku-cursors` deb: fetch
   `https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz`
   (sha256 `172e33c4ae415278384dcecc7d1a9b7a024266bc944bc751fd86532be1cc6251`),
   run `PKGBUILD:46-55` and install as `:62-72`. Control:
   `Provides: bibata-cursor-theme`, `Conflicts: bibata-cursor-theme`,
   `Replaces: bibata-cursor-theme` (Debian's package owns the same
   `/usr/share/icons/Bibata-*` paths). Build-Depends `hyprcursor-util, xcur2png`
   (resolute: self-built hyprcursor, see the stack section).
2. `ryoku-cursor-material` deb: pre-fetch `rtgiskard/bibata_cursor` at
   `f4ccfe8abb63fddc7b3ce51a866fd8378395cb3d` into the source package;
   Build-Depends `fish, jq, librsvg2-bin, x11-apps, python3, git`;
   `Depends: python3 (>= 3.11), librsvg2-bin, x11-apps`.
3. `vimix-cursors` deb: clone `https://github.com/vinceliuice/Vimix-cursors`
   (tag `2020-02-24`), `cp -r dist /usr/share/icons/Vimix-cursors`,
   `cp -r dist-white /usr/share/icons/Vimix-white-cursors` (upstream
   `install.sh:22-23`).
4. Optional extras from prebuilt releases into `/usr/share/icons/`:
   `phisch/phinger-cursors` v2.2 `phinger-cursors-variants.tar.bz2`;
   `catppuccin/cursors` v2.0.0 `catppuccin-mocha-*-cursors.zip`;
   `ful1e5/apple_cursor` v2.0.1 `macOS.tar.xz`, `macOS-White.tar.xz`.

**Complexity:** Low.

**Issues / risks:**

- The configured theme is `Bibata-Modern-Ice`, but the hyprcursor manifest is
  built for `Bibata-Modern-Classic` only (`ryoku-cursors/PKGBUILD:47-55`); the
  same on Arch.

---

### Icons, GTK theme, Qt theme (`release/packages/ryoku-desktop/PKGBUILD:57-72`, `ryoku/shell/{gtk-3.0,gtk-4.0,qt6ct}`)

**What it does:**

- GTK3 theme `adw-gtk3-dark` set at login
  (`ryoku/hyprland/modules/autostart.lua:13`, `ryoku/niri/autostart.kdl:19`) and
  in the seeds `ryoku/shell/gtk-3.0/settings.ini:11`, `gtk-4.0/settings.ini`
  (`gtk-theme-name=adw-gtk3-dark`, `gtk-icon-theme-name=ryoku-folders`).
  `ryoku doctor` maps the store's `adw` choice to `adw-gtk3[-dark]`
  (`ryoku/cli/internal/doctor/doctor.go:2261-2276`). Source on Arch:
  `adw-gtk-theme` (hard depend, `ryoku-desktop/PKGBUILD:58-64`).
- `gnome-themes-extra` for the "adwaita" option and the portal file chooser
  (`ryoku-desktop/PKGBUILD:65-68`).
- Icons: `papirus-icon-theme` (`:69-72`); `qt6ct.conf:4` selects `Papirus-Dark`;
  `ryoku/shell/scripts/ryoku-cmd-folders` builds a `ryoku-folders` overlay that
  `Inherits=Papirus-Dark` from `/usr/share/icons/Papirus` (`:19,72`), refreshes
  it with `gtk-update-icon-cache` (`:84`) and selects it with `gsettings`
  (`:99-101`). `adwaita-icon-theme` from base
  (`system/packages/base.packages:101`).
- Qt: `QT_QPA_PLATFORMTHEME=qt6ct` (`modules/env.lua:64`), `qt6ct.conf:1-10`
  (custom palette `~/.config/qt6ct/colors/ryoku.conf`, Fusion style, Space
  Grotesk / SpaceMono). Installed by `ryoku-desktop/PKGBUILD:371`; gtk seeds by
  `:379-380`.

**Arch couplings:** package name `adw-gtk-theme` (Arch) vs no Debian package; no
path differences (`/usr/share/themes`, `/usr/share/icons/Papirus` are the same
on Debian).

**Dependencies:**

| Arch pkg                    | Used for (cite)                                               | Debian/Ubuntu pkg     | trixie   | trixie-bpo | forky    | sid      | resolute             | Min version                |
| --------------------------- | ------------------------------------------------------------- | --------------------- | -------- | ---------- | -------- | -------- | -------------------- | -------------------------- |
| adw-gtk-theme 6.5           | GTK3 theme (`autostart.lua:13`)                               | none                  | -        | -          | -        | -        | -                    | 6.5 (Arch)                 |
| gnome-themes-extra 3.28     | Adwaita-dark                                                  | gnome-themes-extra    | 3.28-4   | -          | 3.28-5   | 3.28-5   | 3.28-5               | -                          |
| papirus-icon-theme 20260801 | icons, folder overlay base                                    | papirus-icon-theme    | 20250501 | -          | 20260801 | 20260801 | 20250501+git20260316 | -                          |
| adwaita-icon-theme          | fallback icons                                                | adwaita-icon-theme    | 48.1     | -          | 51.0     | 51.0     | 50.0                 | -                          |
| (gtk3)                      | `gtk-update-icon-cache` (`ryoku-cmd-folders:84`)              | gtk-update-icon-cache | 4.18.6   | -          | 4.24.1   | 4.24.1   | 4.22.4               | -                          |
| qt6ct 0.11                  | Qt platform theme                                             | qt6ct                 | 0.10-2   | -          | 0.11-2   | 0.11-2   | 0.11-2               | -                          |
| matugen                     | palette engine behind all templates (`docs/theming.md:15-20`) | none                  | -        | -          | -        | -        | -                    | owned by the shell section |

**As-is on Debian:** PARTIAL: only `adw-gtk3` is missing.

**Port steps:**

1. `adw-gtk3` deb:
   `curl -LO https://github.com/lassekongo83/adw-gtk3/releases/download/v6.5/adw-gtk3v6.5.tar.xz`;
   the tarball holds prebuilt `adw-gtk3/` and `adw-gtk3-dark/`; install both to
   `/usr/share/themes/`. Name it `adw-gtk-theme` to keep the Arch name (no
   Debian package owns it). Alternative: build from source with meson + sassc.
2. Archive:
   `gnome-themes-extra papirus-icon-theme adwaita-icon-theme gtk-update-icon-cache qt6ct libglib2.0-bin`.

**Complexity:** Low.

**Issues / risks:** trixie's Papirus (20250501) lacks icons added since;
folder-color names Ryoku maps to may differ (`ryoku-cmd-folders` picks
"Papirus's nearest folder colour", `:3-6`); not checked per name.

---

### Brand assets, wallpapers, decor art (`ryoku/assets/`)

**What it does:** 94 files, 239 MB (`ryoku/assets/wallpapers` 234 MB, 59 files;
`brand` 1.7 MB; `ryodecors` 3.9 MB). Install destinations:

- `brand/fastfetch-emblem.png` ->
  `/usr/share/ryoku/config/fastfetch/fastfetch-emblem.png`
  (`release/packages/ryoku-desktop/PKGBUILD:392-393`); `brand/logo.svg` ->
  `/usr/share/icons/hicolor/scalable/apps/ryoku-hub.svg` (`:427-428`);
  `brand/logo-mark.svg` as the fallback app icon in the app loop (`:317`).
- `ryodecors/` -> `/usr/share/ryoku/ryodecors/` (`:508-509`), seeded into
  `~/Pictures/ryodecors` by the installer and `ryoku doctor`.
- `wallpapers/` is not packaged: the installer copies it from the repo payload
  to `~/Pictures/Wallpapers`, `brand/` to `~/.local/share/ryoku/assets/brand`,
  `ryodecors/` to `~/Pictures/ryodecors`
  (`installation/backend/lib/deploy.sh:298-306`).

**Arch couplings:** none (plain files).

**As-is on Debian:** YES.

**Port steps:** same install lines in the `ryoku-desktop` deb; the installer
keeps seeding wallpapers from its payload.

**Complexity:** Low.

**Issues / risks:** wallpapers (234 MB) ride only the installer payload; a box
installed from debs without the Ryoku installer gets no wallpaper set (same as
an Arch box built without the installer).

---

## Cross-cutting findings

- **Hyprland floor is 0.56.0** (`hl.get_loaded_plugins`,
  `ryoku/wm/hyprland/config_plugins.go:114`; #13322 maximise fix,
  `ryoku/hyprland/CHANGELOG.md:46-51`). Lua config itself dates from 0.55.0.
  Only Debian forky/sid have it (0.56.2, identical to Arch); trixie-bpo has
  0.55.2, resolute 0.53.3. `ryoku/README.md:9-10` says "0.55+".
- **The C++26 toolchain reaches users.** Hyprland 0.56 was only ever built by
  Debian with GCC 16; the runtime plugin rebuild (`ryoku doctor`, Hub > Plugins)
  compiles against Hyprland's headers with the box's default `c++`, which is g++
  14 on trixie and 15 on resolute. The installer/package set must decide which
  compiler a user box carries.
- **Plugin ABI coupling in deb terms.** Debian's `hyprland` Provides
  `hyprland-abi-<sha7>`; a plugin deb built with `Depends: ${hyprland:ABI}` is
  exact, but `ryoku-desktop-hyprland`'s hard `=$pkgver` Depends on all five
  plugin packages then blocks or removes the desktop on every Debian Hyprland
  binNMU until `[ryoku]` republishes. The update/delivery section must know
  this.
- **Hyprland `version.h` must carry the upstream commit.** Debian's does
  (`efb50993...` for 0.56.2); a tarball self-build without `GIT_COMMIT_HASH`
  writes `unknown` and disables the ABI receipt, staleness checks, `commit_pins`
  lookup and rebuild (`ryoku/wm/hyprland/config_plugins_tier.go:179`).
- **Qt6 QML path.** `ryoku-desktop-hyprland` installs `Ryoku.Wm.Hyprland` to
  `/usr/lib/qt6/qml` (`PKGBUILD:87-88`), like `Ryoku.Ui` in `ryoku-desktop`
  (`PKGBUILD:331-332`); Debian's is `/usr/lib/x86_64-linux-gnu/qt6/qml`.
- **pacman inside Go code in this scope:** `ryoku/wm/reclaim.go:204-292`
  (compositor switch plan), `ryoku/wm/hyprland/config_plugins_tier.go:691`
  (`pacman -Q`), `ryoku/cli/internal/doctor/reconcile_shipped_apps.go:72-93`
  (app delivery). `ryoku-wm` is vendored into five modules (cli, hub/backend,
  rashin/backend, shell/ipc, shell/ryogami/daemon); a port edit must be
  re-vendored in each.
- **Package names are a Go contract.** `compositorPackages` in
  `ryoku/wm/hyprland/caps.go:66-81` and `ryoku/wm/niri/caps.go:64-81` list the
  names a switch reclaims; Debian names are identical for hyprland,
  hyprpolkitagent, xdg-desktop-portal-hyprland, hypridle, hyprpicker,
  hyprsunset, xdg-desktop-portal-gnome, gammastep; the `[ryoku]`-built debs must
  keep `hypr-dynamic-cursors`, `ryoku-hypr-plugins`, `hyprglass`, `imgborders`,
  `ryoku-keysounds`, `hyprland-preview-share-picker`, `niri`,
  `xwayland-satellite`.
- **niri >= 26.04** (window `background-effect`); niri and xwayland-satellite
  are in no Debian or Ubuntu suite.
- **`xdg-desktop-portal-gnome` on Debian Recommends gnome-shell +
  gnome-settings-daemon and Depends on nautilus**; installer apt calls need
  `--no-install-recommends` or a pin.
- **hyprpicker on niri boxes:** niri binds call `hyprpicker -a`
  (`ryoku/wm/niri/config_binds.go:167`) and `ryoku-desktop` depends on it, so
  the hypr library stack (hyprutils) is needed on a niri-only box.
- **Theme names hardcoded in both compositor autostarts:** `adw-gtk3-dark`
  (`ryoku/hyprland/modules/autostart.lua:13`, `ryoku/niri/autostart.kdl:19`) and
  `Bibata-Modern-Ice`; `adw-gtk3` is in no Debian/Ubuntu suite, Debian's
  `bibata-cursor-theme` is 2.0.6 without hyprcursor data.
- **`fd` vs `fdfind`:** `ryoku/apps/fish/config.fish:58`,
  `ryoku/apps/terminal-shell/env.sh:12` and yazi's search call `fd`; a
  Ryoku-owned `/usr/bin/fd -> fdfind` symlink fixes every caller (no Debian
  package owns `/usr/bin/fd`). No config in this scope calls `bat`.
- **Go floors in this scope:** `ryoku/wm/go.mod` says go 1.22;
  `ryostore/backend` and the three `ryovm` helpers say go 1.26 (trixie golang-go
  is 1.24; Debian's `go.env` `GOTOOLCHAIN=auto` silently downloads a newer
  toolchain, so build with `GOTOOLCHAIN=local` and trixie-bpo
  `golang-1.26`/`golang-go` 1.27).
- **SpaceMono Nerd Font** is the documented mono (`docs/ui-ux.md:216`,
  `ryoku/ui/Singletons/Tokens.qml:107`, `kitty.conf:2`, `qt6ct.conf:10`) and no
  Ryoku package installs it, on Arch either.
- **Chromium flags** need `/etc/chromium.d/` on Debian; resolute has only the
  snap. Debian's pipewire lacks AAC (`51-ryoku-bluetooth.conf:24`).
- **Doc drift found in this scope:** `docs/hyprland-plugins.md:162-164` (builder
  files that do not exist), `docs/compositors.md:302` vs
  `ryoku-desktop-niri/PKGBUILD:40-41` (exclusive vs not),
  `docs/compositors.md:22` vs `:289` (eleven vs ten verbs),
  `ryoku/apps/README.md:8` (JetBrains Mono vs SpaceMono),
  `docs/preinstalled.md:53-55` (ryostore/ryowalls/ryovm packages that do not
  exist).
- **Tooling note for the coordinator:** `tools/pkgver` does not URL-encode `+`,
  so names like `g++-16`, `libsdbus-c++-dev` always print `-`; the Ubuntu column
  also returned `-` for whole batches intermittently (re-queried in small
  batches or by source name here).

## Debian package names this file needs

Archive (all suites unless noted; versions in the tables above): hyprland
(forky/sid), hyprland-dev (forky/sid), hyprland-guiutils, hyprcursor-util,
xdg-desktop-portal-hyprland, hyprpolkitagent, hyprsunset, hypridle, hyprpicker,
libaquamarine14, libhyprutils13, libhyprlang2, libhyprcursor0, libhyprgraphics4,
libhyprwire3, liblua5.5-0, libinput10 (>= 1.29), xwayland, xdg-desktop-portal,
xdg-desktop-portal-gtk, xdg-desktop-portal-gnome, gnome-keyring, polkitd,
gammastep, libxcb-cursor0, libwayland-server0, procps, libglib2.0-bin, dbus-bin,
util-linux, libnotify-bin, wireplumber, playerctl, jq, xcvt, systemd, ffmpeg,
python3, imagemagick, libcanberra0, slurp, libgtk-4-1, libgtk4-layer-shell0,
fonts-noto-core, fonts-noto-cjk, fonts-noto-color-emoji, fonts-inter,
gnome-themes-extra, papirus-icon-theme, adwaita-icon-theme,
gtk-update-icon-cache, qt6ct, librsvg2-bin, x11-apps, kitty, fish, bash,
bash-completion, ble.sh (forky+), zsh, zsh-autosuggestions,
zsh-syntax-highlighting, starship, fastfetch, chafa, btop, neovim
(forky+/resolute), neovim-runtime, tree-sitter-cli, git, curl, build-essential,
unzip, ripgrep, fd-find, fzf, zoxide, eza, bat, lazygit, nautilus,
python3-nautilus, gir1.2-nautilus-4.0 (trixie) / gir1.2-nautilus-4.1 (forky+),
nodejs, npm, python3-pip, pipx, pipewire, pipewire-audio, pipewire-alsa,
pipewire-pulse, libspa-0.2-bluetooth, mpv, mpv-mpris, chromium, golang-go /
golang-1.26 (trixie-bpo), qml6-module-qtquick, qml6-module-qtquick-controls,
qml6-module-qtquick-effects, qml6-module-qtquick-templates, quickemu,
qemu-system-x86, qemu-system-gui, qemu-utils, ovmf, swtpm, swtpm-tools,
spice-client-gtk, virt-viewer, xorriso, genisoimage, libsecret-tools,
openssh-client, zenity, wl-clipboard, xdg-utils, 7zip, poppler-utils, resvg,
libarchive-tools.

Build-only (archive): cmake, cpio, debhelper, pkgconf, hyprland-protocols,
hyprwayland-scanner, hyprwire-scanner, libaquamarine-dev, libhyprutils-dev,
libhyprlang-dev, libhyprcursor-dev, libhyprgraphics-dev, libhyprwire-dev,
libhyprtoolkit-dev, liblua5.5-dev, libcairo-dev, libcairo2-dev, libdrm-dev,
libxkbcommon-dev, libegl-dev, libegl1-mesa-dev, libeis-dev, libgbm-dev,
libglaze-dev, libgles-dev, glslang-dev, glslang-tools, libinput-dev,
liblcms2-dev, libmuparser-dev, libpango1.0-dev, libpixman-1-dev, libre2-dev,
libseat-dev, libtomlplusplus-dev, libudev-dev, libudis86-dev, libwayland-dev,
libxcb1-dev, libxcb-render0-dev, libxcb-xfixes0-dev, libxcb-icccm4-dev,
libxcb-composite0-dev, libxcb-res0-dev, libxcb-errors-dev, libssl-dev,
wayland-protocols (>= 1.49), libxcursor-dev, xxd, hwdata, libdisplay-info-dev,
libpugixml-dev, libffi-dev, librsvg2-dev, libzip-dev, libheif-dev, libjpeg-dev,
libjxl-dev, libmagic-dev, libspng-dev, libwebp-dev, libabsl-dev, libgtest-dev,
libiniparser-dev, libpolkit-agent-1-dev, libsdbus-c++-dev, libpipewire-0.3-dev,
libspa-0.2-dev, qt6-base-dev, uuid-dev, libcanberra-dev, g++-16
(forky/sid/resolute), cargo, rustc, clang, libclang-dev, golang-go,
libdbus-1-dev, libsystemd-dev, libglib2.0-dev, libgtk-4-dev,
libgtk4-layer-shell-dev, libxcb-cursor-dev, fish, xcur2png, git.

Built and packaged by Ryoku (in no suite, or too old in the chosen suite):
hyprland stack on trixie (lua5.5, libinput >= 1.29, wayland-protocols 1.49,
hyprland 0.56.x, gcc-16 per the trixie question) and on resolute (about 15 hypr
sources), the plugin debs (ryoku-hypr-plugins, hypr-dynamic-cursors, hyprglass,
imgborders, ryoku-keysounds), hyprland-preview-share-picker, niri (>= 26.04),
xwayland-satellite (0.8.3), ryoku-cursors (Bibata 2.0.7), ryoku-cursor-material,
vimix-cursors, adw-gtk-theme (adw-gtk3 6.5), fonts (Space Grotesk outside
resolute, Maple Mono NF, JetBrainsMono/FiraCode/Hack/SpaceMono Nerd Font,
Material Symbols, Fraunces), yazi (upstream .deb v26.9.1), mise,
zsh-history-substring-search (v1.1.0), ryoku-oh-my-zsh (ohmyzsh 4b65740), ble.sh
(trixie only), neovim >= 0.11.2 + tree-sitter-cli >= 0.26.1 (trixie only),
ghostty (optional), pipewire with AAC (optional), optional cursor extras
(phinger, catppuccin, apple).

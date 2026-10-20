# Agent brief: Ryoku -> Debian port deep dive

Source repo (READ-ONLY, never modify): `/home/me/src/ryokudebian-installer`,
pinned at commit `98a0368253d9628be72b853985878a5db90e1547` (2026-09-26, version
0.75.5-beta.20). Ryoku is an Arch Linux distro: Hyprland or niri desktop,
Quickshell/QML shell, Go daemons/CLI, Go TUI installer, archiso ISO, signed
`[ryoku]` pacman repo.

Goal of the port: reproduce Ryoku 100% (same look, feel, behaviour) on a Debian
base: Debian 13 trixie (+backports), Debian testing (forky) / sid, or Ubuntu
26.04 (resolute). The base is NOT decided yet; report facts for all of them.

## The question for every component

1. Does it work on Debian as-is? YES / PARTIAL / NO.
2. If not: the exact steps to make it work the same way it does on Arch.
3. Viability, feasibility, complexity, and every issue that would waste time
   later if not raised now.

"Not packaged in Debian/Ubuntu" is never a blocker: it becomes a build-from-
source + package-as-.deb step (upstream URL, version/tag Ryoku expects, build
system, build deps by Debian package name, build commands, install paths).

## Rules

- Facts only. No opinions on whether to do it, no "consider", no advice that is
  not a step toward the port. Every claim about Ryoku cites `path:line`.
- Things that are genuinely the human's decision go under "Questions for the
  human", phrased as a decision with the options and their concrete
  consequences.
- Issues, complexities, unforeseen problems: raise them plainly under "Issues /
  risks". That is the point of this pass.
- NEVER install packages on this host (no apt/pip/npm/cargo install, no sudo).
  Never modify `/home/me/src/ryokudebian-installer`. Read-only investigation
  plus writing your assigned output file(s).
- Debian/Ubuntu availability: use
  `/home/me/src/ryokudebian-installer/tools/pkgver <pkg> [pkg...]` (batch many
  names per call). It prints trixie, trixie-bpo, forky, sid, resolute versions.
  Use Debian names; when unsure of the Debian name, try candidates or query
  `https://sources.debian.org/api/search/<name>/` or
  `https://packages.debian.org/search?keywords=<name>&searchon=names&suite=all`.
- Upstream versions: `git ls-remote --tags <url>` or the GitHub API via
  `gh api`.
- Navigation: `prowl-agent search|find|def|outline|references` (run from
  /home/me/src/ryokudebian-installer) is faster than grepping blind; grep for
  literals.
- Known Debian-vs-Arch differences to check everywhere: Qt6 QML dir is
  `/usr/lib/x86_64-linux-gnu/qt6/qml` (Arch: `/usr/lib/qt6/qml`); Qt6 tools
  (`qsb`, `qmllint`) live in `/usr/lib/qt6/bin` and package names differ;
  `/usr/lib/<multiarch>` vs `/usr/lib`; package names (e.g. `base-devel`, `-dev`
  split); `/etc/os-release` ID checks; pacman/makepkg/yay/paru/
  pacman-key/paccache/reflector/archlinux-keyring/mkinitcpio/archiso/
  arch-chroot/genfstab/pacstrap calls; pacman hooks (`*.hook`) vs dpkg triggers
  / apt hooks; `multilib`; systemd unit or binary names that differ (e.g.
  `fd`->`fdfind`, `bat`->`batcat`); `/usr/share/libalpm`; AUR.

## Output format (Markdown, one file, path given in your task)

Start with a one-paragraph scope line and a summary table:
`| Component | Path | As-is on Debian | Complexity | Blocking issues |`

Then one section per component:

```markdown
### <Component> (`path`)

**What it does:** ... (cites) **Arch couplings:** bullet per coupling,
`path:line`, what it calls/assumes. **Dependencies:** table
`| Arch pkg | Used for (cite) | Debian/Ubuntu pkg | trixie | trixie-bpo | forky | sid | resolute | Min version Ryoku needs (why, cite) |`
**As-is on Debian:** YES/PARTIAL/NO, one line. **Port steps:** numbered, exact:
commands, file edits (old -> new), paths, build recipes for anything missing.
**Complexity:** Low/Medium/High + one line. **Issues / risks:** ... **Questions
for the human:** ... (omit if none)
```

End with: "Cross-cutting findings" (things other subsystems must know) and a
flat list of every Debian package name your section needs (for the master
package list).

Be exhaustive within your scope. Read the code, not just the docs: docs can be
stale; where code and docs disagree, report both with cites. Your final reply to
the coordinator: 10 lines max (file written, top blocking issues, questions).

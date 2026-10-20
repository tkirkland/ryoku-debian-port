# Future work

Ideas worth doing that are not part of the current phase. Each entry says what
it is, why it is worth it, and what it depends on. Nothing here is scheduled.

## Automated upstream-version PRs for the Hyprland stack

**What:** a scheduled job checks every stack component (Hyprland, hyprutils,
aquamarine, hyprlang, hyprcursor, hyprgraphics, hyprwayland-scanner, xdph,
hyprlock, hypridle, ...) for a newer release tag, bumps the pinned version in
the monorepo, and opens a pull request. The PR's check is the full stack build,
so it stays red until the whole set compiles and links.

**Two ways to build it:**

- Renovate with a regex manager tracking GitHub release tags in a version table
  kept in the repo. No custom code; grouping must be configured so related
  components land in one PR.
- A scheduled GitHub Action of our own: query the releases API per component,
  compare with the pinned table, push a bump branch, open the PR. More code,
  full control over grouping.

**The rule the checker must enforce:** a Hyprland release drives the bump of
the whole stack. A library release on its own (hyprutils, aquamarine) only
opens a PR if the currently pinned Hyprland still builds against it. In July
2026 hyprutils 0.14 and aquamarine 0.13 released ahead of the Hyprland that
consumed them, bumped their sonames, and a per-component bump would have merged
an unloadable compositor.

**Depends on:** D-07 (decided: one native monorepo source, 2026-10-20), the
stack build job existing in CI, and a pinned version table the checker can
rewrite.

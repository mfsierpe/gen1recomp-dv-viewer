# DV Viewer

DV Viewer shows every Pokémon's hidden DVs and Stat Exp on a third STATS page,
graded GREAT / GOOD / OK / POOR, and opens that page the moment you catch
something, so you can tell at a glance whether a catch is worth keeping.

It is for players of the [Gen 1 recomp engine](https://github.com/bryanthaboi/gen1recomp)
(Red, Blue and Yellow) who want to judge their Pokémon without a calculator.

## Try it

1. Download `dv_viewer-<version>.zip` from the [latest release](https://github.com/mfsierpe/gen1recomp-dv-viewer/releases/latest).
2. In the launcher, **MODS → Import mod .zip**, then make sure **DV Viewer** is on.
3. Start your game, then **START → POKéMON → STATS** and press **A** twice.

DV Viewer is not in the launcher's **Find** tab yet: its listing in the
[mod index](https://github.com/bryanthaboi/gen1recomp-mod-index) is waiting for
review in [PR #341](https://github.com/bryanthaboi/gen1recomp-mod-index/pull/341).
Until it is merged, install it from the release zip as above. Either way, the
manifest names this repo, so the launcher's **Update** button picks up new
releases on its own.

## What it shows

| Where | What |
|---|---|
| Right after a catch | The new Pokémon's DV page opens after the nickname question (party or PC box). One press of A closes it and the battle ends as usual. |
| STATS screen, page 3 | A on the moves page now opens the DV page instead of closing. A again closes it. Works from the party menu and the PC. |

On the page:

- **DV** (0–15) for HP, Attack, Defense, Speed and Special. HP's DV is not
  stored in Gen 1; it is built from the low bit of the other four, and the page
  shows the value the stat formula actually uses.
- **Stat Exp** (0–65,535 per stat), which grows with every Pokémon it defeats.
  A fresh catch always starts at 0.
- A ★ next to any perfect 15.
- **DV TOTAL** out of 60 (Attack + Defense + Speed + Special; HP is left out
  because it is derived from the other four) and a grade:

| Total | Grade | Wild odds |
|---|---|---|
| 45–60 | GREAT | about 1 in 17 |
| 40–44 | GOOD | about 1 in 10 |
| 25–39 | OK | about half |
| 0–24 | POOR | about 1 in 4 |

DV Viewer only reads. It never changes a Pokémon's DVs, Stat Exp or stats.

## Compatibility

- Gen 1 games only (Red, Blue, Yellow); engine 0.3.97 or newer.
- Needs the `engine_internals` permission: it adds a page to the built-in
  STATS screen (`src/ui/SummaryMenu.lua`).
- Link play is unaffected (`affects_link: false`).
- Tested alongside Shiny Pokemon, which also draws on the STATS screen. A mod
  that replaces the STATS screen outright will not show page 3.

## Development

The tests use the engine's ROM-free mod test kit, so they need a checkout of
[gen1recomp](https://github.com/bryanthaboi/gen1recomp) and LuaJIT. From the
root of that checkout:

```sh
luajit /path/to/gen1recomp-dv-viewer/tests/dv_viewer_test.lua
```

`tests/` is left out of the release zip (`.gitattributes`, `.modkitignore`).
Bumping `version` in `manifest.json` and pushing to `main` publishes a release
through `.github/workflows/release.yml`.

## License

[MIT](LICENSE) © 2026 mfsierpe

# <REPO>

A KiCad project, version-controlled with the
[kicad-git-starter](https://github.com/<OWNER>/kicad-git-starter) setup.

## Working on it

```bash
# save and close KiCad first, so the board is written and the .lck is gone
git switch -c feature/thing
git add -A
git commit -m "Add 3V3 regulator and decoupling"
git push -u origin HEAD
gh pr create --fill
```

The pull request gets an **interactive visual diff** of the schematic and the
layout, linked from a comment. `main` takes changes through pull requests only.

Tag revisions you actually send to fabrication — a tag is what makes "which
files did we build?" answerable a year later:

```bash
git tag -a rev-a -m "Sent to JLCPCB"
git push --tags
```

## Three habits specific to KiCad

**Close KiCad — or at least save — before committing.** KiCad holds edits in
memory and writes on save. Committing mid-edit captures a half-state that
doesn't match your screen.

**Commit the schematic and the layout together.** `.kicad_sch` and `.kicad_pcb`
share net and footprint identity. A schematic change without the matching layout
update is a broken state you can't cleanly return to.

**Don't expect merges to work on `.kicad_pcb`.** Because the files are text, git
*will* merge two divergent layouts and can produce a valid file with nonsense
geometry: overlapping footprints, traces to nowhere, silently dropped zones.
That's worse than a conflict, because nothing warns you. Branch freely for
schematic work, keep layout work linear, and redo a diverged layout rather than
merging it.

## What's tracked, and what isn't

Tracked: `*.kicad_pro`, `*.kicad_sch`, `*.kicad_pcb`, `*.kicad_dru`, and any
project-specific `*.kicad_sym` / `*.kicad_mod`.

Ignored: lock files, `*.kicad_prl` (per-user view settings), `*-backups/`,
autosaves, `fp-info-cache`, netlists and fabrication output. The rule of thumb:
**if KiCad can regenerate it, don't commit it.**

Two checks enforce that, since `.gitignore` alone doesn't stop `git add -f`:

- **Repo file check** on every PR — fails on personal or backup files, and
  leaves a ⚠️ comment (without blocking) when a PR adds gerbers or other fab
  output, so it's a conscious decision.
- **`.githooks/pre-commit`** locally, which refuses the commit before it's made.
  It's already enabled here. In any *other* clone of this repo, turn it on once
  with `git config core.hooksPath .githooks`.

## Automated previews

| Workflow | Trigger | Produces |
|---|---|---|
| `kicad-export.yml` | push to `main` | Schematic SVG/PDF and board PNGs, published to the `previews` branch |
| `kicad-diff.yml` | pull request | Interactive KiRi diff vs `main`, plus red/green PDFs |
| `kicad-pages.yml` | after a diff run | Publishes the diff sites to GitHub Pages |
| `repo-hygiene.yml` | pull request | The Repo file check |

Each open PR gets a page at
`https://<OWNER>.github.io/<REPO>/pr-<number>/`.

### Latest render of `main`

These appear after the first run of the export workflow.

**Schematic** ([PDF](https://github.com/<OWNER>/<REPO>/raw/previews/schematic/schematic.pdf))

![Schematic](https://github.com/<OWNER>/<REPO>/raw/previews/schematic/schematic.svg)

**PCB**

| Top | Bottom |
|---|---|
| ![PCB top](https://github.com/<OWNER>/<REPO>/raw/previews/pcb/pcb-top.png) | ![PCB bottom](https://github.com/<OWNER>/<REPO>/raw/previews/pcb/pcb-bottom.png) |

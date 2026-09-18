# <REPO>

A KiCad project, version-controlled with the visual-diff half of the
[kicad-git-starter](https://github.com/<OWNER>/kicad-git-starter) setup.

<!-- kicad-git-usage -->
## Using this repo

```bash
# save and close KiCad first, so the board is written and the .lck is gone
git switch -c feature/thing
git add -A
git commit -m "Add 3V3 regulator and decoupling"
git push -u origin HEAD
gh pr create --fill
```

The pull request gets an **interactive visual diff** of the schematic and the
layout, linked from a comment. Each open PR gets a page at
`https://<OWNER>.github.io/<REPO>/pr-<number>/`, plus red/green PDFs as a
downloadable build artifact.

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

## Workflows

| Workflow | Trigger | Produces |
|---|---|---|
| `kicad-diff.yml` | pull request | Interactive KiRi diff vs `main`, plus red/green PDFs |
| `kicad-pages.yml` | after a diff run | Publishes the diff sites to GitHub Pages |

This repo was set up with `--visual-diff-only`, so it has no "Repo file check"
workflow, no pre-commit hook, no branch protection and no rendered previews of
`main`. To add them later, run `kicad-git-init.sh --no-create` here.

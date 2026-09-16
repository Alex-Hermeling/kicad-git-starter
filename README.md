# kicad-git-starter

Turns any KiCad project folder into a GitHub repo with visual diffs on pull
requests, rendered previews of `main`, and a check that keeps lock files,
backups and other personal junk out of the repo.

One command per project:

```bash
cd ~/KiCad/projects/MyBoard
kicad-git-init.sh
```

About 30 seconds later that folder is a GitHub repo with CI running, `main`
protected, and a pre-commit hook installed.

---

## One-time setup on a machine

```bash
brew install gh && gh auth login
git clone git@github.com:<OWNER>/kicad-git-starter.git ~/KiCad/kicad-git-starter
ln -s ~/KiCad/kicad-git-starter/bootstrap/kicad-git-init.sh /opt/homebrew/bin/kicad-git-init.sh
```

`git pull` in that clone updates the command everywhere.

## Starting a new project

1. **KiCad → File → New Project**, e.g. `~/KiCad/projects/MyBoard`.
2. Draw something, save, **close KiCad** (that clears the `.lck` file).
3. `cd ~/KiCad/projects/MyBoard && kicad-git-init.sh`

For a project that already has a GitHub remote, use `kicad-git-init.sh --no-create`:
it adds the workflows, hook and ruleset without touching the remote.

Useful flags: `--dry-run` (show everything, change nothing), `--force`
(overwrite files that are already there), `--private`, `--project <path>`.

## What a project gets

| File | What it does |
|---|---|
| `.github/workflows/kicad-export.yml` | On push to `main`: renders the schematic (SVG/PDF) and board (PNG) and publishes them to a `previews` branch, so the README can show the current state |
| `.github/workflows/kicad-diff.yml` | On every PR: an interactive [KiRi](https://github.com/leoheck/kiri) diff of the schematic and layout, published to Pages and linked from a PR comment |
| `.github/workflows/kicad-pages.yml` | Publishes those diff sites to GitHub Pages |
| `.github/workflows/repo-hygiene.yml` | The **Repo file check**: fails a PR that adds lock files, `.kicad_prl`, backups or OS junk; warns on gerbers without blocking |
| `.githooks/pre-commit` | The same rules locally, before a commit is made |
| `.gitignore`, `.gitattributes` | KiCad-aware ignores, and LF text handling so board files stay diffable |
| `.kibot/*.yml` | KiBot configs behind the previews and diffs |

`bootstrap/ruleset.json` is the branch protection the script applies to `main`:
pull requests required, **Repo file check** required, force-pushes and branch
deletion blocked.

## How CI finds your board

`.github/scripts/find-kicad-project.sh` looks for the single `*.kicad_pro` in the
repo, at any depth, and derives the schematic and board paths from it. If a repo
holds more than one project, commit a `.kicad-ci.env` at the root:

```sh
PROJECT=hardware/mainboard
```

It never guesses: with several projects and no `.kicad-ci.env`, the workflow
fails with a message listing the candidates.

## Repo file check

| Result | Files |
|---|---|
| ❌ Blocked | `*.lck`, `*.kicad_prl`, `*-backups/`, `_autosave-*`, `*.bak` / `*-bak`, `fp-info-cache`, `.DS_Store` / `Thumbs.db` |
| ⚠️ Warning only | Gerbers, drill files, `*.pos` / `*-pos.csv`, `*-bom.csv`, `*.zip`, `*.net`, anything in `gerbers/`, `production/`, `fab/`, `kibot-output/` |

Fabrication output is a warning rather than an error on purpose: committing it
for a revision you actually ordered is legitimate, so the check leaves a comment
asking for confirmation instead of blocking the merge.

The rules live in `.github/scripts/check-repo-files.sh`, shared by the workflow
and the hook. To skip the hook once: `git commit --no-verify`.

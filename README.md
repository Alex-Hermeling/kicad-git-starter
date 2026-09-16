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

**Requirements:** `git`, the [GitHub CLI](https://cli.github.com) (`gh`), and a
GitHub account. The examples use macOS and Homebrew paths; Linux works the same
way with a different directory for the symlink. The CI renders with KiBot, using
the KiCad 10 file format.

---

## 1. One-time setup on a machine

```bash
brew install gh
gh auth login
```

For `gh auth login`, choose **GitHub.com → SSH → your key → Login with a web
browser**. If the key is already on your GitHub account, pick **Skip** when it
offers to upload it.

Then clone this repository — copy the URL from its green **Code** button — and
put the command on your PATH:

```bash
git clone https://github.com/OWNER/kicad-git-starter.git ~/KiCad/kicad-git-starter
ln -s ~/KiCad/kicad-git-starter/bootstrap/kicad-git-init.sh /opt/homebrew/bin/kicad-git-init.sh
```

`/opt/homebrew/bin` is the Homebrew path on Apple silicon. Use `/usr/local/bin`,
`~/.local/bin`, or any other directory on your `PATH` instead.

Check it worked:

```bash
kicad-git-init.sh --help
```

If that prints the usage text, you're done. `git pull` in
`~/KiCad/kicad-git-starter` updates the command everywhere, because the PATH
entry is a symlink into that clone.

## 2. Starting a new project

1. **KiCad → File → New Project**, e.g. `~/KiCad/projects/MyBoard`.
2. Draw something, save, and **close KiCad** — that clears the `.lck` lock file.
3. Run it:

```bash
cd ~/KiCad/projects/MyBoard
kicad-git-init.sh
```

The repo is named after the folder. Want to see what it would do first? Add
`--dry-run`: it prints every action and changes nothing.

What it does, in order: finds your `.kicad_pro`, copies in the workflows,
`.gitignore`, `.gitattributes` and hook, runs `git init`, enables the hook,
checks that nothing personal is about to be committed, commits, creates the
GitHub repo and pushes, applies branch protection to `main`, and enables Pages.

## 3. Everyday use

```bash
git switch -c feature/thing      # branch (close KiCad first)
git add -A && git commit -m "Add 3V3 regulator"
git push -u origin HEAD
gh pr create --fill
```

The PR gets an interactive visual diff of the schematic and layout. Merging
needs the **Repo file check** to pass.

## Options

| Flag | Use it when |
|---|---|
| `--dry-run` | You want to see the plan without changing anything |
| `--no-create` | The project is already on GitHub — adds the CI, hook and ruleset to the existing repo |
| `--private` | The GitHub repo should be private (default is public) |
| `--project <path>` | The repo holds more than one `.kicad_pro`; also writes `.kicad-ci.env` |
| `--force` | Overwrite starter files that are already in the folder |

By default nothing existing is overwritten: a file that's already there is kept
and reported as "kept existing …".

## Adding this to a project that already uses git

```bash
cd ~/KiCad/projects/OldBoard
kicad-git-init.sh --no-create
```

It adds the machinery, commits it, pushes, and applies the ruleset. If the
project already tracks files that shouldn't be there, it stops and prints the
exact `git rm --cached` command to fix them first.

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
| `README.md` | A starting README for the project, with your owner/repo filled in |

`bootstrap/ruleset.json` is the branch protection applied to `main`: pull
requests required, **Repo file check** required, force-pushes and branch
deletion blocked. Rulesets are *not* copied by GitHub's "template repository"
feature, which is why this is a script rather than a template repo.

## What it deliberately doesn't do

- **Create board files.** Make the project in KiCad; the script refuses to run
  where there's no `.kicad_pro`.
- **Touch your existing files** without `--force`.
- **Help you merge layouts.** Git will happily merge two divergent `.kicad_pcb`
  files into valid-looking nonsense. Keep layout work linear.

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

## Troubleshooting

**`gh is not logged in`** — run `gh auth login`.

**`No .kicad_pro found in this repo`** — you're in the wrong folder, or the
project hasn't been created in KiCad yet.

**`Found 2 KiCad projects`** — the message lists them; commit a `.kicad-ci.env`
naming the one CI should use, or rerun with `--project <path>`.

**The hook blocked a commit** — that's it working. Follow the printed
`git rm --cached` line. To override deliberately: `git commit --no-verify`.

**The first PR warns that it couldn't start the Pages deploy** — normal. The
deploy workflow has to be on `main` before it can be triggered, so it works from
the second PR onwards.

**Diff pages don't appear** — check Settings → Pages → Source is **GitHub
Actions**. The script sets this, but it can't if Pages is disabled org-wide.

**A PR from a fork gets no comment or diff site** — intended. Fork PRs get a
read-only token, so they only get the downloadable PDF artifact.

**Branch protection didn't apply** — the script skips it if a ruleset named
"Main PR Rules" already exists. Check Settings → Rules → Rulesets.

## Status

The detection script, the file checks, the hook and `--dry-run` are tested. The
live path — `gh repo create`, the ruleset and Pages API calls, and a real KiBot
run using the detected paths — is lifted from a repo where it works, but hasn't
been run end to end from this script yet. Use `--dry-run` first on your next
board.

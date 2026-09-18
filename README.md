# kicad-git-starter

Turns any KiCad project folder into a GitHub repo with visual diffs on pull
requests, rendered previews of `main`, and a check that keeps lock files,
backups and other personal junk out of the repo.


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

Then clone this repository (this assumes KiCad is already installed):

```bash
git clone https://github.com/Alex-Hermeling/kicad-git-starter.git ~/KiCad/kicad-git-starter
ln -s ~/KiCad/kicad-git-starter/bootstrap/kicad-git-init.sh /opt/homebrew/bin/kicad-git-init.sh
```

`/opt/homebrew/bin` is the Homebrew path on Apple Silicon. Use `/usr/local/bin`,
`~/.local/bin`, or any other directory on your `PATH` instead.

Check it worked:

```bash
kicad-git-init.sh --help
```

If that prints the usage text, you're done. `git pull` in
`~/KiCad/kicad-git-starter` updates the command everywhere, because the PATH
entry is a symlink into that clone.

## 2. Running the script

`kicad-git-init.sh` always runs **from inside a KiCad project folder**. It never
creates board files, so make the project in KiCad first, save it, and close
KiCad — that clears the `.lck` lock file.

```
Usage: kicad-git-init.sh [options]

  --dry-run           Show what would happen, change nothing
  --visual-diff-only  Install only the PR visual diff (no hygiene check,
                      pre-commit hook, branch protection or main previews)
  --force             Overwrite starter files that already exist here
  --no-create         Don't create a GitHub repo (use for an existing remote)
  --private           Create the GitHub repo private (default: public)
  --project <path>    Use this .kicad_pro when the repo holds several
  -h, --help          This message
```

The GitHub repo is named after the folder you run it in, so
`~/KiCad/projects/MyBoard` becomes `MyBoard`.

With no flags it: finds your `.kicad_pro`, copies in the workflows,
`.gitignore`, `.gitattributes` and the hook, runs `git init -b main`, enables
the hook, checks that nothing personal is about to be committed, commits,
creates the GitHub repo and pushes, applies branch protection to `main`, and
enables Pages.

### The flags, one at a time

**`--dry-run`** — prints every action with a `[dry-run]` prefix and changes
nothing, locally or on GitHub. Nothing is copied, no repo is created. Use it the
first time on any project:

```bash
cd ~/KiCad/projects/MyBoard
kicad-git-init.sh --dry-run
```

**`--visual-diff-only`** — installs just the part that puts a visual diff on a
pull request, and nothing that enforces anything. You get `kicad-diff.yml`,
`kicad-pages.yml`, the two scripts they call, `.kibot/config_diff.yml`,
`.gitignore` and `.gitattributes` — plus the repo, the commit, the push and
GitHub Pages.

Left out: the **Repo file check** workflow, the `.githooks/pre-commit` hook, the
`main` ruleset, `kicad-export.yml` and `.kibot/config.yml`. So `main` stays
unprotected and nothing blocks a merge; open a PR anyway, because that's what
triggers the diff. The project `README.md` written in this mode describes only
what's installed.

`.gitignore` and `.gitattributes` still come along: they're what keeps lock
files out of the repo and makes the board files diff as text in the first place.
The script also still runs its one-off check that nothing personal is about to
be committed — that's a preflight before publishing, not a check installed in
the repo.

```bash
cd ~/KiCad/projects/MyBoard
kicad-git-init.sh --visual-diff-only
```

Run the script again later without the flag to add the rest.

**`--no-create`** — skips `gh repo create`. Use it when the project is already
on GitHub: the script adds the CI, hook and ruleset to the existing repo and
pushes to the remote that's already there. (If `origin` exists, creation is
skipped automatically, flag or not.)

```bash
cd ~/KiCad/projects/OldBoard
kicad-git-init.sh --no-create
```

If that project already tracks files that shouldn't be in it, the script stops
before committing and prints the exact `git rm --cached` command to fix them.

**`--private`** — creates the GitHub repo private. The default is public.
Ignored when the repo already exists.

**`--project <path>`** — picks the board when the folder holds more than one
`.kicad_pro`. Pass the path with or without the extension; the script also
writes a `.kicad-ci.env` so CI picks the same one later:

```bash
kicad-git-init.sh --project hardware/mainboard
```

**`--force`** — overwrites starter files that are already in the folder,
including `README.md`. Without it nothing existing is touched: each file is kept
and reported as `kept existing …`. Use it to pull in updated workflows after
`git pull` in your starter clone.

**`-h`, `--help`** — prints the usage text above and exits. Good for checking
the symlink works.

### Combining them

Flags combine freely. A private repo for a multi-project folder, rehearsed
first:

```bash
kicad-git-init.sh --dry-run --private --project hardware/mainboard
kicad-git-init.sh --private --project hardware/mainboard
```

`--visual-diff-only` combines with the rest too, e.g. diffs only on a board
that's already on GitHub:

```bash
kicad-git-init.sh --visual-diff-only --no-create
```

### After it finishes

The script prints the repo URL and the next commands. Day-to-day use — branching,
committing, reading the visual diff — is documented in the `README.md` it puts in
the project itself, so it's there when you come back to the board later.

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
| `README.md` | How to use the project repo — branching, PRs, the visual diff, what's tracked — with your owner/repo filled in. If the project already has a README, that section is appended to it instead |

`bootstrap/ruleset.json` is the branch protection applied to `main`: pull
requests required, **Repo file check** required, force-pushes and branch
deletion blocked. Rulesets are *not* copied by GitHub's "template repository"
feature, which is why this is a script rather than a template repo.

With `--visual-diff-only` the table shrinks to `kicad-diff.yml`,
`kicad-pages.yml`, `.github/scripts/*`, `.kibot/config_diff.yml`, `.gitignore`,
`.gitattributes` and `README.md`; no ruleset is applied.

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

The detection script, the file checks, the hook, `--dry-run` and the README
handling (new file, appended section, skip, `--force`) are tested. The
live path — `gh repo create`, the ruleset and Pages API calls, and a real KiBot
run using the detected paths — is lifted from a repo where it works, but hasn't
been run end to end from this script yet. Use `--dry-run` first on your next
board.

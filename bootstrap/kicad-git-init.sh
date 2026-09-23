#!/usr/bin/env bash
# Turns a KiCad project folder into a git repo with the full CI setup:
# KiBot previews, KiRi visual diffs on PRs, the "Repo file check" hygiene gate,
# a pre-commit hook, a protected main branch and GitHub Pages.
#
#   cd ~/KiCad/projects/MyBoard && kicad-git-init.sh
#
# With --visual-diff-only it installs just the PR visual diff and the README
# previews of main: no hygiene check, no pre-commit hook, no branch protection.
#
# It never creates board files: make the project in KiCad first.
# See README.md in the starter repo for the one-time setup.

set -euo pipefail

# Only needed when this script runs outside a clone of the starter repo.
# Point it at your own copy: export KICAD_GIT_STARTER_REPO=<owner>/<repo>
STARTER_REPO="${KICAD_GIT_STARTER_REPO:-}"

force=false
create=true
dry=false
visual_diff_only=false
visibility="--public"
project_override=""

usage() {
  cat <<'EOF'
Usage: kicad-git-init.sh [options]

  --dry-run           Show what would happen, change nothing
  --visual-diff-only  Install only the PR visual diff and README previews
                      (no hygiene check, pre-commit hook or branch protection)
  --force             Overwrite starter files that already exist here
  --no-create         Don't create a GitHub repo (use for an existing remote)
  --private           Create the GitHub repo private (default: public)
  --project <path>    Use this .kicad_pro when the repo holds several
  -h, --help          This message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   dry=true ;;
    --visual-diff-only) visual_diff_only=true ;;
    --force)     force=true ;;
    --no-create) create=false ;;
    --private)   visibility="--private" ;;
    --project)   shift; project_override=${1:-} ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
run()  { if $dry; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

# --- where the starter files live -------------------------------------------
# Resolve symlinks so the PATH symlink still finds the repo it points into
src=${BASH_SOURCE[0]}
while [ -L "$src" ]; do
  dir=$(cd -P "$(dirname "$src")" && pwd)
  src=$(readlink "$src")
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
starter=$(cd -P "$(dirname "$src")/.." && pwd)
tmp_clone=""

if [ ! -f "$starter/.github/workflows/repo-hygiene.yml" ]; then
  [ -n "$STARTER_REPO" ] || die "the starter files aren't next to this script. Run it from a clone of the starter repo, or set KICAD_GIT_STARTER_REPO=<owner>/<repo>."
  say "Fetching the starter files from $STARTER_REPO"
  tmp_clone=$(mktemp -d)
  run gh repo clone "$STARTER_REPO" "$tmp_clone/starter" -- --depth 1 --quiet
  starter="$tmp_clone/starter"
  trap 'rm -rf "$tmp_clone"' EXIT
fi

# --- preflight ---------------------------------------------------------------
say "Checking prerequisites"
command -v git >/dev/null || die "git is not installed."
if ! command -v gh >/dev/null; then
  die "the GitHub CLI is not installed. Run: brew install gh && gh auth login"
fi
gh auth status >/dev/null 2>&1 || die "gh is not logged in. Run: gh auth login"
info "git and gh are ready"

project_dir=$(pwd -P)
name=$(basename "$project_dir")
case "$name" in
  *[!A-Za-z0-9._-]*) die "'$name' has characters GitHub won't take in a repo name. Rename the folder." ;;
esac

# --- find the KiCad project --------------------------------------------------
say "Looking for the KiCad project"
if [ -n "$project_override" ]; then
  pro="${project_override%.kicad_pro}.kicad_pro"
  [ -f "$pro" ] || die "$pro does not exist."
  if [ ! -f .kicad-ci.env ] || ! grep -q "^PROJECT=" .kicad-ci.env 2>/dev/null; then
    info "writing .kicad-ci.env so CI picks the same project"
    $dry || printf 'PROJECT=%s\n' "${pro%.kicad_pro}" > .kicad-ci.env
  fi
fi
bash "$starter/.github/scripts/find-kicad-project.sh" | while IFS= read -r line; do info "$line"; done

# --- copy the starter files --------------------------------------------------
say "Adding the starter files"
if $visual_diff_only; then
  # Only what the PR diff and the README previews need. .gitignore and
  # .gitattributes come along because they are what keeps lock files out and
  # makes the board files diff as text in the first place.
  files="
.gitignore
.gitattributes
.github/scripts/find-kicad-project.sh
.github/scripts/update-pr-diffs-branch.sh
.github/workflows/kicad-diff.yml
.github/workflows/kicad-export.yml
.github/workflows/kicad-pages.yml
.kibot/config.yml
.kibot/config_diff.yml
"
  info "visual diff only: skipping the hygiene check and the pre-commit hook"
else
  files="
.gitignore
.gitattributes
.githooks/pre-commit
.github/scripts/check-repo-files.sh
.github/scripts/find-kicad-project.sh
.github/scripts/update-pr-diffs-branch.sh
.github/workflows/kicad-diff.yml
.github/workflows/kicad-export.yml
.github/workflows/kicad-pages.yml
.github/workflows/repo-hygiene.yml
.kibot/config.yml
.kibot/config_diff.yml
"
fi
for f in $files; do
  if [ -e "$f" ] && ! $force; then
    info "kept existing $f"
    continue
  fi
  run mkdir -p "$(dirname "$f")"
  run cp "$starter/$f" "$f"
  info "added $f"
done

owner=$(gh api user --jq .login)
slug="$owner/$name"

# Fill in the real owner/repo so the preview image links work
subst() { sed -e "s|<OWNER>/<REPO>|$slug|g" -e "s|<OWNER>|$owner|g" -e "s|<REPO>|$name|g"; }
if $visual_diff_only; then
  readme_tpl="$starter/template/README.visual-diff.md"
else
  readme_tpl="$starter/template/README.project.md"
fi
usage_marker='<!-- kicad-git-usage -->'

if [ ! -e README.md ] || $force; then
  if $dry; then
    info "[dry-run] write README.md from template/$(basename "$readme_tpl")"
  else
    subst < "$readme_tpl" > README.md
  fi
  info "added README.md for $slug"
elif grep -qF "$usage_marker" README.md; then
  info "kept existing README.md (it already has the usage section)"
else
  # Keep the project's own README, but add the how-to-use half of the template
  # to the end of it, so the instructions are still there for the next person.
  if $dry; then
    info "[dry-run] append the usage section to the existing README.md"
  else
    { printf '\n'; awk -v m="$usage_marker" 'index($0, m) { f = 1 } f' "$readme_tpl" | subst; } >> README.md
  fi
  info "appended the usage section to your existing README.md"
fi

# --- git ---------------------------------------------------------------------
say "Setting up git"
if [ -d .git ]; then
  info "already a git repo"
else
  run git init -q -b main
  info "git init (branch main)"
fi
if $visual_diff_only; then
  info "no pre-commit hook (--visual-diff-only)"
else
  run git config core.hooksPath .githooks
  info "pre-commit hook enabled (core.hooksPath=.githooks)"
fi

# Refuse to publish someone's lock files, backups or personal settings
say "Checking for files that must not be committed"
if $dry && [ ! -d .git ]; then
  info "[dry-run] skipped: there's no git repo here yet to list files from"
else
  # .gitignore keeps most of this out; this catches anything already tracked
  # or force-added in an existing repo
  { git ls-files; git ls-files --others --exclude-standard; } | sort -u \
    | bash "$starter/.github/scripts/check-repo-files.sh" \
    || die "fix the files listed above, then run this again."
  info "nothing personal or generated is about to be committed"
  if $visual_diff_only; then
    info "(this is a one-off check before publishing; no check is installed in the repo)"
  fi
fi

say "Committing"
if $dry; then
  info "[dry-run] git add -A && git commit"
elif [ -n "$(git status --porcelain)" ]; then
  git add -A
  if $visual_diff_only; then
    msg="Add KiCad CI: visual diffs on pull requests and previews of main"
  else
    msg="Add KiCad git setup: CI previews, visual diffs and file checks"
  fi
  git commit -q --no-verify -m "$msg"
  info "committed $(git rev-parse --short HEAD)"
else
  info "nothing to commit"
fi

# --- GitHub ------------------------------------------------------------------
if git remote get-url origin >/dev/null 2>&1; then
  slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "$slug")
  say "Remote already set: $slug"
  run git push -u origin main
elif $create; then
  say "Creating github.com/$slug"
  run gh repo create "$name" "$visibility" --source . --push \
    --description "KiCad project: $name"
else
  say "Skipping repo creation (--no-create)"
fi

if $dry; then
  say "Dry run finished. Nothing was changed."
  exit 0
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  say "No remote yet, so skipping the ruleset and Pages."
  info "Create the repo, then run: kicad-git-init.sh --no-create"
  exit 0
fi

if $visual_diff_only; then
  say "Skipping branch protection (--visual-diff-only)"
  info "main takes direct pushes; open a PR anyway to get the diff"
else
  say "Protecting main"
  if gh api "repos/$slug/rulesets" --jq '.[].name' 2>/dev/null | grep -qx "Main PR Rules"; then
    info "ruleset 'Main PR Rules' already exists"
  else
    gh api --method POST "repos/$slug/rulesets" --input "$starter/bootstrap/ruleset.json" >/dev/null
    info "ruleset applied: PRs required, 'Repo file check' required, no force-push, no deletion"
  fi
fi

say "Enabling GitHub Pages"
if gh api "repos/$slug/pages" >/dev/null 2>&1; then
  info "Pages already enabled"
else
  gh api --method POST "repos/$slug/pages" -f build_type=workflow >/dev/null \
    && info "Pages set to build from GitHub Actions" \
    || info "could not enable Pages automatically; Settings -> Pages -> Source: GitHub Actions"
fi

say "Done: https://github.com/$slug"
if $visual_diff_only; then
cat <<EOF

    Next:
      1. Work on a branch:      git switch -c feature/thing
      2. Push and open a PR:    git push -u origin HEAD && gh pr create --fill
      3. The PR gets a comment linking an interactive KiRi visual diff of the
         schematic and the layout against main.

    Nothing here blocks a merge: main is unprotected and there is no file check.
    To add those later, run: kicad-git-init.sh --no-create

    Close KiCad before committing, so the .lck file is gone and the board is saved.
EOF
else
cat <<EOF

    Next:
      1. Work on a branch:      git switch -c feature/thing
      2. Push and open a PR:    git push -u origin HEAD && gh pr create --fill
      3. The PR gets an interactive KiRi visual diff, and personal or backup
         files are blocked from main.

    Close KiCad before committing, so the .lck file is gone and the board is saved.
EOF
fi

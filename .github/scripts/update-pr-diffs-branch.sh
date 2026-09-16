#!/usr/bin/env bash
# Replace or remove one pull request's KiRi site on the `pr-diffs` branch.
#
#   update-pr-diffs-branch.sh <pr-number> [<site dir>]
#
# With a site dir, its contents become pr-<number>/ on the branch.
# Without one, pr-<number>/ is deleted (used when the PR is closed).
# Either way, index.html at the branch root is regenerated to list the open PRs.
#
# The branch is rewritten as a single orphan commit every time, so sites from
# old pushes and closed PRs never pile up in the repository's history.
# kicad-pages.yml publishes the branch to GitHub Pages.
#
# Needs GITHUB_TOKEN (contents: write) and GITHUB_REPOSITORY.
set -euo pipefail

pr="$1"
src="${2:-}"
[ -n "$src" ] && src=$(cd "$src" && pwd)

branch=pr-diffs
remote="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
work="${RUNNER_TEMP:-/tmp}/pr-diffs-work"

write_landing_page() {
  local dirs n
  dirs=$(ls -d pr-*/ 2>/dev/null | sed 's#^pr-##; s#/$##' | sort -n) || true
  {
    echo '<!doctype html>'
    echo '<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
    echo '<title>KiCad visual diffs</title>'
    echo '<style>body{font:16px/1.5 system-ui,sans-serif;max-width:40rem;margin:2rem auto;padding:0 1rem}</style>'
    echo '<h1>KiCad visual diffs</h1>'
    if [ -n "$dirs" ]; then
      echo '<ul>'
      for n in $dirs; do
        echo "<li><a href=\"pr-$n/\">Pull request #$n</a> (<a href=\"https://github.com/${GITHUB_REPOSITORY}/pull/$n\">on GitHub</a>)</li>"
      done
      echo '</ul>'
    else
      echo '<p>No open pull requests with a diff.</p>'
    fi
  } > index.html
}

# Two PRs can publish at the same moment. The push is guarded with
# --force-with-lease, so the loser retries on top of the winner's commit.
for attempt in 1 2 3 4 5; do
  cd /
  rm -rf "$work"
  git init -q "$work"
  cd "$work"
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  old=""
  if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null; then
    git fetch -q --depth 1 "$remote" "refs/heads/$branch"
    old=$(git rev-parse FETCH_HEAD)
    git read-tree -u --reset FETCH_HEAD
  elif [ -z "$src" ]; then
    echo "No $branch branch, nothing to remove."
    exit 0
  fi

  rm -rf "pr-$pr"
  if [ -n "$src" ]; then
    mkdir -p "pr-$pr"
    cp -r "$src"/. "pr-$pr"/
    message="KiRi site for PR #$pr"
  else
    message="Remove KiRi site for closed PR #$pr"
  fi
  write_landing_page

  git add -A
  commit=$(git commit-tree "$(git write-tree)" -m "$message")

  if git push -q --force-with-lease="refs/heads/$branch:$old" "$remote" "$commit:refs/heads/$branch"; then
    echo "$message ($branch @ ${commit::7})"
    exit 0
  fi
  echo "$branch changed while updating (attempt $attempt), retrying..." >&2
  sleep $((attempt * 3))
done

echo "Gave up updating $branch after 5 attempts." >&2
exit 1

#!/usr/bin/env bash
# Checks repo paths for files that must never reach main (KiCad lock files,
# per-user settings, backups, OS junk) and for fabrication output that is only
# sometimes intentional (gerbers, drill files, BOM / placement exports).
#
# Usage:  <paths, one per line> | check-repo-files.sh [--github]
#
#   Exits 1 if any path is blocked, 0 otherwise. Warnings never fail.
#   --github  also emits workflow annotations, writes a Markdown report to
#             $REPORT_FILE and blocked= / warned= counts to $GITHUB_OUTPUT.
#
# Used by .github/workflows/repo-hygiene.yml and .githooks/pre-commit.

set -eo pipefail

github=false
[ "${1:-}" = "--github" ] && github=true

# Gerber extensions are often upper case (e.g. board.GTL)
shopt -s nocasematch

# Prints "block <reason>", "warn <reason>" or nothing
classify() {
  local path=$1 name=${1##*/}

  case "$path" in
    *.lck)              echo "block KiCad lock file (contains your user and host name)"; return ;;
    *.kicad_prl)        echo "block Per-user KiCad settings (visible layers, zoom, window layout)"; return ;;
    *-backups/*)        echo "block KiCad automatic backup"; return ;;
    *.kicad_sch-bak|*.kicad_pcb-bak|*.bak|*~)
                        echo "block Backup file"; return ;;
  esac
  case "$name" in
    _autosave-*)        echo "block KiCad autosave file"; return ;;
    fp-info-cache)      echo "block KiCad footprint cache"; return ;;
    .DS_Store|Thumbs.db|desktop.ini)
                        echo "block Operating system metadata"; return ;;
  esac

  case "$path" in
    *.gbr|*.gbrjob|*.gtl|*.gbl|*.gts|*.gbs|*.gto|*.gbo|*.gtp|*.gbp|*.gko|*.gm[0-9]*|*.g[0-9])
                        echo "warn Gerber file" ;;
    *.drl|*.xln|*.exc)  echo "warn Drill file" ;;
    *.pos|*-pos.csv)    echo "warn Pick-and-place file" ;;
    *-bom.csv)          echo "warn BOM export" ;;
    *.zip)              echo "warn Zip archive (fab upload?)" ;;
    *.net)              echo "warn Netlist (regenerated from the schematic)" ;;
    gerbers/*|*/gerbers/*|production/*|*/production/*|fab/*|*/fab/*)
                        echo "warn File in a fabrication output folder" ;;
    kibot-output/*|kibot-diff/*)
                        echo "warn KiBot output (CI generates this)" ;;
  esac
}

n_blocked=0
n_warned=0
blocked_txt=""
warned_txt=""
blocked_md=""
warned_md=""
rm_args=""

while IFS= read -r path || [ -n "$path" ]; do
  [ -n "$path" ] || continue
  result=$(classify "$path")
  kind=${result%% *}
  reason=${result#* }

  case "$kind" in
    block)
      n_blocked=$((n_blocked + 1))
      blocked_txt+="    $path  ($reason)"$'\n'
      blocked_md+="| \`$path\` | $reason |"$'\n'
      rm_args+=" '$path'"
      if $github; then
        echo "::error file=$path,title=File must not be merged::$reason"
      fi
      ;;
    warn)
      n_warned=$((n_warned + 1))
      warned_txt+="    $path  ($reason)"$'\n'
      warned_md+="| \`$path\` | $reason |"$'\n'
      if $github; then
        echo "::warning file=$path,title=Fabrication output::$reason. Make sure committing it is intentional."
      fi
      ;;
  esac
done

if [ "$n_blocked" -gt 0 ]; then
  {
    echo "✖ These files must not be committed:"
    printf '%s' "$blocked_txt"
    echo "  They are personal or auto-generated, and already listed in .gitignore."
    echo "  Remove them from git (the files stay on disk) with:"
    echo "    git rm --cached --$rm_args"
    echo
  } >&2
fi

if [ "$n_warned" -gt 0 ]; then
  {
    echo "⚠ Fabrication output included. Double-check this is intentional:"
    printf '%s' "$warned_txt"
    echo "  Fine for a deliberate release; otherwise unstage it with: git rm --cached -- <file>"
    echo
  } >&2
fi

if $github; then
  {
    echo "blocked=$n_blocked"
    echo "warned=$n_warned"
  } >> "$GITHUB_OUTPUT"

  {
    echo "## Repo file check"
    echo
    if [ "$n_blocked" -eq 0 ] && [ "$n_warned" -eq 0 ]; then
      echo "✅ No personal, backup or fabrication files in this PR."
    fi

    if [ "$n_blocked" -gt 0 ]; then
      echo "### ❌ Files that must not be merged"
      echo
      echo "These are personal or auto-generated files. They are already in \`.gitignore\`, so they were added with \`git add -f\` or by a Git GUI. **This check fails until they are removed from the PR.**"
      echo
      echo "| File | Why |"
      echo "|---|---|"
      printf '%s' "$blocked_md"
      echo
      echo "Remove them from git (your local copies stay on disk):"
      echo
      echo '```sh'
      echo "git rm --cached --$rm_args"
      echo 'git commit -m "Remove personal KiCad files"'
      echo 'git push'
      echo '```'
      echo
    fi

    if [ "$n_warned" -gt 0 ]; then
      echo "### ⚠️ Fabrication output: please double-check"
      echo
      echo "This PR adds or changes generated fabrication files. That's fine for a deliberate release, but normally CI generates them and they aren't committed. **Reviewer: confirm this is intentional before merging.** This does not block the merge."
      echo
      echo "| File | Type |"
      echo "|---|---|"
      printf '%s' "$warned_md"
      echo
    fi
  } > "$REPORT_FILE"

  if [ "$n_blocked" -eq 0 ] && [ "$n_warned" -eq 0 ]; then
    echo "No personal, backup or fabrication files found."
  fi
fi

if [ "$n_blocked" -gt 0 ]; then
  exit 1
fi

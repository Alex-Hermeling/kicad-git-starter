#!/usr/bin/env bash
# Works out which KiCad project this repo holds, so the workflows don't have to
# hardcode a file name.
#
#   1. .kicad-ci.env at the repo root wins:  PROJECT=path/to/name
#   2. Otherwise: the single *.kicad_pro in the repo
#   3. None, or several with no .kicad-ci.env -> exit 1 and say so. Never guess.
#
# Prints project= / sch= / pcb= and, inside GitHub Actions, appends the same
# lines to $GITHUB_OUTPUT.

set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root"

die() { printf '%s\n' "$@" >&2; exit 1; }

pro=""
if [ -f .kicad-ci.env ]; then
  # Accept PROJECT=board, PROJECT=hw/board or PROJECT=hw/board.kicad_pro
  value=$(sed -n 's/^[[:space:]]*PROJECT[[:space:]]*=[[:space:]]*//p' .kicad-ci.env | tail -1 | tr -d '"'\''' | tr -d '\r')
  [ -n "$value" ] || die ".kicad-ci.env exists but has no PROJECT= line."
  pro="${value%.kicad_pro}.kicad_pro"
  [ -f "$pro" ] || die ".kicad-ci.env points at '$pro', which does not exist."
else
  matches=$(find . -name '*.kicad_pro' -not -path './.git/*' -not -path '*-backups/*' | sed 's|^\./||' | sort)
  count=$(printf '%s' "$matches" | grep -c . || true)
  case "$count" in
    0)
      die "No .kicad_pro found in this repo." \
          "Create the project in KiCad first, or add .kicad-ci.env with PROJECT=path/to/name."
      ;;
    1) pro="$matches" ;;
    *)
      first="${matches%%$'\n'*}"
      die "Found $count KiCad projects:" "$matches" "" \
          "Pick one by committing a .kicad-ci.env at the repo root:" \
          "    PROJECT=${first%.kicad_pro}"
      ;;
  esac
fi

base="${pro%.kicad_pro}"
sch="$base.kicad_sch"
pcb="$base.kicad_pcb"

[ -f "$sch" ] || die "Found $pro but no $sch next to it."
[ -f "$pcb" ] || die "Found $pro but no $pcb next to it."

for kv in "project=$base" "sch=$sch" "pcb=$pcb"; do
  printf '%s\n' "$kv"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s\n' "$kv" >> "$GITHUB_OUTPUT"
  fi
done

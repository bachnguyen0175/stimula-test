#!/usr/bin/env bash
# spec-slices.sh - turn an approved OpenSpec change into factory queue items.
#
#   ./.factory/scripts/spec-slices.sh <change-id>                 # preview (default)
#   ./.factory/scripts/spec-slices.sh <change-id> --apply         # create GitHub issues
#   ./.factory/scripts/spec-slices.sh <change-id> --base <ref>    # approval ref (default origin/main, else main)
#
# Approval is the merge of the spec PR. A change counts as approved only when
# openspec/changes/<id>/tasks.md exists on the base ref, and the slices are read from
# that approved copy, never from the working tree.
#
# Each "## N. Title" section of tasks.md is one slice and must declare, as blockquote lines:
#   > done_when: <checkable condition>
#   > files_expected: <comma-separated paths>
#   > load_bearing: true | false
#   > gate_level: fast | full | deep
#
# Exit codes: 0 = ok   2 = usage error, unknown change, or a slice that is not ready
#             3 = the change is not approved (not on the base ref)

set -euo pipefail

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

CHANGE=""; BASE=""; APPLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --base) [ "$#" -ge 2 ] || usage; BASE="$2"; shift ;;
    -h|--help) usage ;;
    -*) echo "error: unknown option: $1" >&2; exit 2 ;;
    *) [ -z "$CHANGE" ] || usage; CHANGE="$1" ;;
  esac
  shift
done
[ -n "$CHANGE" ] || usage
case "$CHANGE" in *[!a-z0-9-]*|-*) echo "error: change id must be kebab-case: $CHANGE" >&2; exit 2 ;; esac

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [ -z "$BASE" ]; then
  if git rev-parse --verify -q origin/main >/dev/null; then BASE="origin/main"; else BASE="main"; fi
fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "error: base ref not found: $BASE" >&2; exit 2; }

TASKS="openspec/changes/$CHANGE/tasks.md"
if ! git cat-file -e "$BASE:$TASKS" 2>/dev/null; then
  if [ -e "$TASKS" ] || git log --all --format=%H -1 -- "$TASKS" | grep -q .; then
    echo "NOT APPROVED: $TASKS is not on $BASE. Merge the spec PR first; agents never approve specs." >&2
    exit 3
  fi
  echo "error: no such OpenSpec change: $CHANGE" >&2
  exit 2
fi

OUT="$(mktemp -d "${TMPDIR:-/tmp}/spec-slices.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Split the approved tasks.md into <n>.title, <n>.body and <n>.handoff files.
git show "$BASE:$TASKS" | awk -v out="$OUT" -v change="$CHANGE" -v base="$BASE" -v now="$NOW" '
  function flush(   k, f) {
    if (n == 0) return
    for (k = 1; k <= 4; k++) {
      f = req[k]
      if (meta[f] == "") { printf "NOT READY: slice %s (%s) has no \"> %s:\" line\n", num, title, f > "/dev/stderr"; bad = 1 }
    }
    if (meta["gate_level"] !~ /^(fast|full|deep)$/ && meta["gate_level"] != "") { printf "NOT READY: slice %s gate_level must be fast, full or deep\n", num > "/dev/stderr"; bad = 1 }
    if (meta["load_bearing"] !~ /^(true|false)$/ && meta["load_bearing"] != "") { printf "NOT READY: slice %s load_bearing must be true or false\n", num > "/dev/stderr"; bad = 1 }
    printf "[%s] %s. %s\n", change, num, title > (out "/" n ".title")
    printf "Slice %s of OpenSpec change `%s`, approved by merging its spec PR into `%s`.\n\n", num, change, base > (out "/" n ".body")
    printf "spec: openspec/changes/%s/\n\n", change > (out "/" n ".body")
    printf "Read proposal.md, design.md and the delta specs under specs/ before implementing.\n\nTasks:\n%s", tasks > (out "/" n ".body")
    printf "<!-- factory-handoff:v1 -->\ndisposition: ready-to-implement\ndone_when: %s\nfiles_expected: %s\nload_bearing: %s\ngate_level: %s\nconfidence: high\nspec_change: %s\ntriaged_at: %s\n", meta["done_when"], meta["files_expected"], meta["load_bearing"], meta["gate_level"], change, now > (out "/" n ".handoff")
    close(out "/" n ".title"); close(out "/" n ".body"); close(out "/" n ".handoff")
  }
  BEGIN { split("done_when files_expected load_bearing gate_level", req, " "); n = 0; bad = 0 }
  /^## [0-9]+\. / {
    flush()
    n++; num = $2; sub(/\.$/, "", num)
    title = $0; sub(/^## [0-9]+\. /, "", title)
    delete meta; tasks = ""
    next
  }
  n > 0 && /^> [a-z_]+: / {
    key = $2; sub(/:$/, "", key)
    val = $0; sub(/^> [a-z_]+: /, "", val)
    meta[key] = val
    next
  }
  n > 0 && /^- \[[ x]\] / { tasks = tasks $0 "\n" }
  END {
    flush()
    if (n == 0) { print "NOT READY: tasks.md has no \"## N. Title\" sections" > "/dev/stderr"; exit 2 }
    if (bad) exit 2
    print n > (out "/count")
  }
'

COUNT="$(cat "$OUT/count")"
for i in $(seq 1 "$COUNT"); do
  printf '=== slice %s of %s ===\ntitle: %s\n--- issue body ---\n' "$i" "$COUNT" "$(cat "$OUT/$i.title")"
  cat "$OUT/$i.body"
  printf -- '--- handoff comment ---\n'
  cat "$OUT/$i.handoff"
  echo
done

[ "$APPLY" -eq 1 ] || { echo "(preview only; re-run with --apply to create $COUNT issue(s))"; exit 0; }

command -v gh >/dev/null 2>&1 || { echo "error: --apply needs an authenticated gh CLI" >&2; exit 2; }
# List titles rather than search: GitHub's issue search lags new issues by seconds, so a
# quick re-run would duplicate slices. If the list fails, refuse rather than guess.
existing_titles="$(gh issue list --state all --limit 1000 --json title --jq '.[].title')" || {
  echo "error: could not list existing issues to check for duplicates; nothing created" >&2
  exit 2
}
for i in $(seq 1 "$COUNT"); do
  title="$(cat "$OUT/$i.title")"
  if printf '%s\n' "$existing_titles" | grep -qxF -- "$title"; then
    echo "skip    $title (an issue with this title already exists)"
    continue
  fi
  url="$(gh issue create --title "$title" --body-file "$OUT/$i.body" --label factory:ready-to-implement)"
  number="${url##*/}"
  case "$number" in ''|*[!0-9]*) echo "error: could not read the issue number from: $url" >&2; exit 1 ;; esac
  gh issue comment "$number" --body-file "$OUT/$i.handoff" >/dev/null
  echo "created #$number  $title"
done

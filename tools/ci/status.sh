#!/usr/bin/env bash
# Short CI report for a commit, so Claude reads a few lines instead of
# polling the API again and again and pasting long logs.
#
#   tools/ci/status.sh [commit-or-branch] [--wait] [--lines N]
#
# Prints one line per job (pass / FAIL / running). For each failed job it
# prints only the lines that look like errors (max N, default 30).
# --wait: check every 60 s until no job is queued or running (max 90 min).
set -euo pipefail
REPO=yv28f5k922-dot/Gez
REF=HEAD; WAIT=0; N=30
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) WAIT=1 ;;
    --lines) N="$2"; shift ;;
    *) REF="$1" ;;
  esac
  shift
done
SHA=$(git rev-parse "$REF" 2>/dev/null || echo "$REF")

runs() { gh api "repos/$REPO/actions/runs?head_sha=$SHA" --jq '.workflow_runs[].id'; }
jobs() { gh api "repos/$REPO/actions/runs/$1/jobs?per_page=100" \
  --jq '.jobs[] | "\(.id)\t\(.status)\t\(.conclusion)\t\(.name)"'; }

for i in $(seq 1 90); do
  ALL=""
  for r in $(runs); do ALL+="$(jobs "$r")"$'\n'; done
  ALL=$(printf '%s' "$ALL" | sed '/^$/d')
  [ -z "$ALL" ] && { echo "no CI runs for ${SHA:0:7} yet"; [ $WAIT = 1 ] && { sleep 60; continue; } || exit 0; }
  BUSY=$(printf '%s\n' "$ALL" | awk -F'\t' '$2!="completed"' | wc -l)
  [ $WAIT = 1 ] && [ "$BUSY" -gt 0 ] && { sleep 60; continue; }
  break
done

echo "CI for ${SHA:0:7}:"
printf '%s\n' "$ALL" | awk -F'\t' '{
  s = ($2!="completed") ? "running" : ($3=="success" ? "pass" : ($3=="skipped" ? "skip" : ($3=="cancelled" ? "cancel" : "FAIL")));
  printf "  %-7s %s\n", s, $4 }'

printf '%s\n' "$ALL" | awk -F'\t' '$2=="completed" && $3=="failure" {print $1"\t"$4}' |
while IFS=$'\t' read -r id name; do
  echo; echo "== $name (job $id): error lines =="
  gh api "repos/$REPO/actions/jobs/$id/logs" 2>/dev/null |
    sed 's/^[0-9T:.-]*Z //' |
    grep -E "error|Error|ERROR|failed|FAIL|fatal|Fatal|XCTAssert|Parse Error|Process completed with exit code" |
    grep -v "^warning" | tail -n "$N"
done

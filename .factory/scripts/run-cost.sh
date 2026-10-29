#!/usr/bin/env bash
# run-cost.sh - estimate the models and API-equivalent cost of a Claude Code run.
#
#   ./.factory/scripts/run-cost.sh                        # newest transcript of this repo
#   ./.factory/scripts/run-cost.sh --transcript <file>    # a specific session transcript
#
# Prints run-record front-matter lines:
#   models: claude-opus-5-5, claude-sonnet-5-5
#   cost_usd_estimate: 1.2345 | unknown
#   cost_source: transcript | none
#   unpriced_models: <ids>            (only when a model has no price)
#
# Reads the session transcript plus its subagent transcripts, counts each API message once
# (transcripts log a message several times), and prices it with .factory/prices.json. This
# is an estimate at list prices: on a subscription plan it shows where usage goes, not what
# is billed. It always exits 0 so a run record can still be written; missing data prints
# "unknown", never a guessed number.

set -uo pipefail

TRANSCRIPT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --transcript) TRANSCRIPT="${2:-}"; shift ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

FACTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRICES="$FACTORY/prices.json"

unknown() {
  printf 'models: unknown\ncost_usd_estimate: unknown\ncost_source: none\n'
  [ -n "${1:-}" ] && echo "note: $1" >&2
  exit 0
}

command -v jq >/dev/null 2>&1 || unknown "jq is required"
[ -f "$PRICES" ] || unknown "missing $PRICES"

if [ -z "$TRANSCRIPT" ]; then
  # Claude Code stores transcripts under ~/.claude/projects/<repo path with / and . as ->.
  repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  dir="$HOME/.claude/projects/$(printf '%s' "$repo" | tr '/.' '--')"
  TRANSCRIPT="$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)"
fi
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || unknown "no transcript found"

files=("$TRANSCRIPT")
for sub in "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do
  [ -f "$sub" ] && files+=("$sub")
done

cat "${files[@]}" | jq -nrR --slurpfile p "$PRICES" '
  $p[0] as $P
  | [inputs | fromjson? | select(.type == "assistant" and .message.id and .message.usage)]
  | group_by(.message.id) | map(.[-1].message)
  | map(
      (.model | sub("-[0-9]{8}$"; "")) as $model
      | .usage as $u
      | (if $u.cache_creation then ($u.cache_creation.ephemeral_5m_input_tokens // 0)
         else ($u.cache_creation_input_tokens // 0) end) as $w5
      | (if $u.cache_creation then ($u.cache_creation.ephemeral_1h_input_tokens // 0) else 0 end) as $w1
      | (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0)) as $prompt
      | $P.models[$model] as $base
      | (if $base == null then null
         elif ($base.long_prompt != null and $prompt > $base.long_prompt.over_tokens) then $base.long_prompt
         else $base end) as $r
      | { model: $model,
          cost: (if $r == null then null else
            ( ($u.input_tokens // 0) * $r.input
            + ($u.output_tokens // 0) * $r.output
            + $w5 * $r.cache_write_5m
            + $w1 * $r.cache_write_1h
            + ($u.cache_read_input_tokens // 0) * $r.cache_read )
            * (if $u.inference_geo == "us" then $P.us_inference_multiplier else 1 end)
            / 1000000 end) })
  | ([.[].model] | unique) as $models
  | ([.[] | select(.cost == null) | .model] | unique) as $unpriced
  | if length == 0 then "models: unknown\ncost_usd_estimate: unknown\ncost_source: none"
    else
      "models: \($models | join(", "))\n"
      + (if ($unpriced | length) > 0
         then "cost_usd_estimate: unknown\ncost_source: transcript\nunpriced_models: \($unpriced | join(", "))"
         else "cost_usd_estimate: \(([.[].cost] | add) * 10000 | round / 10000)\ncost_source: transcript" end)
    end
' || unknown "could not read $TRANSCRIPT"

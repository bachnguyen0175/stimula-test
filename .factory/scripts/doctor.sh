#!/usr/bin/env bash
# Check whether the installed factory has enough configuration to run safely.

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2

failures=0
warnings=0

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

required_files=(
  CLAUDE.md
  docs/factory/CONTRACT.md
  docs/factory/CHARTER.md
  .factory/gates.conf
  .claude/scripts/gates.sh
)

for path in "${required_files[@]}"; do
  [ -f "$path" ] && pass "$path exists" || fail "$path is missing"
done

# The test-file guard fails closed without jq, which would block every edit.
if command -v jq >/dev/null 2>&1; then
  pass "jq is installed"
else
  fail "jq is missing; .claude/hooks/protect-tests.sh blocks all edits without it (brew install jq / apt install -y jq)"
fi

if [ -f CLAUDE.md ] && grep -q '<PROJECT NAME>\|<install>\|<One paragraph:' CLAUDE.md; then
  fail "CLAUDE.md still contains setup placeholders"
else
  pass "CLAUDE.md placeholders replaced"
fi

if [ -f docs/factory/CHARTER.md ] && grep -q '^CHARTER_STATUS: ready$' docs/factory/CHARTER.md; then
  pass "charter is marked ready"
else
  fail "charter is not marked ready"
fi

if [ -f docs/factory/CHARTER.md ] && grep -q '^TIER: \(revival\|greenfield\|oss\|client-production\)$' docs/factory/CHARTER.md; then
  pass "charter tier is valid"
else
  fail "charter tier is missing or invalid"
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  pass "Git repository detected"
  if git remote get-url origin >/dev/null 2>&1; then pass "origin remote detected"; else warn "no origin remote"; fi
else
  fail "not a Git repository"
fi

if "$(dirname "$0")/gh-auth.sh" 2>/dev/null; then
  pass "GitHub CLI authenticated"
  existing_labels="$(gh label list --limit 200 --json name --jq '.[].name' 2>/dev/null || true)"
  missing_labels=0
  for label in factory:ready-to-implement factory:ready-to-spec factory:needs-info factory:wait-to-implement factory:in-progress factory:awaiting-review; do
    printf '%s\n' "$existing_labels" | grep -qxF "$label" || missing_labels=$((missing_labels + 1))
  done
  [ "$missing_labels" -eq 0 ] && pass "live queue labels exist" || warn "$missing_labels live queue labels missing; run ./.factory/scripts/bootstrap-github.sh --apply"
else
  warn "gh is unavailable or unauthenticated; live queue checks skipped"
fi

if [ "${CLAUDE_CODE_SUBAGENT_MODEL_FORCE:-}" = "1" ]; then
  warn "CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 overrides the verifier and critic models; see docs/factory/README.md, Models per stage"
fi
# User-level and plugin hooks also run inside local factory sessions and can block or
# half-apply edits. Cloud routines don't load them. Any block goes in the run record's
# blocked_by field.
count_pretooluse='[.hooks.PreToolUse[]? | .hooks[]?] | length'

check_settings_hooks() {
  local settings="$1" count matchers
  if ! jq -e . "$settings" >/dev/null 2>&1; then
    warn "$settings is not valid JSON; user-level hooks could not be checked"
    return 1
  fi
  count="$(jq -r "$count_pretooluse" "$settings")"
  [ "$count" -gt 0 ] || return 0
  matchers="$(jq -r '[.hooks.PreToolUse[]? | .matcher // "*"] | join(", ")' "$settings")"
  warn "user-level PreToolUse hooks present ($count; matchers: $matchers) in $settings; they also run in local factory sessions and may block edits; name any block in the run record's blocked_by"
}

# Plugin hooks live in <installPath>/hooks/hooks.json. installed_plugins.json is Claude
# Code's internal registry, so an unreadable one is reported, never guessed around.
check_plugin_hooks() {
  local settings="$1" registry="$HOME/.claude/plugins/installed_plugins.json"
  local plugins plugin path count found=""
  plugins="$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings")"
  [ -n "$plugins" ] || return 0
  if ! jq -e '.plugins | type == "object"' "$registry" >/dev/null 2>&1; then
    warn "$(printf '%s\n' "$plugins" | wc -l | tr -d ' ') enabled plugins; their hooks could not be checked ($registry unreadable)"
    return 0
  fi
  while IFS= read -r plugin; do
    count=0
    while IFS= read -r path; do
      [ -f "$path/hooks/hooks.json" ] || continue
      count=$((count + $(jq -r "$count_pretooluse" "$path/hooks/hooks.json" 2>/dev/null || echo 0)))
    done < <(jq -r --arg p "$plugin" '.plugins[$p][]?.installPath // empty' "$registry")
    [ "$count" -gt 0 ] && found="${found:+$found, }$plugin ($count)"
  done <<< "$plugins"
  [ -z "$found" ] || warn "plugin PreToolUse hooks present: $found; they also run in local factory sessions and may block edits; name any block in the run record's blocked_by"
}

user_settings="$HOME/.claude/settings.json"
if [ -f "$user_settings" ] && command -v jq >/dev/null 2>&1; then
  check_settings_hooks "$user_settings" && check_plugin_hooks "$user_settings"
fi

warn "verify GitHub branch protection or a ruleset manually; see docs/factory/GITHUB.md"

printf '\nFACTORY_DOCTOR: failures=%d warnings=%d\n' "$failures" "$warnings"
[ "$failures" -eq 0 ]

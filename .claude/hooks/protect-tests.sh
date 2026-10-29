#!/usr/bin/env bash
# protect-tests.sh - enforce the charter's test-file rule (TESTS_ARE_LOAD_BEARING).
#
# Blocks Edit/Write/NotebookEdit on an EXISTING test file, and shell writes to test
# files. Creating a NEW test file is allowed, matching the charter. A human who has
# approved a test change in an interactive session can start Claude with
# FACTORY_ALLOW_TEST_EDITS=1 for that session only.
#
# Wired as a PreToolUse hook in .claude/settings.json. Exit 2 blocks the call and
# returns stderr to the agent as feedback.

set -uo pipefail

[ "${FACTORY_ALLOW_TEST_EDITS:-0}" = "1" ] && exit 0

INPUT="$(cat)"

# This hook needs reliable JSON parsing; failing open on a parse problem would make
# the rule decorative. Without jq, block and say why.
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCKED by factory hook: jq is required for the test-file guard." >&2
  exit 2
fi

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')"

# Test files: *.test.*, *.spec.*, and anything under a tests/ or __tests__/ directory.
TEST_PATH_RE='(\.(test|spec)\.[A-Za-z0-9]+$|(^|/)(__tests__|tests?)/)'

block() {
  echo "BLOCKED by factory hook: $1" >&2
  echo "" >&2
  echo "Existing tests are load-bearing (docs/factory/CHARTER.md, section 3)." >&2
  echo "Add a new test file instead, or stop and ask the human." >&2
  exit 2
}

case "$TOOL" in
  Edit|Write|NotebookEdit)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
    [ -z "$FILE" ] && exit 0
    if printf '%s' "$FILE" | grep -qE "$TEST_PATH_RE" && [ -e "$FILE" ]; then
      block "editing existing test file $FILE"
    fi
    ;;
  Bash)
    CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
    [ -z "$CMD" ] && exit 0
    if printf '%s' "$CMD" | grep -qE '\.(test|spec)\.[A-Za-z0-9]+|(__tests__|tests?)/'; then
      if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(sed[[:space:]]+-i|tee|>|>>|rm|mv|cp|truncate|perl[[:space:]]+-i)'; then
        block "writing to a test file via the shell"
      fi
    fi
    ;;
esac

exit 0

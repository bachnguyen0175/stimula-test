#!/usr/bin/env bash
# Exit 0 when gh is installed and logged in to the GitHub host this repo's origin points to.
# Plain `gh auth status` fails when any configured host fails, such as a stale second login,
# so check only the host that matters. GH_HOST overrides; with no usable origin, github.com.

set -euo pipefail

command -v gh >/dev/null 2>&1 || { echo "gh is not installed" >&2; exit 1; }

host="${GH_HOST:-}"
if [ -z "$host" ]; then
  url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    *://*) url="${url#*://}"; url="${url#*@}"; host="${url%%[/:]*}" ;;
    *@*:*) url="${url#*@}"; host="${url%%:*}" ;;
  esac
fi
host="${host:-github.com}"

gh auth status --hostname "$host" >/dev/null 2>&1 || {
  echo "gh is not logged in to $host; run: gh auth login --hostname $host" >&2
  exit 1
}

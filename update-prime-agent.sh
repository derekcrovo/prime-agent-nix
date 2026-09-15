#!/usr/bin/env bash
# Update the packaged Prime Agent to the latest upstream stable tag.
#
# Wraps the repository's own update machinery (scripts/update.sh) with the
# build verification and commit steps from README "Update to a new release".
#
# Usage:
#   ./update-prime-agent.sh            # update to latest tag, verify, commit
#   ./update-prime-agent.sh --check    # only report available update
#   ./update-prime-agent.sh --force    # regenerate hashes for current tag
#   ./update-prime-agent.sh --no-commit # update and verify, but don't commit
set -euo pipefail

cd "$(dirname "$0")"

args=()
commit=1
for arg in "$@"; do
  case "$arg" in
    --check|--force) args+=("$arg") ;;
    --no-commit) commit=0 ;;
    *)
      echo "Usage: $0 [--check|--force|--no-commit]" >&2
      exit 2
      ;;
  esac
done

# 1. Update VERSION.json pins (no-op when current, unless --force).
nix run .#update -- "${args[@]+${args[@]}}"

if [ "${1-}" = "--check" ]; then
  exit 0
fi

# 2. Build and verify before committing.
nix flake check --print-build-logs

# 3. Commit the release bump.
if [ "$commit" -eq 1 ] && ! git diff --quiet; then
  rev="$(jq -r .rev VERSION.json)"
  git add VERSION.json package-lock.json
  git commit -m "prime-agent: update to $rev"
  echo "Committed update to $rev."
else
  echo "Nothing to commit."
fi

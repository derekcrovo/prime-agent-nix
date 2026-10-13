#!/usr/bin/env bash
# Pin the newest Prime Agent release, then build and validate it if it changed.
set -euo pipefail

cd "$(dirname "$0")"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean; commit or discard local changes before updating." >&2
  exit 1
fi

backup="$(mktemp)"
cp VERSION.json "$backup"
validated=0
finish() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ] && [ "$validated" -eq 0 ] && ! cmp -s "$backup" VERSION.json; then
    cp "$backup" VERSION.json
    echo "Update validation failed; restored the previous VERSION.json pin." >&2
  fi
  rm -f "$backup"
  exit "$status"
}
trap finish EXIT

old_rev="$(jq -r .rev VERSION.json)"
nix run .#update
new_rev="$(jq -r .rev VERSION.json)"

if [ "$old_rev" = "$new_rev" ]; then
  echo "No Prime Agent update; skipping build and validation."
  exit 0
fi

echo "Validating Prime Agent $new_rev (was $old_rev)."
nix flake check --print-build-logs
validated=1

git commit --only -m "prime-agent: update to $new_rev" -- VERSION.json
git push
echo "Prime Agent $new_rev built, validated, committed, and pushed."

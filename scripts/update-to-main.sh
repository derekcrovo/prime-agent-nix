#!/usr/bin/env bash
# Check for a new upstream Prime Agent release; if one exists, refresh the
# packaged version (VERSION.json + package-lock.json), build and check it,
# commit, and merge into main.
#
# Usage: scripts/update-to-main.sh [--dry-run]
set -euo pipefail

repo="johnrichardrinehart/prime-agent-nix"
bot_name="github-actions[bot]"
bot_email="41898282+github-actions[bot]@users.noreply.github.com"

dry_run=0
[ "${1-}" = "--dry-run" ] && dry_run=1

# --- repo sanity -----------------------------------------------------------
if [ ! -f VERSION.json ] || [ ! -f flake.nix ]; then
  echo "Run from the prime-agent-nix repository root." >&2
  exit 1
fi
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is dirty; commit or stash first." >&2
  exit 1
fi

current_rev="$(jq -r .rev VERSION.json)"

# --- check for a new release ------------------------------------------------
latest_rev="$(
  git ls-remote --tags --refs https://github.com/PrimeIntellect-ai/prime-agent.git 'v*' |
    awk -F/ '{ print $3 }' |
    grep -E '^v[0-9]+(\.[0-9]+)*$' |
    sort -V |
    tail -n1
)"
test -n "$latest_rev"

if [ "$latest_rev" = "$current_rev" ]; then
  echo "Prime Agent is current at $current_rev. Nothing to do."
  exit 0
fi
echo "Update available: $current_rev -> $latest_rev"
[ "$dry_run" = 1 ] && {
  echo "(dry run: stopping before any changes)"
  exit 0
}

# --- branch ------------------------------------------------------------------
branch="prime-agent-${latest_rev}"
start_ref="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"
git checkout -b "$branch"

cleanup() {
  # If we bailed mid-update, go back to where we started.
  if [ "$(git symbolic-ref --quiet --short HEAD || true)" = "$branch" ] &&
    ! git diff --quiet -- VERSION.json package-lock.json 2>/dev/null; then
    git checkout -- VERSION.json package-lock.json
  fi
}
trap cleanup EXIT

# --- refresh hashes (existing repo machinery) --------------------------------
# Runs scripts/update.sh: fetches the new source tarball, computes the
# source hash and npm deps hash, rewrites VERSION.json and package-lock.json.
nix run .#update

if git diff --quiet -- VERSION.json package-lock.json; then
  echo "Nothing changed after update run; aborting." >&2
  git checkout "$start_ref" && git branch -D "$branch"
  trap - EXIT
  exit 1
fi

# --- build + check ------------------------------------------------------------
echo "Building and checking prime-agent $latest_rev ..."
nix build .#prime-agent
nix flake check --print-build-logs
if result/bin/prime-agent --version 2>&1 | grep -qx "${latest_rev#v}"; then
  echo "version check OK: ${latest_rev#v}"
else
  echo "version check FAILED" >&2
  exit 1
fi

# --- commit + merge ------------------------------------------------------------
git config user.name "$bot_name"
git config user.email "$bot_email"
git add VERSION.json package-lock.json
git commit -m "prime-agent: update to $latest_rev"

git checkout main
git merge --no-ff "$branch" -m "Merge branch '$branch'"
git branch -d "$branch"
trap - EXIT

echo
echo "Merged $latest_rev into main."
echo "Push with: git push derekcrovo main   (then open/merge a PR on $repo if desired)"

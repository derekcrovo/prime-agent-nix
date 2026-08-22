#!/usr/bin/env bash
# Lightweight hourly check (for launchd/cron): compare the packaged Prime
# Agent version in this checkout against the latest upstream stable tag.
# Notify via macOS notification when an update is available, and remind once
# per day while it remains unapplied. Exits 0 when current, 1 when an update
# is available (handy for scripts), 2 on error.
set -euo pipefail

if [ ! -f VERSION.json ]; then
  echo "Run prime-agent-update-check from the prime-agent-nix repository root." >&2
  exit 2
fi

current_rev="$(jq -r .rev VERSION.json)"
latest_rev="$(
  git ls-remote --tags --refs https://github.com/PrimeIntellect-ai/prime-agent.git 'v*' |
    awk -F/ '{ print $3 }' |
    grep -E '^v[0-9]+(\.[0-9]+)*$' |
    sort -V |
    tail -n1
)"
if [ -z "$latest_rev" ]; then
  echo "Could not determine the latest upstream tag." >&2
  exit 2
fi

if [ "$latest_rev" = "$current_rev" ]; then
  echo "Prime Agent is current at $current_rev."
  exit 0
fi

echo "Prime Agent update available: $current_rev -> $latest_rev"

# Notify at most once per day per target version.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/prime-agent-nix"
mkdir -p "$state_dir"
stamp="$state_dir/notified-$latest_rev"
today="$(date +%F)"
if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$today" ]; then
  osascript -e "display notification \"Prime Agent $latest_rev is available (packaged: $current_rev). Run scripts/update-to-main.sh in ~/prime-agent-nix.\" with title \"prime-agent-nix\" sound name \"Glass\"" ||
    echo "(notification failed)" >&2
  echo "$today" >"$stamp"
fi
exit 1

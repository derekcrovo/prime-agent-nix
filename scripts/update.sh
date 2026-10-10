# shellcheck shell=bash

mode=update
case "${1-}" in
"") ;;
--check) mode=check ;;
--force) mode=force ;;
*)
  echo "Usage: prime-agent-update [--check|--force]" >&2
  exit 2
  ;;
esac

if [ ! -f VERSION.json ] || [ ! -f flake.nix ]; then
  echo "Run prime-agent-update from the prime-agent-nix repository root." >&2
  exit 1
fi

latest_rev="$(
  git ls-remote --tags --refs https://github.com/PrimeIntellect-ai/prime-agent.git 'v*' |
    awk -F/ '{ print $3 }' |
    grep -E '^v[0-9]+(\.[0-9]+)*$' |
    sort -V |
    tail -n1
)"
test -n "$latest_rev"
current_rev="$(jq -r .rev VERSION.json)"

if [ "$mode" = check ]; then
  if [ "$latest_rev" = "$current_rev" ]; then
    echo "Prime Agent is current at $current_rev."
  else
    echo "Prime Agent update available: $current_rev -> $latest_rev"
  fi
  exit 0
fi

if [ "$mode" != force ] && [ "$latest_rev" = "$current_rev" ]; then
  echo "Prime Agent is current at $current_rev."
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source_json="$(
  nix store prefetch-file --json --unpack \
    "https://github.com/PrimeIntellect-ai/prime-agent/archive/refs/tags/$latest_rev.tar.gz"
)"
source_hash="$(jq -r .hash <<<"$source_json")"
source_path="$(jq -r .storePath <<<"$source_json")"

catalog_rev="$(
  git ls-remote https://github.com/PrimeIntellect-ai/prime-agent-catalog.git refs/heads/main |
    awk 'NR == 1 { print $1 }'
)"
test -n "$catalog_rev"
catalog_json="$(
  nix store prefetch-file --json --unpack \
    "https://github.com/PrimeIntellect-ai/prime-agent-catalog/archive/$catalog_rev.tar.gz"
)"
catalog_hash="$(jq -r .hash <<<"$catalog_json")"
catalog_path="$(jq -r .storePath <<<"$catalog_json")"

if [ ! -f "$source_path/Cargo.toml" ] || \
   [ ! -f "$source_path/Cargo.lock" ] || \
   [ ! -f "$source_path/crates/pa-cli/Cargo.toml" ]; then
  echo "Prime Agent $latest_rev is not a supported Rust workspace (expected Cargo.toml, Cargo.lock, and crates/pa-cli)." >&2
  exit 1
fi
if grep -Fq 'source = "git+' "$source_path/Cargo.lock"; then
  echo "Prime Agent $latest_rev added Git-sourced Cargo dependencies; add their hashes to nix/packages/prime-agent.nix before updating." >&2
  exit 1
fi
python3 "$source_path/scripts/release/bundle_catalog.py" generate \
  --catalog-dir "$catalog_path" --out "$tmpdir/catalog-assets" >/dev/null

jq \
  --arg rev "$latest_rev" \
  --arg hash "$source_hash" \
  --arg catalogRev "$catalog_rev" \
  --arg catalogHash "$catalog_hash" \
  'del(.npmDepsHash) | del(.cargoHash) | .rev = $rev | .hash = $hash | .catalogRev = $catalogRev | .catalogHash = $catalogHash' \
  VERSION.json >"$tmpdir/VERSION.json"
mv "$tmpdir/VERSION.json" VERSION.json

echo "Updated Prime Agent to $latest_rev."

# prime-agent-nix

A Nix package for [Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent),
maintained as a personal fork. It supports `x86_64-linux`, `aarch64-linux`,
and Apple Silicon (`aarch64-darwin`).

Versions are updated manually: check for a new upstream release, refresh the
pinned version and hashes, build, and commit. There is no scheduled automation.

## Run

```console
nix run github:derekcrovo/prime-agent-nix -- --version
nix run github:derekcrovo/prime-agent-nix
```

The Rust CLI ships with its Python RLM runtime, built-in skills, and a Nix-built
Python 3.11 environment. The environment is locked in `nix/kernel/uv.lock` and
includes MCP 2 plus the default Python modules. It does not download a Python
runtime on first use, so kernel startup works offline.

## Install declaratively

Use the package directly from a flake input:

```nix
{
  inputs.prime-agent.url = "github:derekcrovo/prime-agent-nix";
  inputs.prime-agent.inputs.nixpkgs.follows = "nixpkgs-unstable";

  # ...
  home.packages = [ prime-agent.packages.aarch64-darwin.default ];
}
```

The flake also exports `overlays.default` as `pkgs.prime-agent`.

## Update to a new release

1. Check for a newer stable tag (or wait for the TUI banner / the hourly
   `scripts/update-check.sh` notification):

   ```console
   nix run .#update -- --check
   ```

2. Refresh the pinned Rust source and validated catalog snapshot in
   `VERSION.json`. Cargo dependencies come from the upstream `Cargo.lock`:

   ```console
   nix run .#update
   ```

3. Build and verify, then commit:

   ```console
   nix flake check --print-build-logs
   git commit -am "prime-agent: update to v$NEW_VERSION"
   ```

The `./update-prime-agent.sh` wrapper runs the update and checks, then commits
and pushes by default. Use `./update-prime-agent.sh --no-commit` to review the
changes without committing. If a build breaks, inspect `nix/packages/prime-agent.nix`
and `nix/kernel/pyproject.toml` for packaging assumptions that need updating.

Use `nix run .#update -- --force` to regenerate hashes for the current tag.

## Trust model

Each revision pins the Prime Agent source and bundled catalog snapshot by
content hash. Rust dependencies use the checksums in upstream `Cargo.lock`, and
the Nix-built Python kernel dependencies are pinned in `nix/kernel/uv.lock`.
Updates are built and checked before commit.

This repository packages Prime Agent but does not maintain it. Prime Agent is
MIT licensed by Prime Intellect and its contributors. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for packaging attribution.

## Development

```console
nix fmt
nix flake check --print-build-logs
```

Direnv loads the dev shell automatically (`.envrc`). On Darwin, Nix skips two
upstream CLI tests with socket or short-timer assumptions; it runs the rest
with `NO_COLOR=1`. Linux package builds run the full CLI library suite.
`checks.kernel` validates the packaged CLI and Python runtime on Darwin.

## License

The packaging code uses the MIT License. See [`LICENSE`](LICENSE).

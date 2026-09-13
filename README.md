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

The package supplies a Nix-built IPython kernel and all default Python modules.
It does not download a generic Linux Python during first use. This behavior
keeps the kernel compatible with NixOS and supports offline kernel startup.

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

2. Refresh the pinned source and npm dependency hashes in `VERSION.json`:

   ```console
   nix run .#update
   ```

3. Build and verify, then commit:

   ```console
   nix flake check --print-build-logs
   git commit -am "prime-agent: update to v$NEW_VERSION"
   ```

If the build breaks, upstream changed something the packaging relied on; see
`nix/packages/prime-agent.nix` for the patches and substitutions that usually
need adjusting.

Use `nix run .#update -- --force` to regenerate hashes for the current tag.

## Trust model

Each revision pins Prime Agent source and npm dependencies with Nix hashes.
Updates are built and checked before commit, by hand.

This repository packages Prime Agent but does not maintain it. Prime Agent is
MIT licensed by Prime Intellect and its contributors. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for packaging attribution.

## Development

```console
nix fmt
nix flake check --print-build-logs
```

Direnv loads the dev shell automatically (`.envrc`).

## License

The packaging code uses the MIT License. See [`LICENSE`](LICENSE).

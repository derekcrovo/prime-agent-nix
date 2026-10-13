# prime-agent-nix

A small Nix flake that packages upstream [Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent).

## Update Prime Agent

Run this from the repository root:

```sh
./update.sh
```

The script checks the latest stable upstream tag. If it is unchanged, it exits without building. If it changed, it updates the pinned source and catalog hashes, runs `nix flake check --print-build-logs`, then commits the validated pin and pushes it. A failed update or validation does not leave a new version pin behind.

The update requires Nix with flakes enabled, Git, and `jq`. The Git checkout must be clean and have a push-enabled `origin` remote.

## Use the package

The flake exposes the package as `packages.<system>.default` (also `prime-agent`) and through `overlays.default`.

```nix
home.packages = [ prime-agent.packages.aarch64-darwin.default ];
```

Supported systems: `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

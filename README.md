# prime-agent-nix

This repository provides a frequently updated Nix package for
[Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent). It supports
`x86_64-linux`, `aarch64-linux`, and Apple Silicon (`aarch64-darwin`).

The scheduled workflow checks upstream every ten minutes. When a stable release
changes, it refreshes the fixed source and dependency hashes. It then builds and
smoke-tests the package before it updates `main`. GitHub can delay scheduled
workflow starts during periods of high load.

## Run

```console
nix --tarball-ttl 0 run github:johnrichardrinehart/prime-agent-nix -- --version
nix --tarball-ttl 0 run github:johnrichardrinehart/prime-agent-nix
```

`--tarball-ttl 0` makes Nix resolve the current repository revision instead of
using a cached GitHub archive lookup.

The package supplies a Nix-built IPython kernel and all default Python modules.
It does not download a generic Linux Python during first use. This behavior
keeps the kernel compatible with NixOS and supports offline kernel startup.

## Install declaratively

Use the package directly from a flake input:

```nix
{
  inputs.prime-agent-nix.url =
    "github:johnrichardrinehart/prime-agent-nix";

  outputs = { nixpkgs, prime-agent-nix, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            prime-agent-nix.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

The flake also exports `overlays.default` as `pkgs.prime-agent`.

## Update and verify

```console
nix run .#update
nix flake check --print-build-logs
```

Use `nix run .#update -- --check` to compare the packaged version with the
latest stable upstream tag. Use `--force` to regenerate hashes for the current
tag.

## Trust model

Each revision pins Prime Agent source and npm dependencies with Nix hashes.
Scheduled updates build before publication, but they merge without human
review. Track an exact commit when review and reproducibility matter more than
release speed.

This repository packages Prime Agent but does not maintain it. Prime Agent is
MIT licensed by Prime Intellect and its contributors. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for packaging attribution.

## Development

This repository uses
[`nix-project-template`](https://github.com/johnrichardrinehart/nix-project-template)
because it is a Nix-native consumer flake. The template keeps development-only
formatting and hook inputs out of package consumers.

```console
nix fmt
nix flake check --print-build-logs
nix develop
```

## License

The packaging code uses the MIT License. See [`LICENSE`](LICENSE).

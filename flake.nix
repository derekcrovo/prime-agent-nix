{
  description = "Frequently updated Nix package for Prime Intellect Prime Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [ inputs.flake-parts.flakeModules.partitions ];

      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module = import ./nix/flake/dev-partition.nix;
      };

      perSystem =
        { pkgs, ... }:
        let
          release = builtins.fromJSON (builtins.readFile ./VERSION.json);
          version = pkgs.lib.removePrefix "v" release.rev;
          src = pkgs.fetchFromGitHub {
            owner = "PrimeIntellect-ai";
            repo = "prime-agent";
            inherit (release) rev hash;
          };
          primeAgent = pkgs.callPackage ./nix/packages/prime-agent.nix {
            inherit src version;
            inherit (release) npmDepsHash;
          };
          update = import ./nix/apps/update.nix { inherit pkgs; };
        in
        {
          packages = {
            default = primeAgent;
            prime-agent = primeAgent;
          };

          apps = {
            default = {
              type = "app";
              program = pkgs.lib.getExe primeAgent;
              meta.description = "Run Prime Agent";
            };
            update = {
              type = "app";
              program = pkgs.lib.getExe update;
              meta.description = "Refresh the packaged Prime Agent release";
            };
          };

          checks = {
            package = primeAgent;
            kernel = import ./nix/checks/kernel.nix { inherit pkgs primeAgent version; };
            version =
              pkgs.runCommand "prime-agent-version-${version}" { nativeBuildInputs = [ primeAgent ]; }
                ''
                  export HOME="$TMPDIR/home"
                  mkdir -p "$HOME"
                  test "$(prime-agent --version 2>&1)" = ${pkgs.lib.escapeShellArg version}
                  touch "$out"
                '';
          };
        };

      flake.overlays.default = final: _prev: {
        prime-agent = self.packages.${final.stdenv.hostPlatform.system}.prime-agent;
      };
    };
}

{
  description = "Nix package for Prime Intellect Prime Agent";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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
        in
        {
          default = primeAgent;
          prime-agent = primeAgent;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          update = import ./nix/apps/update.nix { inherit pkgs; };
        in
        {
          default = {
            type = "app";
            program = pkgs.lib.getExe self.packages.${system}.prime-agent;
            meta.description = "Run Prime Agent";
          };
          update = {
            type = "app";
            program = pkgs.lib.getExe update;
            meta.description = "Refresh the packaged Prime Agent release";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          primeAgent = self.packages.${system}.prime-agent;
          version = primeAgent.version;
        in
        {
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
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "fmt";
          runtimeInputs = [ pkgs.nixfmt-tree ];
          text = ''
            if [ $# -eq 0 ]; then
              set -- .
            fi
            exec treefmt "$@"
          '';
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell { packages = [ pkgs.nixfmt-tree ]; };
        }
      );

      overlays.default = final: _prev: {
        prime-agent = self.packages.${final.stdenv.hostPlatform.system}.prime-agent;
      };
    };
}

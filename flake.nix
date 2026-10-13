{
  description = "Nix package for Prime Intellect Prime Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
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
          catalogSrc = pkgs.fetchFromGitHub {
            owner = "PrimeIntellect-ai";
            repo = "prime-agent-catalog";
            rev = release.catalogRev;
            hash = release.catalogHash;
          };
          kernelPython = import ./nix/packages/kernel-python.nix {
            inherit
              pkgs
              pyproject-nix
              uv2nix
              pyproject-build-systems
              ;
          };
          primeAgent = pkgs.callPackage ./nix/packages/prime-agent.nix {
            inherit
              src
              version
              catalogSrc
              kernelPython
              ;
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

      overlays.default = final: _prev: {
        prime-agent = self.packages.${final.stdenv.hostPlatform.system}.prime-agent;
      };
    };
}

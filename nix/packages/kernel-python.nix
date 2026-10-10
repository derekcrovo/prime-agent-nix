{
  pkgs,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
let
  inherit (pkgs) lib;
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ../../nix/kernel;
  };
  workspaceOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };
  python = pkgs.python311;
  pythonBase = pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  };
  pythonSet = pythonBase.overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      workspaceOverlay
    ]
  );
in
pythonSet.mkVirtualEnv "prime-agent-kernel-python" workspace.deps.default

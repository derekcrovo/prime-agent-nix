{ pkgs }:
pkgs.writeShellApplication {
  name = "prime-agent-update";
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    git
    gnugrep
    gnused
    jq
    nix
    python3
  ];
  text = builtins.readFile ../../scripts/update.sh;
}

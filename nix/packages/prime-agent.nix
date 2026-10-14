{
  lib,
  stdenv,
  rustPlatform,
  makeWrapper,
  python3,
  nodejs_22,
  uv,
  gitMinimal,
  openssh,
  ripgrep,
  fd,
  src,
  version,
  catalogSrc,
  kernelPython,
}:
let
  runtimeBins = lib.makeBinPath [
    nodejs_22
    uv
    gitMinimal
    openssh
    ripgrep
    fd
  ];
in
rustPlatform.buildRustPackage {
  pname = "prime-agent";
  inherit src version;
  cargoLock.lockFile = "${src}/Cargo.lock";

  cargoBuildFlags = [
    "--package"
    "pa-cli"
    "--bin"
    "prime-agent"
  ];
  # Keep snapshots plain even when Nix exposes terminal-like stdout.
  env = {
    NO_COLOR = "1";
  };
  # These upstream tests are not stable on the Darwin Nix builder: one expects
  # a non-Darwin socket error; the other uses a 60ms scheduling window.
  checkFlags = lib.optionals stdenv.hostPlatform.isDarwin [
    "--skip"
    "daemon_client::tests::socket_close_reports_daemon_closing_reason"
    "--skip"
    "piped_stdin::tests::a_live_producer_resets_the_window"
  ];
  cargoTestFlags = [
    "--package"
    "pa-cli"
    "--lib"
  ];
  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  postInstall = ''
    packageDir="$out/lib/prime-agent"
    mkdir -p "$out/libexec" "$packageDir"
    mv "$out/bin/prime-agent" "$out/libexec/prime-agent"

    cp -R ${src}/prime-agent-runtime "$packageDir/prime-agent-runtime"
    cp -R ${src}/skills "$packageDir/skills"
    cp ${src}/README.md ${src}/LICENSE "$packageDir/"
    python3 ${src}/scripts/release/bundle_catalog.py generate \
      --catalog-dir ${catalogSrc} --out "$packageDir" >/dev/null

    cat >"$packageDir/package.json" <<'JSON'
    {
      "name": "prime-agent",
      "version": "${version}",
      "description": "Prime Agent: the RLM coding agent (Rust build)",
      "bin": { "prime-agent": "prime-agent" },
      "piConfig": { "name": "prime-agent", "configDir": ".prime/agent" }
    }
    JSON

    # The Rust kernel resolves Python skills from the packaged skills tree.
    # Put each src package on one read-only PYTHONPATH entry.
    pythonModules="$packageDir/python-modules"
    mkdir -p "$pythonModules"
    for sourceDir in "$packageDir/prime-agent-runtime/src" "$packageDir"/skills/*/src; do
      [ -d "$sourceDir" ] || continue
      for module in "$sourceDir"/*; do
        [ -e "$module" ] || continue
        ln -s "$module" "$pythonModules/$(basename "$module")"
      done
    done

    # Kernel interpreter. Hand-rolled wrapper (makeWrapper cannot express
    # this) because the scrub is load-bearing: a leaked dev-shell PYTHONPATH
    # carries /nix/store site-packages built for a different Python minor,
    # and PYTHONPATH precedes site-packages in sys.path, so e.g.
    # python3.13-pydantic shadows this (3.11) env's own pydantic with an
    # ABI-incompatible build and kernel start fails with "missing default
    # Python packages (pydantic)". Drop inherited store entries; keep
    # non-store ones (e.g. the skills dir launch wrappers export for
    # late-installed skills).
    cat >"$out/bin/prime-agent-kernel-python" <<'PA_KERNEL_PYTHON'
    #!${stdenv.shell} -e
    export PYTHONDONTWRITEBYTECODE=1
    scrubbed="$(printf '%s' "''${PYTHONPATH:-}" | tr ':' '\n' | grep -v '^/nix/store/' | paste -sd: -)"
    export PYTHONPATH="${placeholder "out"}/lib/prime-agent/python-modules''${scrubbed:+:$scrubbed}"
    exec "${kernelPython}/bin/python" "$@"
    PA_KERNEL_PYTHON
    chmod +x "$out/bin/prime-agent-kernel-python"

    makeWrapper "$out/libexec/prime-agent" "$out/bin/prime-agent" \
      --set PI_PACKAGE_DIR "$packageDir" \
      --set-default PRIME_AGENT_KERNEL_PYTHON "$out/bin/prime-agent-kernel-python" \
      --prefix PATH : "${runtimeBins}" \
      --run 'export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/prime-agent/npm}"'
  '';

  passthru = { inherit kernelPython; };

  meta = {
    description = "Self-improving RLM agent for coding and long-running autonomous tasks";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    changelog = "https://github.com/PrimeIntellect-ai/prime-agent/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = lib.platforms.linux ++ [ "aarch64-darwin" ];
  };
}

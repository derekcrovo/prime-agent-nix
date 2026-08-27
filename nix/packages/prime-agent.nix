{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs_22,
  gitMinimal,
  openssh,
  ripgrep,
  fd,
  uv,
  cmake,
  ninja,
  pkg-config,
  python3,
  python313,
  runCommand,
  pixman,
  cairo,
  pango,
  libpng,
  libjpeg,
  giflib,
  librsvg,
  src,
  version,
  npmDepsHash,
}:
let
  nodejs = nodejs_22;
  # tyro 1.0.15's test_suppress_subcommand asserts the suppressed field name
  # "bc" is absent from --help output, but the Nix build runs pytest from a
  # store path that happens to contain the substring "bc", which tyro prints
  # in the usage line (prog = sys.argv[0]). Hash-lottery false positive;
  # disable that test.
  python313' = python313.override {
    packageOverrides = _final: prev: {
      tyro = prev.tyro.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [ "test_suppress_subcommand" ];
      });
    };
  };
  buildNpmPackage' = buildNpmPackage.override { inherit nodejs; };
  runtimeBins = lib.makeBinPath [
    nodejs
    gitMinimal
    openssh
    ripgrep
    fd
    uv
  ];
  kernelPythonEnv = python313'.withPackages (
    ps: with ps; [
      beautifulsoup4
      dill
      httpx
      ipykernel
      lxml
      mcp
      nest-asyncio
      numpy
      pandas
      pillow
      pydantic
      python-dotenv
      pyyaml
      requests
      scipy
      tomli
      tyro
    ]
  );
  kernelPython =
    runCommand "prime-agent-kernel-python-${version}" { nativeBuildInputs = [ makeWrapper ]; }
      ''
        mkdir -p "$out/bin" "$out/lib"
        cp -r ${src}/prime-agent-runtime/src/. "$out/lib/"
        for sourceDir in ${src}/packages/coding-agent/skills/*/src; do
          cp -r "$sourceDir"/. "$out/lib/"
        done
        # Fix: MCP SDK (>= 1.x) expects a timedelta for
        # ClientSession(read_timeout_seconds=...) and calls .total_seconds() on
        # it, but the kernel passes a raw float, causing
        #   AttributeError: 'float' object has no attribute 'total_seconds'
        # on every stdio MCP server startup.  Fixed upstream in prime-agent
        # main but not yet released; remove this once 0.9.0+ ships.
        substituteInPlace "$out/lib/rlm/mcp.py" \
          --replace-fail "ClientSession(read, write, read_timeout_seconds=self.call_timeout)" \
                          "ClientSession(read, write, read_timeout_seconds=__import__('datetime').timedelta(seconds=self.call_timeout))"
        makeWrapper ${kernelPythonEnv}/bin/python "$out/bin/python" \
          --prefix PYTHONPATH : "$out/lib" \
          --set PYTHONDONTWRITEBYTECODE 1
      '';
in
buildNpmPackage' {
  pname = "prime-agent";
  inherit src version npmDepsHash;
  npmDepsFetcherVersion = 2;

  nativeBuildInputs = [
    makeWrapper
    gitMinimal
    cmake
    ninja
    pkg-config
    python3
  ];

  buildInputs = [
    pixman
    cairo
    pango
    libpng
    libjpeg
    giflib
    librsvg
  ];

  dontUseCmakeConfigure = true;

  prePatch = ''
    cp ${../../package-lock.json} package-lock.json
  '';

  preBuild = ''
    substituteInPlace packages/ai/package.json \
      --replace-fail "npm run generate-models && " ""

    find packages -name package.json -exec sed -i \
      -e 's/--watch --preserveWatchOutput//g' \
      {} \;
  '';

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageDir="$out/lib/node_modules/@earendil-works/pi-coding-agent"
    mkdir -p "$out/bin" "$packageDir" "$out/lib/node_modules/@earendil-works"

    for pkg in tui ai agent; do
      mkdir -p "$out/lib/node_modules/@earendil-works/pi-$pkg"
      cp -r "packages/$pkg/dist" "$out/lib/node_modules/@earendil-works/pi-$pkg/"
      cp "packages/$pkg/package.json" "$out/lib/node_modules/@earendil-works/pi-$pkg/"
    done

    cp -r packages/coding-agent/dist "$packageDir/"
    for path in package.json README.md CHANGELOG.md docs examples skills postinstall.cjs; do
      [ ! -e "packages/coding-agent/$path" ] || cp -r "packages/coding-agent/$path" "$packageDir/"
    done

    cp -rL node_modules/. "$out/lib/node_modules/"

    makeWrapper ${nodejs}/bin/node "$out/bin/prime-agent" \
      --add-flags "$packageDir/dist/bundle/cli.js" \
      --set PI_PACKAGE_DIR "$packageDir" \
      --set-default PRIME_AGENT_KERNEL_PYTHON "${kernelPython}/bin/python" \
      --set PRIME_AGENT_LAUNCHER_PATH "$out/bin/prime-agent" \
      --prefix NODE_PATH : "$out/lib/node_modules" \
      --suffix PATH : "${runtimeBins}" \
      --run 'export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/prime-agent/npm}"'

    runHook postInstall
  '';

  passthru = { inherit kernelPython; };

  meta = {
    description = "Self-improving RLM agent for coding and long-running autonomous tasks";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    changelog = "https://github.com/PrimeIntellect-ai/prime-agent/blob/v${version}/packages/coding-agent/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = lib.platforms.linux ++ [ "aarch64-darwin" ];
  };
}

{
  pkgs,
  primeAgent,
  version,
}:
pkgs.runCommand "prime-agent-kernel-${version}" { } ''
  set -euo pipefail
  export HOME="$TMPDIR/home"
  export XDG_DATA_HOME="$HOME/.local/share"
  mkdir -p "$HOME"
  export PI_PACKAGE_DIR=${primeAgent}/lib/prime-agent
  export PRIME_AGENT_KERNEL_PYTHON=${primeAgent}/bin/prime-agent-kernel-python

  test "$( ${primeAgent}/bin/prime-agent --version 2>&1 )" = ${pkgs.lib.escapeShellArg version}
  ${primeAgent}/bin/prime-agent --help >/dev/null 2>&1
  bootstrap_output="$( ${primeAgent}/bin/prime-agent --prime-agent-bootstrap )"
  test "$bootstrap_output" = "kernel python: ${primeAgent}/bin/prime-agent-kernel-python"

  ${primeAgent}/bin/prime-agent-kernel-python - ${primeAgent}/lib/prime-agent/python-modules <<'PY'
  import importlib
  import importlib.metadata
  import sys
  from pathlib import Path

  import dill
  import mcp
  import rlm
  import rlm.repl

  assert importlib.metadata.version("mcp") == "2.0.0"
  assert rlm.repl.PROTOCOL_VERSION == 3
  for module in (
      "requests", "httpx", "yaml", "tomli", "dotenv", "pandas", "numpy",
      "scipy", "bs4", "lxml", "pydantic", "tyro", "PIL",
  ):
      importlib.import_module(module)

  for path in sorted(Path(sys.argv[1]).iterdir()):
      if path.name.startswith("_"):
          continue
      importlib.import_module(path.name)
  PY

  # Regression: inherited /nix/store PYTHONPATH entries must be scrubbed
  # (a leaked dev-shell PYTHONPATH carries site-packages built for a
  # different Python minor and shadows this env's own packages with
  # ABI-incompatible builds), while non-store entries are preserved.
  keep="$TMPDIR/pa-kernel-keep"
  mkdir -p "$keep"
  touch "$keep/pa_kernel_scrub_keep.py"
  PYTHONPATH="/nix/store/zzz-pa-kernel-scrub-must-vanish:$keep" \
    ${primeAgent}/bin/prime-agent-kernel-python - "$keep" <<'PY'
  import importlib
  import sys

  keep = sys.argv[1]
  assert keep in sys.path, f"non-store PYTHONPATH entry dropped: {sys.path}"
  assert (
      "/nix/store/zzz-pa-kernel-scrub-must-vanish" not in sys.path
  ), f"store PYTHONPATH entry not scrubbed: {sys.path}"
  importlib.import_module("pa_kernel_scrub_keep")
  PY

  touch "$out"
''

{
  pkgs,
  primeAgent,
  version,
}:
pkgs.runCommand "prime-agent-kernel-${version}" { } ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  grep -F ${pkgs.lib.escapeShellArg "PRIME_AGENT_KERNEL_PYTHON"} ${primeAgent}/bin/prime-agent
  grep -F ${pkgs.lib.escapeShellArg "${primeAgent.kernelPython}/bin/python"} ${primeAgent}/bin/prime-agent

  export PI_PACKAGE_DIR=${primeAgent}/lib/node_modules/@earendil-works/pi-coding-agent
  export PRIME_AGENT_KERNEL_PYTHON=${primeAgent.kernelPython}/bin/python
  export PRIME_AGENT_KERNEL_LIB=${primeAgent.kernelPython}/lib
  export BOOTSTRAP_MODULE="$PI_PACKAGE_DIR/dist/core/kernel/bootstrap.js"
  ${pkgs.nodejs_22}/bin/node --input-type=module <<'JS'
  const { ensureKernelPython } = await import(process.env.BOOTSTRAP_MODULE);
  const python = await ensureKernelPython();
  if (python !== process.env.PRIME_AGENT_KERNEL_PYTHON) {
      throw new Error(`unexpected kernel: ''${python}`);
  }
  JS

  ${primeAgent.kernelPython}/bin/python <<'PY'
  import importlib
  import os
  from pathlib import Path
  from jupyter_client import KernelManager

  skill_modules = sorted(
      path.name
      for path in Path(os.environ["PRIME_AGENT_KERNEL_LIB"]).iterdir()
      if path.is_dir() and path.name != "rlm"
  )
  assert skill_modules
  for module in skill_modules:
      importlib.import_module(module)

  manager = KernelManager()
  client = None
  try:
      manager.start_kernel()
      client = manager.client()
      client.start_channels()
      client.wait_for_ready(timeout=20)
      message_id = client.execute("import rlm; assert callable(rlm.spawn)")
      while True:
          reply = client.get_shell_msg(timeout=20)
          if reply.get("parent_header", {}).get("msg_id") == message_id:
              assert reply["content"]["status"] == "ok", reply
              break
  finally:
      if client is not None:
          client.stop_channels()
          client = None
      if manager.has_kernel:
          manager.shutdown_kernel(now=True)
  PY
  touch "$out"
''

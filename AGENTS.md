# Repository guidance

This repository packages upstream Prime Agent with Nix. Keep changes focused on the package, pinned release metadata, and the single update workflow in `update-prime-agent.sh`.

The update script must only commit and push after `nix flake check --print-build-logs` succeeds. Keep the source and catalog revisions content-hash pinned in `VERSION.json`; never build from an unpinned upstream checkout. Preserve third-party license notices.

Validate changes with `nix flake check --print-build-logs`. Do not set Git identity or add `Co-authored-by` trailers to commits.

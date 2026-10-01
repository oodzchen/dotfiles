#!/usr/bin/env python3
"""Idempotently patch installed Pi packages: move host-provided packages
from `dependencies` to `peerDependencies` with a "*" range, so Pi's
extension loader stops warning about duplicate runtime modules.

Host-provided package list comes from pi docs (docs/packages.md):
@earendil-works/pi-ai, @earendil-works/pi-agent-core,
@earendil-works/pi-coding-agent, @earendil-works/pi-tui, typebox

Scans both npm-installed packages (~/.pi/agent/npm/node_modules) and
git-installed packages (~/.pi/agent/git). Safe to run repeatedly.
"""
import json
import sys
from pathlib import Path

HOST_PROVIDED = {
    "@earendil-works/pi-ai",
    "@earendil-works/pi-agent-core",
    "@earendil-works/pi-coding-agent",
    "@earendil-works/pi-tui",
    "typebox",
}

PI_AGENT_DIR = Path.home() / ".pi" / "agent"
SCAN_ROOTS = [
    PI_AGENT_DIR / "npm" / "node_modules",
    PI_AGENT_DIR / "git",
]


def candidate_manifests(root: Path):
    if not root.is_dir():
        return
    # top-level packages and @scoped/<pkg> (npm layout), depth 2
    for entry in root.iterdir():
        if entry.name.startswith("."):
            continue
        if entry.name.startswith("@"):
            for scoped in entry.iterdir():
                pkg = scoped / "package.json"
                if pkg.is_file():
                    yield pkg
        else:
            pkg = entry / "package.json"
            if pkg.is_file():
                yield pkg
    # git checkouts: any package.json at depth <= 4
    for pkg in root.glob("*/**/package.json"):
        if len(pkg.relative_to(root).parts) <= 4:
            yield pkg


def patch(manifest: Path) -> bool:
    try:
        data = json.loads(manifest.read_text())
    except (OSError, json.JSONDecodeError):
        return False
    deps = data.get("dependencies")
    if not isinstance(deps, dict):
        return False
    to_move = sorted(set(deps) & HOST_PROVIDED)
    if not to_move:
        return False
    peers = data.setdefault("peerDependencies", {})
    if not isinstance(peers, dict):
        peers = data["peerDependencies"] = {}
    for name in to_move:
        peers[name] = "*"
        del deps[name]
    if not deps:
        data.pop("dependencies", None)
    try:
        manifest.write_text(json.dumps(data, indent=2) + "\n")
    except OSError:
        return False
    print(f"patched {manifest}: moved {', '.join(to_move)} -> peerDependencies \"*\"")
    return True


def main() -> int:
    changed = 0
    for root in SCAN_ROOTS:
        for manifest in candidate_manifests(root):
            if patch(manifest):
                changed += 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

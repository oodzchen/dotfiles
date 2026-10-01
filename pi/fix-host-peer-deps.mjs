#!/usr/bin/env node
// Idempotently patch installed Pi packages: move host-provided packages from
// `dependencies` to `peerDependencies` with a "*" range, so Pi's extension
// loader stops warning about duplicate runtime modules.
//
// Node rewrite of the former Python script: pi itself is a Node application,
// so Node is guaranteed to exist wherever this runs — the patcher adds no
// extra runtime dependency (pure node: builtins, zero npm deps).
//
// Host-provided package list comes from pi docs (docs/packages.md):
// @earendil-works/pi-ai, @earendil-works/pi-agent-core,
// @earendil-works/pi-coding-agent, @earendil-works/pi-tui, typebox
//
// Scans both npm-installed packages (~/.pi/agent/npm/node_modules) and
// git-installed packages (~/.pi/agent/git). Safe to run repeatedly.
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, relative } from "node:path";

const HOST_PROVIDED = new Set([
	"@earendil-works/pi-ai",
	"@earendil-works/pi-agent-core",
	"@earendil-works/pi-coding-agent",
	"@earendil-works/pi-tui",
	"typebox",
]);

const PI_AGENT_DIR = join(homedir(), ".pi", "agent");
const SCAN_ROOTS = [
	join(PI_AGENT_DIR, "npm", "node_modules"),
	join(PI_AGENT_DIR, "git"),
];

// Top-level packages and @scoped/<pkg> (npm layout), plus any package.json at
// relative depth <= 4 (git checkouts).
function candidateManifests(root) {
	const found = [];
	let entries;
	try {
		entries = readdirSync(root, { withFileTypes: true });
	} catch {
		return found;
	}
	const walk = (dir, depth) => {
		for (const entry of readdirSync(dir, { withFileTypes: true })) {
			if (entry.name.startsWith(".")) continue;
			const full = join(dir, entry.name);
			if (entry.isDirectory()) {
				if (depth < 4) walk(full, depth + 1);
			} else if (entry.name === "package.json") {
				found.push(full);
			}
		}
	};
	for (const entry of entries) {
		if (entry.name.startsWith(".")) continue;
		const full = join(root, entry.name);
		if (!entry.isDirectory()) continue;
		if (entry.name.startsWith("@")) {
			let scoped;
			try {
				scoped = readdirSync(full, { withFileTypes: true });
			} catch {
				continue;
			}
			for (const s of scoped) {
				if (!s.isDirectory()) continue;
				const manifest = join(full, s.name, "package.json");
				if (existsSync(manifest)) found.push(manifest);
			}
		} else {
			walk(full, 1);
		}
	}
	return found;
}

function patch(manifest) {
	let data;
	try {
		data = JSON.parse(readFileSync(manifest, "utf8"));
	} catch {
		return false;
	}
	const deps = data.dependencies;
	if (!deps || typeof deps !== "object" || Array.isArray(deps)) return false;
	const toMove = Object.keys(deps)
		.filter((name) => HOST_PROVIDED.has(name))
		.sort();
	if (toMove.length === 0) return false;
	if (!data.peerDependencies || typeof data.peerDependencies !== "object" || Array.isArray(data.peerDependencies)) {
		data.peerDependencies = {};
	}
	for (const name of toMove) {
		data.peerDependencies[name] = "*";
		delete deps[name];
	}
	if (Object.keys(deps).length === 0) delete data.dependencies;
	try {
		writeFileSync(manifest, JSON.stringify(data, null, 2) + "\n");
	} catch {
		return false;
	}
	console.log(`patched ${manifest}: moved ${toMove.join(", ")} -> peerDependencies "*"`);
	return true;
}

for (const root of SCAN_ROOTS) {
	if (!existsSync(root)) continue;
	for (const manifest of candidateManifests(root)) patch(manifest);
}

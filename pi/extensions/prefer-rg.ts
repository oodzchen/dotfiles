/**
 * prefer-rg — 让 pi 优先使用 ripgrep（rg）
 *
 * 背景：pi 内置的 `grep` 工具本身已经是 ripgrep 实现
 * （dist/core/tools/grep.js 里 spawn 的就是 rg --json），但模型在 bash 里
 * 仍然习惯写 `grep -rn ...`。这个扩展做三件事：
 *
 *   1. 在系统提示里追加 guideline：搜文件内容用 grep 工具或 `rg`，
 *      普通 grep 只用来过滤命令输出（如 `journalctl | grep -i error`）。
 *   2. 把 grep 工具的一行说明改写为 "ripgrep-backed"，让模型知道它背后是 rg。
 *   3. 可选强制：拦截 bash 里递归形式的 grep（`grep -r`、`-rn`、`--include`
 *      等文件搜索用法），只放行管道过滤等非递归用法，避免误伤。
 *
 * 用法：/prefer-rg [status|on|off|enforce-on|enforce-off]
 * 配置持久化在 $PI_CODING_AGENT_DIR/prefer-rg.json（默认 ~/.pi/agent/prefer-rg.json）。
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

type PreferRgState = {
	/** 注入系统提示与工具说明 */
	enabled: boolean;
	/** 拦截 bash 里的递归 grep */
	enforce: boolean;
};

const DEFAULT_STATE: PreferRgState = { enabled: true, enforce: true };

const GUIDELINE =
	"Search file contents with the `grep` tool (ripgrep-backed) or `rg` in bash; never use recursive `grep -r`. Plain `grep` is only for filtering command output, e.g. `journalctl | grep -i error`.";

const GREP_SNIPPET = "Search file contents with ripgrep (respects .gitignore)";

function configPath(): string {
	const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
	return join(agentDir, "prefer-rg.json");
}

function loadState(): PreferRgState {
	try {
		const raw = JSON.parse(readFileSync(configPath(), "utf-8")) as Partial<PreferRgState>;
		return {
			enabled: typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_STATE.enabled,
			enforce: typeof raw.enforce === "boolean" ? raw.enforce : DEFAULT_STATE.enforce,
		};
	} catch {
		return { ...DEFAULT_STATE };
	}
}

function saveState(state: PreferRgState): void {
	const file = configPath();
	try {
		mkdirSync(dirname(file), { recursive: true });
		writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`, "utf-8");
	} catch {
		// 配置写入失败不影响本会话内的行为
	}
}

/** 按未加引号的控制符（| & ; 换行 括号）切分命令，避免引号里的内容误判。 */
export function splitSegments(command: string): string[] {
	const segments: string[] = [];
	let current = "";
	let quote: "'" | '"' | null = null;
	let escaped = false;

	for (const ch of command) {
		if (escaped) {
			current += ch;
			escaped = false;
			continue;
		}
		if (ch === "\\" && quote !== "'") {
			current += ch;
			escaped = true;
			continue;
		}
		if (quote) {
			current += ch;
			if (ch === quote) quote = null;
			continue;
		}
		if (ch === "'" || ch === '"') {
			quote = ch;
			current += ch;
			continue;
		}
		if (ch === "|" || ch === "&" || ch === ";" || ch === "\n" || ch === "(" || ch === "`") {
			segments.push(current);
			current = "";
			continue;
		}
		current += ch;
	}
	segments.push(current);
	return segments;
}

/** 按未加引号的空白切分 token，引号本身被去掉。 */
export function tokenize(segment: string): string[] {
	const tokens: string[] = [];
	let current = "";
	let quote: "'" | '"' | null = null;
	let escaped = false;

	const flush = () => {
		if (current) {
			tokens.push(current);
			current = "";
		}
	};

	for (const ch of segment) {
		if (escaped) {
			current += ch;
			escaped = false;
			continue;
		}
		if (ch === "\\" && quote !== "'") {
			escaped = true;
			continue;
		}
		if (quote) {
			if (ch === quote) quote = null;
			else current += ch;
			continue;
		}
		if (ch === "'" || ch === '"') {
			quote = ch;
			continue;
		}
		if (/\s/.test(ch)) {
			flush();
			continue;
		}
		current += ch;
	}
	flush();
	return tokens;
}

/** 命令前缀（sudo/env 等）不改变真正执行的程序，判断 grep 时要跳过。 */
const COMMAND_PREFIXES = new Set(["sudo", "doas", "command", "time", "nohup", "nice", "stdbuf", "env"]);

function commandHead(tokens: string[]): { head: string; args: string[] } | null {
	let i = 0;
	while (i < tokens.length) {
		const token = tokens[i];
		if (COMMAND_PREFIXES.has(token)) {
			i++;
			// 跳过 env/sudo 的 VAR=value 与短选项
			while (i < tokens.length) {
				const next = tokens[i];
				if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(next) || /^--?[A-Za-z]/.test(next)) {
					i++;
					continue;
				}
				break;
			}
			continue;
		}
		if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(token)) {
			i++;
			continue;
		}
		break;
	}
	if (i >= tokens.length) return null;
	return { head: tokens[i], args: tokens.slice(i + 1) };
}

const RECURSIVE_FLAG = /^-[A-Za-z0-9]*[rR][A-Za-z0-9]*$/;
const RECURSIVE_LONG = new Set(["--recursive", "--dereference-recursive", "--directories=recurse"]);
const FILE_FILTER_FLAG = /^--(?:include|exclude|exclude-dir|exclude-from)(?:=|$)/;

/** 判断一条命令里是否有应被拦截的递归 grep；返回命中的片段用于提示。 */
export function findBlockedGrep(command: string): string | null {
	for (const segment of splitSegments(command)) {
		const tokens = tokenize(segment);
		const parsed = commandHead(tokens);
		if (!parsed || parsed.head !== "grep") continue;

		const recursive = parsed.args.some(
			(arg) => RECURSIVE_LONG.has(arg) || FILE_FILTER_FLAG.test(arg) || RECURSIVE_FLAG.test(arg),
		);
		if (recursive) {
			return segment.trim();
		}
	}
	return null;
}

function rgVersion(): string | null {
	try {
		const result = spawnSync("rg", ["--version"], { encoding: "utf-8" });
		if (result.status === 0 && result.stdout) {
			return result.stdout.split("\n")[0]?.trim() || null;
		}
	} catch {
		// rg 不存在
	}
	return null;
}

export default function preferRgExtension(pi: ExtensionAPI) {
	let state = loadState();

	const statusText = (): string => {
		const rg = rgVersion();
		return `prefer-rg: ${state.enabled ? "on" : "off"}, enforce: ${state.enforce ? "on (recursive grep blocked)" : "off"}, rg: ${rg ?? "not found"}`;
	};

	pi.registerCommand("prefer-rg", {
		description: "Prefer ripgrep: /prefer-rg [status|on|off|enforce-on|enforce-off]",
		handler: async (args: string, ctx: ExtensionContext) => {
			const action = (args || "status").trim();
			switch (action) {
				case "on":
				case "off":
					state = { ...state, enabled: action === "on" };
					saveState(state);
					ctx.ui.notify(`prefer-rg ${action}`, "info");
					return;
				case "enforce-on":
				case "enforce-off":
					state = { ...state, enforce: action === "enforce-on" };
					saveState(state);
					ctx.ui.notify(`prefer-rg enforcement ${action === "enforce-on" ? "on" : "off"}`, "info");
					return;
				case "status":
				case "":
					ctx.ui.notify(statusText(), "info");
					return;
				default:
					ctx.ui.notify("Usage: /prefer-rg [status|on|off|enforce-on|enforce-off]", "warning");
			}
		},
	});

	pi.on("before_agent_start", (event) => {
		if (!state.enabled) return;

		const options = event.systemPromptOptions;
		options.toolSnippets = { ...options.toolSnippets, grep: GREP_SNIPPET };
		if (!options.promptGuidelines.includes(GUIDELINE)) {
			options.promptGuidelines.push(GUIDELINE);
		}
	});

	pi.on("tool_call", (event) => {
		if (!state.enabled || !state.enforce) return;
		if (event.toolName !== "bash") return;

		const command = (event.input as { command?: string }).command;
		if (!command) return;

		const blocked = findBlockedGrep(command);
		if (!blocked) return;

		return {
			block: true,
			reason:
				`Blocked recursive grep by prefer-rg: \`${blocked}\`. ` +
				"Use the ripgrep-backed `grep` tool or `rg` in bash instead. " +
				"Plain `grep` is fine for filtering command output (e.g. `journalctl | grep -i error`).",
		};
	});
}

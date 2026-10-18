/**
 * hide-commands — 从 `/` 命令补全菜单里隐藏用不到的内置命令
 *
 * 背景：pi 的内置斜杠命令（dist/core/slash-commands.js 的 BUILTIN_SLASH_COMMANDS）
 * 无法通过 settings.json 关闭，输入 `/` 时总会出现在补全菜单里。这个扩展在内置
 * autocomplete provider 外面包一层，把配置里列出的命令从补全结果中过滤掉。
 * 只影响补全菜单，不影响命令本身：完整输入 `/clone` 回车仍然会执行。
 *
 * 用法：/hide-commands [status|on|off|add <name>|remove <name>|reset]
 * 配置持久化在 $PI_CODING_AGENT_DIR/hide-commands.json（默认 ~/.pi/agent/hide-commands.json）。
 */

import type {
	ExtensionAPI,
	ExtensionCommandContext,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import type { AutocompleteProvider } from "@earendil-works/pi-tui";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

type HideCommandsState = {
	/** 是否启用过滤 */
	enabled: boolean;
	/** 要隐藏的命令名（不带前导 /） */
	hidden: string[];
};

const DEFAULT_STATE: HideCommandsState = {
	enabled: true,
	hidden: ["clone"],
};

const USAGE = "用法: /hide-commands [status|on|off|add <name>|remove <name>|reset]";

function configPath(): string {
	const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
	return join(agentDir, "hide-commands.json");
}

function normalizeName(raw: string): string {
	return raw.trim().replace(/^\//, "");
}

function loadState(): HideCommandsState {
	try {
		const raw = JSON.parse(readFileSync(configPath(), "utf-8")) as Partial<HideCommandsState>;
		const hidden = Array.isArray(raw.hidden)
			? raw.hidden.map((name) => normalizeName(String(name))).filter(Boolean)
			: DEFAULT_STATE.hidden;
		return {
			enabled: typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_STATE.enabled,
			hidden,
		};
	} catch {
		return { enabled: DEFAULT_STATE.enabled, hidden: [...DEFAULT_STATE.hidden] };
	}
}

function saveState(state: HideCommandsState): void {
	const file = configPath();
	try {
		mkdirSync(dirname(file), { recursive: true });
		writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`, "utf-8");
	} catch {
		// 配置写入失败不影响本会话内的行为
	}
}

/**
 * 是否为“正在补全命令名”的状态。
 * 内置 provider 在命令名补全时把整段 commandText（如 `/`、`/clo`）作为 prefix；
 * 进入参数补全后 prefix 是参数文本，不再以 `/` 开头。
 */
function isCommandNamePrefix(prefix: string): boolean {
	return prefix.startsWith("/") && !/\s/.test(prefix.slice(1));
}

/** 每次补全时才读取当前隐藏集合，这样切换配置无需重新注册 provider。 */
function createFilteringProvider(
	current: AutocompleteProvider,
	getHidden: () => ReadonlySet<string>,
): AutocompleteProvider {
	return {
		triggerCharacters: current.triggerCharacters,
		async getSuggestions(lines, cursorLine, cursorCol, options) {
			const result = await current.getSuggestions(lines, cursorLine, cursorCol, options);
			if (!result || result.items.length === 0 || !isCommandNamePrefix(result.prefix)) {
				return result;
			}
			const hidden = getHidden();
			if (hidden.size === 0) {
				return result;
			}
			const items = result.items.filter((item) => !hidden.has(item.value));
			if (items.length === result.items.length) {
				return result;
			}
			return items.length === 0 ? null : { ...result, items };
		},
		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
		},
		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
		},
	};
}

export default function hideCommandsExtension(pi: ExtensionAPI): void {
	let state = loadState();

	pi.on("session_start", (_event, ctx: ExtensionContext) => {
		ctx.ui.addAutocompleteProvider((current) =>
			createFilteringProvider(current, () => new Set(state.enabled ? state.hidden : [])),
		);
	});

	const applyState = (next: HideCommandsState, ctx: ExtensionCommandContext): void => {
		state = next;
		saveState(state);
		const list = state.hidden.length ? state.hidden.map((n) => `/${n}`).join(" ") : "(空)";
		ctx.ui.notify(
			state.enabled ? `hide-commands: 隐藏 ${list}` : "hide-commands: 已关闭（所有命令都会出现在补全中）",
			"info",
		);
	};

	pi.registerCommand("hide-commands", {
		description: "从斜杠命令补全中隐藏指定内置命令",
		argumentHint: "[status|on|off|add <name>|remove <name>|reset]",
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const [subcommand = "status", ...rest] = args.trim().split(/\s+/).filter(Boolean);
			const names = rest.map(normalizeName).filter(Boolean);

			switch (subcommand) {
				case "status": {
					const list = state.hidden.length ? state.hidden.map((n) => `/${n}`).join(", ") : "(空)";
					ctx.ui.notify(`hide-commands: ${state.enabled ? "已启用" : "已关闭"}，隐藏: ${list}`, "info");
					return;
				}
				case "on":
					applyState({ ...state, enabled: true }, ctx);
					return;
				case "off":
					applyState({ ...state, enabled: false }, ctx);
					return;
				case "add": {
					if (names.length === 0) {
						ctx.ui.notify(USAGE, "error");
						return;
					}
					applyState({ ...state, enabled: true, hidden: [...new Set([...state.hidden, ...names])] }, ctx);
					return;
				}
				case "remove": {
					if (names.length === 0) {
						ctx.ui.notify(USAGE, "error");
						return;
					}
					const drop = new Set(names);
					applyState({ ...state, hidden: state.hidden.filter((name) => !drop.has(name)) }, ctx);
					return;
				}
				case "reset":
					applyState({ enabled: DEFAULT_STATE.enabled, hidden: [...DEFAULT_STATE.hidden] }, ctx);
					return;
				default:
					ctx.ui.notify(USAGE, "error");
			}
		},
	});
}

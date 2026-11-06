/**
 * remember-last-model
 *
 * Makes the model + thinking level you last picked the defaults for new sessions,
 * so you never have to press Ctrl+S in /model or /thinking again.
 *
 * How it works:
 * - Every explicit model change (/model, Ctrl+P cycling, pi.setModel) records
 *   { provider, id, thinkingLevel } into <agent-dir>/last-model.json.
 * - Every explicit thinking-level change updates the recorded level. Level changes
 *   that are only a side effect of switching models are ignored.
 * - On session_start with reason "startup" or "new" the recorded pair is applied.
 *   Resumed/forked sessions keep their own model.
 *
 * It never writes settings.json, so it cannot race with Pi's own settings writer.
 * Disable with `/reload` after renaming the file, or delete it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";

type Remembered = {
	provider: string;
	id: string;
	thinkingLevel?: string;
};

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
const STATE_PATH = join(AGENT_DIR, "last-model.json");
const APPLY_RETRY_DELAYS = [0, 500, 1500];
const VALID_LEVELS = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);

function modelKey(provider: string, id: string): string {
	return `${provider}/${id}`;
}

async function readState(): Promise<Remembered | undefined> {
	try {
		const parsed = JSON.parse(await readFile(STATE_PATH, "utf8")) as Remembered;
		if (typeof parsed?.provider !== "string" || typeof parsed?.id !== "string") return undefined;
		return parsed;
	} catch {
		return undefined;
	}
}

async function writeState(state: Remembered): Promise<void> {
	try {
		await mkdir(dirname(STATE_PATH), { recursive: true });
		const tmp = `${STATE_PATH}.tmp`;
		await writeFile(tmp, `${JSON.stringify(state, null, "\t")}\n`, "utf8");
		await rename(tmp, STATE_PATH);
	} catch {
		// Best effort: remembering the model must never break a session.
	}
}

export default function rememberLastModel(pi: ExtensionAPI): void {
	// provider/id that the record currently describes; used to tell a
	// model-switch-induced level change from a user-initiated one.
	let recordedKey: string | undefined;

	pi.on("session_start", async (event, ctx) => {
		recordedKey = ctx.model ? modelKey(ctx.model.provider, ctx.model.id) : undefined;
		if (event.reason !== "startup" && event.reason !== "new") return;

		const saved = await readState();
		if (!saved) return;

		const apply = async (attempt: number): Promise<void> => {
			const model = ctx.modelRegistry.find(saved.provider, saved.id);
			if (!model) {
				const delay = APPLY_RETRY_DELAYS[attempt];
				if (delay !== undefined) {
					setTimeout(() => void apply(attempt + 1), delay);
				}
				return;
			}
			try {
				// Throws when the provider has no usable credentials; nothing to do then.
				const applied = await pi.setModel(model);
				if (!applied) return;
				recordedKey = modelKey(model.provider, model.id);
				if (saved.thinkingLevel && VALID_LEVELS.has(saved.thinkingLevel)) {
					pi.setThinkingLevel(saved.thinkingLevel as ThinkingLevel);
				}
			} catch {
				// Keep the session's current model rather than failing startup.
			}
		};

		void apply(0);
	});

	pi.on("model_select", async (event) => {
		recordedKey = modelKey(event.model.provider, event.model.id);
		await writeState({
			provider: event.model.provider,
			id: event.model.id,
			thinkingLevel: pi.getThinkingLevel(),
		});
	});

	pi.on("thinking_level_select", async (event, ctx) => {
		const model = ctx.model;
		if (!model) return;
		// A model switch changes the level first and emits model_select afterwards;
		// model_select records both halves, so skip the intermediate value here.
		if (recordedKey !== undefined && recordedKey !== modelKey(model.provider, model.id)) {
			recordedKey = modelKey(model.provider, model.id);
			return;
		}
		await writeState({ provider: model.provider, id: model.id, thinkingLevel: event.level });
	});
}

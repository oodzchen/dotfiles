import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

export type ErrorCategory =
	| "NETWORK_TIMEOUT"
	| "CONNECTION_FAILURE"
	| "RATE_LIMIT"
	| "UPSTREAM_SERVER_ERROR"
	| "AUTHENTICATION_ERROR"
	| "CONTEXT_OVERFLOW"
	| "CONTENT_FILTER"
	| "CLIENT_ABORT"
	| "UNKNOWN_ERROR";

export interface ClassifiedError {
	source: {
		provider: string;
		model: string;
		api: string;
	};
	category: ErrorCategory;
	rawMessage: string;
	description: string;
	timestamp: number;
}

const ENTRY_TYPE = "error-diagnostic";

function classifyError(
	msg: {
		provider?: string;
		model?: string;
		api?: string;
		stopReason?: string;
		errorMessage?: string;
	},
	fallbackModel?: { provider?: string; id?: string; api?: string },
): ClassifiedError {
	const rawMessage = (msg.errorMessage || "").trim();
	const provider = msg.provider || fallbackModel?.provider || "unknown";
	const model = msg.model || fallbackModel?.id || "unknown";
	const api = msg.api || fallbackModel?.api || "unknown";
	const stopReason = msg.stopReason || "error";

	let category: ErrorCategory = "UNKNOWN_ERROR";
	let description = "Unclassified error occurred during model interaction.";

	// 1. Network timeout / transport aborted
	if (
		/the operation was aborted/i.test(rawMessage) ||
		/this operation was aborted/i.test(rawMessage) ||
		/\b(?:timed?\s*out|timeout|etimedout|deadline\s*exceeded)\b/i.test(rawMessage)
	) {
		category = "NETWORK_TIMEOUT";
		description = "Request timed out or was terminated by client/gateway transport before completion.";
	}
	// 2. Client manual abort
	else if (
		stopReason === "aborted" &&
		(!rawMessage || /operation aborted|user aborted|cancelled/i.test(rawMessage))
	) {
		category = "CLIENT_ABORT";
		description = "Operation was manually aborted by the user.";
	}
	// 3. Network connection failures
	else if (
		/\b(?:fetch failed|econnreset|econnrefused|enotfound|eai_again|socket hang up|connection.*lost|connection.*error|connection.*refused|network.*error|terminated|other side closed)\b/i.test(
			rawMessage,
		)
	) {
		category = "CONNECTION_FAILURE";
		description = "Network connection failed, reset, or was refused.";
	}
	// 4. Rate limits
	else if (
		/\b(?:429|rate\s*limit|too\s*many\s*requests|resource\s*exhausted|quota|out\s*of\s*budget)\b/i.test(
			rawMessage,
		)
	) {
		category = "RATE_LIMIT";
		description = "Provider rate limit, concurrency limit, or quota exhausted.";
	}
	// 5. Upstream server errors
	else if (
		/\b(?:500|502|503|504|520|524|internal\s*server\s*error|bad\s*gateway|service\s*unavailable|gateway\s*timeout|provider\s*returned\s*error|server\s*error)\b/i.test(
			rawMessage,
		)
	) {
		category = "UPSTREAM_SERVER_ERROR";
		description = "Upstream provider server returned an HTTP 5xx error or internal failure.";
	}
	// 6. Authentication errors
	else if (
		/\b(?:401|403|unauthorized|forbidden|invalid.*api.*key|authentication|access\s*denied)\b/i.test(
			rawMessage,
		)
	) {
		category = "AUTHENTICATION_ERROR";
		description = "Authentication failed. Check API key, permissions, or account access.";
	}
	// 7. Context overflow
	else if (
		/\b(?:context.*(?:overflow|length|window|exceeded)|maximum\s*context\s*length|prompt\s*is\s*too\s*long|too\s*many\s*tokens)\b/i.test(
			rawMessage,
		)
	) {
		category = "CONTEXT_OVERFLOW";
		description = "Prompt tokens exceeded the model's maximum context window.";
	}
	// 8. Content filter
	else if (/\b(?:content\s*filter|safety|moderation|policy\s*violation)\b/i.test(rawMessage)) {
		category = "CONTENT_FILTER";
		description = "Request or response was blocked by upstream provider content / safety policies.";
	}

	return {
		source: { provider, model, api },
		category,
		rawMessage: rawMessage || (stopReason === "aborted" ? "Operation aborted" : "Unknown error"),
		description,
		timestamp: Date.now(),
	};
}

export default function (pi: ExtensionAPI) {
	let lastError: ClassifiedError | undefined;

	// Render diagnostic entry directly in the transcript
	pi.registerEntryRenderer<ClassifiedError>(ENTRY_TYPE, (entry, _options, theme) => {
		const data = entry.data;
		if (!data) return undefined;

		const box = new Box(1, 1, (t) => theme.bg("customMessageBg", t));
		box.addChild(
			new Text(
				`${theme.bold(theme.fg("error", "✖ ERROR DIAGNOSTIC"))} · ${theme.bold(theme.fg("warning", data.category))}`,
				0,
				0,
			),
		);
		box.addChild(
			new Text(
				`${theme.fg("muted", "Source:   ")} ${data.source.provider} / ${data.source.model} (${data.source.api})`,
				0,
				0,
			),
		);
		box.addChild(
			new Text(`${theme.fg("muted", "Category: ")} ${theme.fg("warning", data.category)}`, 0, 0),
		);
		box.addChild(new Text(`${theme.fg("muted", "Details:  ")} ${data.rawMessage}`, 0, 0));
		box.addChild(new Text(`${theme.fg("muted", "Reason:   ")} ${theme.fg("dim", data.description)}`, 0, 0));
		return box;
	});

	// Inspect assistant messages on turn end
	pi.on("turn_end", (event, ctx) => {
		if (event.message?.role !== "assistant") return;
		const msg = event.message as {
			role: string;
			stopReason?: string;
			errorMessage?: string;
			provider?: string;
			model?: string;
			api?: string;
		};

		// Only handle actual errors or unexpected aborts (skip normal completions and explicit user aborts)
		if (msg.stopReason === "error") {
			const classified = classifyError(msg, ctx.model);
			lastError = classified;

			// Append diagnostic entry to the session
			pi.appendEntry(ENTRY_TYPE, classified);

			// Surface immediate notification in UI
			if (ctx.hasUI) {
				const notifyText = `[${classified.category}] ${classified.source.provider}/${classified.source.model}: ${classified.rawMessage}`;
				ctx.ui.notify(notifyText, "error");
			}
		}
	});

	// Optional command to inspect the latest error
	pi.registerCommand("last-error", {
		description: "Display the latest classified error details",
		handler: async (_args, ctx) => {
			if (!lastError) {
				if (ctx.hasUI) ctx.ui.notify("No recent error recorded", "info");
				return;
			}
			const time = new Date(lastError.timestamp).toLocaleTimeString();
			if (ctx.hasUI) {
				ctx.ui.notify(
					`[${lastError.category}] ${lastError.source.provider}/${lastError.source.model}: ${lastError.rawMessage} (${time})`,
					"warning",
				);
			}
		},
	});
}

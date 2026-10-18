/**
 * Clear Alias Extension
 *
 * 习惯用 /clear 开新会话，但这个命令 pi 里叫 /new。
 * 这里注册一个 /clear 扩展命令，内部走与内置 /new 完全相同的
 * ctx.newSession() 路径（清空上下文、开新 session 文件）。
 *
 * 用法：/clear（无需参数）
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function clearAliasExtension(pi: ExtensionAPI) {
	pi.registerCommand("clear", {
		description: "Start a new session (alias for /new)",
		handler: async (_args, ctx) => {
			// 会话替换后旧 ctx / pi 立即失效，任何后续操作必须放到 withSession 里，
			// 并用它传入的新 ctx。
			await ctx.newSession({
				withSession: async (next) => {
					next.ui.notify("✓ New session started", "info");
				},
			});
		},
	});
}

;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

;; 彻底阻止 Emacs 启动时自动初始化 package.el，避免与 straight.el 冲突
(setq package-enable-at-startup nil)

(provide 'early-init)
;;; early-init.el ends here

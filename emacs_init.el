;;; init.el --- My Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; This is my personal Emacs configuration

;;; Code:

;; editor
(setq select-enable-clipboard t)
(setq dired-listing-switches "-aBhl  --group-directories-first")
(setq inhibit-startup-screen t)
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                 "%b"))
		(:eval (if (buffer-modified-p)
                   " *"))
		" - Emacs"))

(setenv "LSP_USE_PLISTS" "true")

(setq-default js-indent-level 2)
(setq-default tab-width 4)
(setq debug-on-error t)
(setq-default cursor-type 'bar)
(setq-default linum-format "%d ") ;; Integer followed by space
(setq-default mode-line-format
	      '("%e"
		mode-line-front-space
		mode-line-mule-info
		mode-line-client
		mode-line-modified
		mode-line-remote
		mode-line-frame-identification
		;; mode-line-buffer-identification
		(:eval (abbreviate-file-name (buffer-file-name)))
		"  "
		mode-line-position

		(vc-mode vc-mode)
		"  "
		mode-line-modes
		mode-line-misc-info
		mode-line-end-spaces))
(setq backup-directory-alist '(("." . "~/.emacs_backups")))
;; (setq-default company-quickhelp-color-background "#000000")
(setq-default web-mode-engines-alist
	      '(("go"    . "\\.tmpl\\'"))
	      )
(setq-default prettier-js-use-modules-bin t)
(setq-default typescript-indent-level 2)
(setq-default typescript-auto-indent-flag t)

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(electric-pair-mode t)
(global-auto-revert-mode 1)
(column-number-mode 1)
(recentf-mode 1)
;; (global-linum-mode t)

(global-display-line-numbers-mode 1)
;; Alternatively, to use it only in programming modes:
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(add-to-list 'load-path "~/.emacs.d/lisp/")

(add-to-list 'default-frame-alist '(height . 50))
(add-to-list 'default-frame-alist '(width . 100))
(add-to-list 'default-frame-alist '(font . "DejaVu Sans Mono"))

;; proxy
(setq url-proxy-services
      '(("no_proxy" . "^\\(localhost\\|10\\..*\\|192\\.168\\..*\\)")
	("http" . "127.0.0.1:1089")
	("https" . "127.0.0.1:1089")))

(setq-default url-queue-timeout 30)

;; straight.el
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(setq package-enable-at-startup nil)
(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-blue ((t (:background "blue2" :foreground "cyan")))))

(use-package magit
  :straight t
  :bind ("C-x g" . magit-status))

(use-package docker
  :straight t)

(use-package docker-compose-mode
  :straight t)

(use-package dockerfile-mode
  :straight t)

(use-package dumb-jump
  :straight t
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

(use-package keyfreq
  :straight t
  :config
  (keyfreq-mode 1)
  (keyfreq-autosave-mode 1))

(use-package rg
  :straight t)

(use-package ripgrep
  :straight t)

(use-package restart-emacs
  :straight t)

(use-package vterm
  :straight t)

;; (use-package eat
;;   :straight t)

(use-package zeno-theme
  :straight t
  :config
  (load-theme 'zeno t))

;; 如果你需要补全框架（你已经用了 corfu，可能不需要）
;; (use-package company
;;   :straight t
;;   :hook (after-init . global-company-mode))

;; (use-package company-box
;;   :straight t
;;   :hook (company-mode . company-box-mode))

;; (use-package company-quickhelp
;;   :straight t
;;   :hook (company-mode . company-quickhelp-mode))

;; TypeScript 支持
(use-package typescript-mode
  :straight t
  :mode (("\\.ts\\'" . typescript-mode)
         ("\\.js\\'" . typescript-mode)))

(use-package web-mode
  :straight t
  :mode (("\\.tsx\\'" . web-mode)
         ("\\.jsx\\'" . web-mode)
         ("\\.tmpl\\'" . web-mode))
  :config
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2  
        web-mode-code-indent-offset 2
        web-mode-attr-indent-offset 2
        web-mode-attr-value-indent-offset 2
        web-mode-enable-auto-pairing t
        web-mode-enable-auto-closing t
        web-mode-enable-current-element-highlight t
        web-mode-enable-current-column-highlight t))

(use-package flycheck
  :init (global-flycheck-mode)
  :config
  (setq flycheck-emacs-lisp-load-path 'inherit)
  
  ;; 启用 ESLint，禁用其他 JavaScript 检查器
  (setq-default flycheck-disabled-checkers 
                '(javascript-jshint 
                  typescript-tslint))
  
  ;; ESLint 9 配置
  (setq-default flycheck-eslint-rules-directories nil)  ; 使用项目的 ESLint 配置
  (setq-default flycheck-eslint-args nil)               ; 额外的 ESLint 参数
  
  ;; 优化检查频率
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  
  ;; 确保 ESLint 能找到正确的工作目录
  (setq flycheck-javascript-eslint-executable "eslint")
  
  ;; 智能 ESLint 配置检查（支持 ESLint 9 的扁平配置）
  (defun my-flycheck-eslint-config-exists-p ()
    "Check if ESLint config exists, including ESLint 9 flat config files."
    (let ((default-directory (or (flycheck-eslint--find-working-directory 'javascript-eslint)
                                 default-directory)))
      (or (file-exists-p "eslint.config.js")     ; ESLint 9 扁平配置
          (file-exists-p "eslint.config.mjs")    ; ESLint 9 扁平配置 (ES modules)
          (file-exists-p ".eslintrc.js")         ; 传统配置
          (file-exists-p ".eslintrc.json")
          (file-exists-p ".eslintrc.yml")
          (file-exists-p ".eslintrc.yaml")
          (file-exists-p ".eslintrc"))))
  
  ;; 覆盖默认的配置检查以支持 ESLint 9
  (advice-add 'flycheck-eslint-config-exists-p :override #'my-flycheck-eslint-config-exists-p)
  
  ;; 确保在 JavaScript 模式下启用 flycheck
  (add-hook 'js-mode-hook 'flycheck-mode)
  (add-hook 'typescript-mode-hook 'flycheck-mode)
  (add-hook 'web-mode-hook 'flycheck-mode)
  
  ;; 强制在 web-mode 和 typescript-mode 中使用 ESLint
  (defun my-force-eslint-in-js-ts ()
    "Force ESLint selection and prevent LSP from overriding it."
    (when (or (eq major-mode 'typescript-mode)
              (and (eq major-mode 'web-mode)
                   (member (file-name-extension buffer-file-name) '("tsx" "jsx"))))
      (flycheck-mode 1)
      ;; 立即设置
      (setq-local flycheck-checker 'javascript-eslint)
      ;; 延迟设置以防被覆盖
      (run-with-timer 0.2 nil
                      (lambda (buf)
                        (when (buffer-live-p buf)
                          (with-current-buffer buf
                            (setq-local flycheck-checker 'javascript-eslint)
                            (when flycheck-mode (flycheck-buffer)))))
                      (current-buffer))
      ;; 再次延迟设置以确保生效
      (run-with-timer 1.0 nil
                      (lambda (buf)
                        (when (buffer-live-p buf)
                          (with-current-buffer buf
                            (unless (eq flycheck-checker 'javascript-eslint)
                              (setq-local flycheck-checker 'javascript-eslint)
                              (when flycheck-mode (flycheck-buffer))))))
                      (current-buffer))))
  
  (add-hook 'typescript-mode-hook #'my-force-eslint-in-js-ts)
  (add-hook 'web-mode-hook #'my-force-eslint-in-js-ts)
  
  ;; 扩展 javascript-eslint 检查器支持的模式
  (with-eval-after-load 'flycheck
    ;; 为 javascript-eslint 检查器添加 web-mode 支持
    (flycheck-add-mode 'javascript-eslint 'web-mode))
  
  :bind (("C-c e" . flycheck-list-errors)        ; 显示错误列表
         ("C-c n" . flycheck-next-error)         ; 下一个错误
         ("C-c p" . flycheck-previous-error)     ; 上一个错误
         ("C-c c" . flycheck-buffer)))            ; 检查缓冲区

(use-package lsp-mode
  :init
  ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
  ;; (setq lsp-keymap-prefix "C-c l")
  (setq lsp-auto-guess-root t)
  (setq lsp-use-plists t)
  
  :hook ((go-mode . lsp-deferred)
         (python-ts-mode . lsp-deferred)
         (rust-ts-mode . lsp-deferred)
         (c-ts-mode . lsp-deferred)
         (c++-ts-mode . lsp-deferred)
         (java-mode . lsp-deferred)
         (js-mode . lsp-deferred)
         (typescript-mode . lsp-deferred)
         (web-mode . (lambda () 
                       (when (member (file-name-extension buffer-file-name) '("tsx" "jsx"))
                         (lsp-deferred))))
         (yaml-mode . lsp-deferred)
         (json-ts-mode . lsp-deferred)
         (lsp-mode . lsp-enable-which-key-integration))
  
  :commands (lsp lsp-deferred)
  :config
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point
        lsp-ui-doc-header t
        lsp-ui-doc-include-signature t
	    lsp-ui-doc-delay 1
	    lsp-ui-doc-show-with-cursor t
		;; lsp-clients-typescript-tls-path "typescript-language-server"
	    lsp-completion-provider :none)
  
  ;; TypeScript LSP configuration
  (setq lsp-clients-typescript-tls-path "typescript-language-server")
  
  (use-package lsp-ui
    :after lsp-mode
    :config
    (setq lsp-ui-doc-enable t)           ; 文档模块
    (setq lsp-ui-sideline-enable t)      ; 侧边栏模块
    (setq lsp-ui-peek-enable t)          ; 预览模块
	(setq lsp-ui-flycheck-enable nil)
    (setq lsp-ui-imenu-enable t))     ; 错误检查模块

  ;; (use-package lsp-completion
  ;;   :no-require
  ;;   :hook ((lsp-mode . lsp-completion-mode)))

  :preface
      (defun lsp-booster--advice-json-parse (old-fn &rest args)
        "Try to parse bytecode instead of json."
        (or
         (when (equal (following-char) ?#)

           (let ((bytecode (read (current-buffer))))
             (when (byte-code-function-p bytecode)
               (funcall bytecode))))
         (apply old-fn args)))
      (defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
        "Prepend emacs-lsp-booster command to lsp CMD."
        (let ((orig-result (funcall old-fn cmd test?)))
          (if (and (not test?)                             ;; for check lsp-server-present?
                   (not (file-remote-p default-directory)) ;; see lsp-resolve-final-command, it would add extra shell wrapper
                   lsp-use-plists
                   (not (functionp 'json-rpc-connection))  ;; native json-rpc
                   (executable-find "emacs-lsp-booster"))
              (progn
                (message "Using emacs-lsp-booster for %s!" orig-result)
                (cons "emacs-lsp-booster" orig-result))
            orig-result)))
      :init
      ;; Initiate https://github.com/blahgeek/emacs-lsp-booster for performance
      (advice-add (if (progn (require 'json)
                             (fboundp 'json-parse-buffer))
                      'json-parse-buffer
                    'json-read)
                  :around
                  #'lsp-booster--advice-json-parse)
      (advice-add 'lsp-resolve-final-command :around #'lsp-booster--advice-final-command))

(defun my-go-mode-hook ()
  ;; Use goimports instead of go-fmt
  (setq-default gofmt-command "goimports")
  ;; Call Gofmt before saving
  (add-hook 'before-save-hook 'gofmt-before-save)
  (unbind-key "C-c C-d" 'go-mode-map)
  ;; Customize compile command to run go build
  ;; (if (not (string-match "go" compile-command))
  ;;     (set (make-local-variable 'compile-command)
  ;;          "go build -v && go test -v && go vet"))
  ;; Godef jump key binding
  ;; (local-set-key (kbd "M-.") 'godef-jump)
  ;; (local-set-key (kbd "M-*") 'pop-tag-mark)
  )

(use-package go-mode
  :hook ((go-mode . my-go-mode-hook)
	 (go-mode . hs-minor-mode)))

;; (use-package helm
;;   :init
;;   (setq helm-mini-default-sources 
;;       '(helm-source-buffers-list
;;         helm-source-recentf))
;;   :config
;;   (helm-mode 1)
;;   :bind (("M-x" . helm-M-x)
;;          ("C-x C-b" . helm-mini)
;;          ("C-x C-f" . helm-find-files)))

(use-package multiple-cursors
  :bind (("C-c m c" . mc/edit-lines)
         ("C-c m n" . mc/mark-next-like-this)
         ("C-c m p" . mc/mark-previous-like-this)
         ("C-c m a" . mc/mark-all-like-this)))

(use-package projectile
  :config
  (projectile-mode +1)
  :bind
  (("C-c p" . projectile-command-map)))

;; (use-package neotree
;;   :bind(("C-c n" . neotree-toggle)))

(use-package yafolding
  :config
  (yafolding-mode 1)
  :bind
  (("C-{" . yafolding-hide-element)
   ("C-}" . yafolding-show-element)))

;; (use-package god-mode
;;   ;; :init
;;   ;; (god-mode-all)
;;   :hook (after-init . god-mode)
;;   :bind (("C-c g" . god-mode-all)
;; 	 ("<escape>" . god-mode-all)))

(use-package which-key
  :config
  (which-key-mode +1))

(use-package corfu
  :custom
  (corfu-cycle t)                 ; Allows cycling through candidates
  (corfu-auto t)                  ; Enable auto completion
  (corfu-auto-prefix 2)           ; Minimum length of prefix for completion
  (corfu-auto-delay 0)            ; No delay for completion
  (corfu-popupinfo-delay '(0.5 . 0.2))
  (corfu-preview-current 'insert) ; insert previewed candidate
  (corfu-preselect 'prompt)
  (corfu-on-exact-match nil)
  
  :bind
  (:map corfu-map
        ("C-n" . corfu-next)
        ("C-p" . corfu-previous)
        ("RET" . corfu-insert)
        ("TAB" . corfu-complete)
        ("<tab>" . corfu-complete)
        ("M-d" . corfu-info-documentation)  ; 手动显示文档
        ("M-l" . corfu-info-location)       ; 显示位置信息
        ("C-g" . corfu-quit))               ; 退出补全
  
  :init
  (global-corfu-mode)
  (corfu-echo-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode)
  
  :config
  (add-hook 'eshell-mode-hook
            (lambda () 
              (setq-local corfu-quit-at-boundary t
                          corfu-quit-no-match t
                          corfu-auto nil)
              (corfu-mode))
            nil t))

;; Cape 提供补全后端
(use-package cape
  :init
  ;; 添加到 completion-at-point-functions
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-elisp-block)
  (add-to-list 'completion-at-point-functions #'cape-keyword)
  (add-to-list 'completion-at-point-functions #'cape-abbrev))

;; Kind-icon 提供图标支持
(use-package kind-icon
  :after corfu
  :custom
  (kind-icon-default-face 'corfu-default)
  (kind-icon-default-style '(:padding 0 :stroke 0 :margin 0 :radius 0 :height 0.5 :scale 1.0))
  :config
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

(use-package vertico
  :straight t
  :init
  (vertico-mode)
  :custom
  (vertico-cycle t)                ; 循环选择
  (vertico-resize t)               ; 自动调整大小
  (vertico-count 15)               ; 显示的候选数量
  :bind (:map vertico-map
              ("C-n" . vertico-next)
              ("C-p" . vertico-previous)
              ;; ("C-f" . vertico-exit)
              ("C-g" . minibuffer-keyboard-quit))
  :config
  ;; 自定义 vertico 选中项的颜色
  (custom-set-faces
   '(vertico-current ((t (:background "#3a3a3a" :foreground "#ffffff" :weight bold))))
   '(vertico-group-title ((t (:foreground "#888888" :weight bold))))
   '(vertico-group-separator ((t (:foreground "#444444"))))))

;; (with-eval-after-load 'vertico
;;   (custom-set-faces
;;    '(vertico-current ((t (:background "#3a3a3a" :foreground "#ffffff"))))
;;    '(marginalia-documentation ((t (:foreground "#888888"))))))

;; Orderless 改善匹配
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Marginalia - 为候选项添加注释信息
(use-package marginalia
  :straight t
  :init
  (marginalia-mode)
  :bind (:map minibuffer-local-map
         ("M-A" . marginalia-cycle)))

;; Consult - 提供各种搜索和导航命令
(use-package consult
  :straight t
  :bind (;; 替代 helm-mini (切换buffer)
         ("C-x C-b" . consult-buffer)
         ("C-x b" . consult-buffer)
         ;; 替代 helm-find-files (查找文件)
         ("C-x C-f" . find-file)  ; 保持原生，或使用 consult-find
         ;; 替代 helm-M-x
         ("M-x" . execute-extended-command)  ; 使用增强的原生版本
         ;; 其他有用的替代
         ;; ("C-s" . consult-line)           ; 替代 helm-occur
         ;; ("C-c s" . consult-ripgrep)      ; 替代 helm-rg
         ;; ("C-c f" . consult-find)         ; 查找文件
         ("C-c r" . consult-recent-file)  ; 最近文件
         ;; ("C-c g" . consult-goto-line)    ; 跳转行
         ("C-c i" . consult-imenu)        ; 符号导航
         ("M-g e" . consult-compile-error)
         ;; ("M-g f" . consult-flymake)
         ("M-y" . consult-yank-pop))      ; 替代 helm-show-kill-ring
  :config
  (consult-customize
   consult-buffer :preview-key nil)
  (setq consult-preview-key 'any)
  (setq consult-ripgrep-args "rg --null --line-buffered --color=never --max-columns=1000 --path-separator /   --smart-case --no-heading --with-filename --line-number --search-zip --hidden --glob=!.git/"))

;; Embark - 提供上下文操作
(use-package embark
  :straight t
  :bind (("C-." . embark-act)         ; 在候选项上执行操作
         ("C-;" . embark-dwim)        ; 智能操作
         ("C-h B" . embark-bindings)) ; 显示所有可用操作
  :init
  ;; 可选：将 which-key 集成到 embark
  (setq prefix-help-command #'embark-prefix-help-command))

;; Embark-Consult 集成
(use-package embark-consult
  :straight t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; 增强的 completion-at-point
(use-package consult-dir
  :straight t
  :bind (("C-x C-d" . consult-dir)
         :map vertico-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file)))

(use-package yasnippet
  :config
  (yas-global-mode 1))

(use-package expand-region
  :bind (("C-'" . er/expand-region)))

(use-package view
  :bind (:map view-mode-map
	      ("n" . next-line)
	      ("p" . previous-line)
	      ("v" . scroll-up-command)
	      ("M-v" . scroll-down-command)))

(use-package emmet-mode
  :hook ((web-mode . emmet-mode)))

(use-package winum
  :config (winum-mode 1))

(use-package prettier-js
  :hook ((web-mode . prettier-js-mode)
         (js-mode . prettier-js-mode)
         (typescript-mode . prettier-js-mode)))

(use-package claude-code-ide
  :straight (:type git :host github :repo "manzaltu/claude-code-ide.el")
  :bind ("C-c C-'" . claude-code-ide-menu) ; Set your favorite keybinding
  :config
  (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools

(straight-use-package
 '(lsp-tailwindcss :type git :host github :repo "merrickluo/lsp-tailwindcss"))

(use-package lsp-tailwindcss
  :straight t
  :after lsp-mode
  :init
  ;; Specify major modes where tailwind LSP should activate
  (setq lsp-tailwindcss-major-modes 
        '(rjsx-mode web-mode html-mode css-mode 
          typescript-mode typescript-tsx-mode js-mode))
  
  ;; Run in add-on mode to prevent server conflicts
  (setq lsp-tailwindcss-add-on-mode t))

(use-package deadgrep
  :straight t)

(require 'bind-key)
;; Global keybindings with highest priority (override mode-specific bindings)
(bind-key* "M-p" 'backward-paragraph)
(bind-key* "M-n" 'forward-paragraph)
(bind-key* "C-<return>" 'browse-url-at-point)
(bind-key* "C-c C-/" 'comment-line)
(bind-key* "C-c C-<tab>" 'previous-buffer)
;; (bind-key* "C-c C-s" 'projectile-ripgrep)
(bind-key* "C-c C-s" 'consult-ripgrep)
(bind-key* "C-c s" 'deadgrep)
(bind-key* "C-c g" 'god-mode-all)
(bind-key* "C-," 'god-mode-all)
(bind-key* "C-c C-d" 'mc/mark-next-like-this)
(bind-key* "C-c C-f" 'projectile-find-file)
(bind-key* "C-c C-r" 'rg)

(provide '.emacs)

(put 'narrow-to-region 'disabled nil)

;; (add-hook 'go-mode-hook 'lsp-deferred)

(add-hook 'html-mode-hook 'emmet-mode)
;; (add-hook 'minibuffer-setup-hook )
;; (add-hook 'after-init-hook 'global-company-mode)

(delete-selection-mode 1)

;;; .emacs ends here

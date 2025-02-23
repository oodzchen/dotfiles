;;; $doomdir/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:

(set-fontset-font t 'han "Noto Sans CJK SC Regular")

(setq doom-theme 'zeno)
(set-face-attribute 'show-paren-match nil
                    :background "#333333"
                    :foreground "#E8F0FF"
                    :weight 'bold)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+'.)
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; you can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(setq lsp-use-plists "true")
(setq debug-on-error nil)

(setq confirm-kill-emacs nil)
(setq warning-minimum-level :error)
(setq +default-want-RET-continue-comments nil)
(setq dired-listing-switches "-aBhl  --group-directories-first")
(setq initial-major-mode 'c-mode)
(setq go-tag-args (list "-transform" "camelcase"))
(setq lsp-modeline-code-actions-enable nil)
(setq yas-snippet-revival nil) ;; To prevent yas breaks undo history
(setq sqlformat-command 'pgformatter)
;; (setq +format-with-lsp nil)

(global-set-key (kbd "C-x C-b") 'helm-mini)
(global-set-key (kbd "M-p") 'backward-paragraph)
(global-set-key (kbd "M-n") 'forward-paragraph)
(global-set-key (kbd "C-<return>") 'browse-url-at-point)
(global-set-key (kbd "C-c C-/") 'comment-line)
(global-set-key (kbd "C-c C-<tab>") 'previous-buffer)
(global-set-key (kbd "C-c C-d") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c C-r") '+default/search-project)
(global-set-key (kbd "C-c C-s") '+default/search-project)
(global-set-key (kbd "C-c m c") 'mc/edit-lines)
(global-set-key (kbd "C-a") 'move-beginning-of-line)
(global-set-key (kbd "C-e") 'move-end-of-line)
(global-set-key (kbd "C-<") 'web-mode-fold-or-unfold)
(global-set-key (kbd "C->") 'web-mode-fold-or-unfold)
(global-set-key (kbd "C-c g") 'god-mode-all)
(global-set-key (kbd "C-,") 'god-mode-all)

;; (global-set-key (kbd "C-c m n") 'mc/mark-next-like-this)
;; (global-set-key (kbd "C-c m p") 'mc/mark-previous-like-this)
;; (global-set-key (kbd "C-c m a") 'mc/mark-all-like-this)

;; (add-to-list 'default-frame-alist '(height . 50))
;; (add-to-list 'default-frame-alist '(width . 100))
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(add-to-list 'default-frame-alist '(font . "DejaVu Sans Mono"))

(map! "C-j" #'emmet-expand-line)

(after! lsp-mode
  (setq lsp-auto-guess-root t))

(after! lsp-ui
  (setq lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point
        lsp-ui-doc-show-with-cursor t))

;; (after! company
;;   (setq company-tooltip-maximum-width 50)
;;   (setq company-minimum-prefix-length 3))

;; (use-package! company-quickhelp
;;   :hook (company-mode . company-quickhelp-mode))

(use-package! lsp-tailwindcss
  :init
  (setq lsp-tailwindcss-add-on-mode t
        lsp-tailwindcss-major-modes '(rjsx-mode
                                      web-mode
                                      html-mode
                                      css-mode
                                      typescript-mode
                                      typescript-tsx-mode
                                      tsx-ts-mode)))

;; (use-package! exec-path-from-shell
;;   :init)

(use-package! web-mode
  :mode
  (("\\.tmpl\\'" . web-mode)))

(use-package! prettier-js
  :hook (web-mode . prettier-js-mode))

(after! web-mode
  (setq web-mode-enable-auto-indentation nil))

(use-package! god-mode
  :config
  (god-mode)
  (god-mode-all))

(require 'diminish)
(diminish 'projectile-mode)

;; (load! "~/.config/doom/flow-for-emacs/flow.el")

(require 'benchmark-init)
;; To disable collection of benchmark data after init is done.
(add-hook 'after-init-hook 'benchmark-init/deactivate)
(add-hook 'sql-mode-hook 'sqlformat-on-save-mode)

;; (setq-hook! 'typescript-tsx-mode +format-with-lsp nil)

;; (add-hook! 'typescript-tsx-mode-hook
;;   (remove-hook 'before-save-hook #'lsp-organize-imports :local))

;; (add-hook! 'go-mode-hook
;;   (add-hook 'before-save-hook #'lsp-organize-imports :local))

(defun lsp-booster--advice-json-parse (old-fn &rest args)
  "Try to parse bytecode instead of json."
  (or
   (when (equal (following-char) ?#)
     (let ((bytecode (read (current-buffer))))
       (when (byte-code-function-p bytecode)
         (funcall bytecode))))
   (apply old-fn args)))
(advice-add (if (progn (require 'json)
                       (fboundp 'json-parse-buffer))
                'json-parse-buffer
              'json-read)
            :around
            #'lsp-booster--advice-json-parse)

(defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
  "Prepend emacs-lsp-booster command to lsp CMD."
  (let ((orig-result (funcall old-fn cmd test?)))
    (if (and (not test?)                             ;; for check lsp-server-present?
             (not (file-remote-p default-directory)) ;; see lsp-resolve-final-command, it would add extra shell wrapper
             lsp-use-plists
             (not (functionp 'json-rpc-connection))  ;; native json-rpc
             (executable-find "emacs-lsp-booster"))
        (progn
          (when-let ((command-from-exec-path (executable-find (car orig-result))))  ;; resolve command from exec-path (in case not found in $PATH)
            (setcar orig-result command-from-exec-path))
          (message "Using emacs-lsp-booster for %s!" orig-result)
          (cons "emacs-lsp-booster" orig-result))
      orig-result)))
(advice-add 'lsp-resolve-final-command :around #'lsp-booster--advice-final-command)

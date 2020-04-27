;;; -------------------------------------------------------------------------
;;; Typescript Emacs Configuration
;;;
;;;    (suggestions for populating your own .emacs file)
;;; -------------------------------------------------------------------------

(defun setup-tide-mode ()
  (interactive)
  (tide-setup)
  (flycheck-mode +1)
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (eldoc-mode +1)
  (tide-hl-identifier-mode +1)
  ;; company is an optional dependency. You have to
  ;; install it separately via package-install
  ;; `M-x package-install [ret] company`
  (company-mode +1))

(defun setup-txs-mode ()
  (interactive)
  (when (string-equal "tsx"
                      (file-name-extension buffer-file-name))
    (setup-tide-mode)))

;; aligns annotation to the right hand side
(setq company-tooltip-align-annotations t)

;; formats the buffer before saving
(add-hook 'before-save-hook 'tide-format-before-save)

;; Setup Tide for typescript
(add-hook 'typescript-mode-hook #'setup-tide-mode)

;; Setup Tide for typescript with JSX syntax
(require 'web-mode)
(add-hook 'web-mode-hook #'setup-txs-mode)

;; Setup Typescript Indentation

(setq-default typescript-indent-level 2)
(setq-default web-mode-markup-indent-offset 2)
(setq-default web-mode-css-indent-offset 2)
(setq-default web-mode-code-indent-offset 2)

;; Auto-mode Loading

(add-to-list 'auto-mode-alist '("\\.ts$" . typescript-mode))
(add-to-list 'auto-mode-alist '("\\.tsx$" . web-mode))

;;; -------------------------------------------------------------------------

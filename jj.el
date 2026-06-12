;;; jj.el --- Magit-inspired UI for Jujutsu -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Guy Lyons
;; Keywords: vc, tools
;; Package-Requires: ((emacs "29.1") (transient "0.13.0") (magit-section "4.0.0"))
;; Version: 0.1.0

;;; Commentary:

;; jj.el provides a Magit-inspired status UI and command dispatcher for
;; Jujutsu repositories.  It does not modify or depend on Magit's Git
;; porcelain; it only uses transient for menus and magit-section for
;; rendering collapsible status sections.

;;; Code:

(require 'jj-core)
(require 'jj-faces)
(require 'jj-status)
(require 'jj-log)
(require 'jj-diff)
(require 'jj-commit)
(require 'jj-branch)
(require 'jj-transient)

;;;###autoload
(defun jj (&optional directory)
  "Show a jj status buffer for DIRECTORY or `default-directory'."
  (interactive)
  (jj-status directory))

(provide 'jj)

;;; jj.el ends here

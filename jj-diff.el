;;; jj-diff.el --- Diff commands for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Diff commands for Jujutsu repositories.

;;; Code:

(require 'jj-core)

;;;###autoload
(defun jj-diff (revision)
  "Show `jj diff' for REVISION."
  (interactive (list (jj--read-revision "Diff revision" "@")))
  (jj--run-and-display "jj diff" "diff" "-r" revision))

(provide 'jj-diff)

;;; jj-diff.el ends here

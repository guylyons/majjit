;;; jj-log.el --- Log commands for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Log commands for Jujutsu repositories.

;;; Code:

(require 'jj-core)

;;;###autoload
(defun jj-log (&optional limit)
  "Show recent jj log output.
With prefix argument LIMIT, prompt for the number of changes to show."
  (interactive
   (list (when current-prefix-arg
           (read-number "Number of changes: " jj-log-limit))))
  (jj--run-and-display "jj log" "log" "-n"
                       (number-to-string (or limit jj-log-limit))))

(provide 'jj-log)

;;; jj-log.el ends here

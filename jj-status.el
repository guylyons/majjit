;;; jj-status.el --- Status buffer for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Status buffer for Jujutsu repositories.

;;; Code:

(require 'magit-section)
(require 'jj-core)
(require 'jj-faces)

(defvar jj-status-buffer-name "*jj-status*"
  "Name of the jj status buffer.")

(defvar-keymap jj-status-mode-map
  :doc "Keymap for `jj-status-mode'."
  "g" #'jj-status-refresh
  "l" #'jj-log
  "d" #'jj-diff
  "c" #'jj-describe
  "n" #'jj-new
  "s" #'jj-squash
  "u" #'jj-undo
  "?" #'jj-dispatch)

(define-derived-mode jj-status-mode special-mode "jj-status"
  "Major mode for the jj status buffer."
  (setq truncate-lines t))

(defun jj--insert-command-section (title root &rest args)
  "Insert a magit section named TITLE containing output from jj ARGS in ROOT."
  (magit-insert-section (jj-command title t)
    (magit-insert-heading title)
    (condition-case err
        (let ((output (apply #'jj--run-colored root args)))
          (insert (if (jj--string-empty-p output)
                      "(no output)\n"
                    output))
          (unless (bolp)
            (insert "\n")))
      (user-error (insert (propertize (error-message-string err)
                                      'face 'error)
                          "\n")))))

(defun jj--render-status (root)
  "Render status information for ROOT into the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize "jj status" 'face 'magit-section-heading) "\n")
    (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n\n")
    (jj--insert-command-section "Current workspace/change" root
                                "log" "-r" "@" "--no-graph")
    (insert "\n")
    (jj--insert-command-section "Summary" root "status")
    (insert "\n")
    (jj--insert-command-section "Recent log" root
                                "log" "-n" (number-to-string jj-log-limit))
    (goto-char (point-min))))

;;;###autoload
(defun jj-status (&optional directory)
  "Show a jj status buffer for DIRECTORY or `default-directory'."
  (interactive)
  (let* ((root (jj--repo-root (or directory default-directory)))
         (buffer (get-buffer-create jj-status-buffer-name)))
    (with-current-buffer buffer
      (jj-status-mode)
      (setq default-directory root)
      (setq jj-root root)
      (jj--render-status root))
    (pop-to-buffer buffer)))

(defun jj-status-refresh ()
  "Refresh the current jj status buffer."
  (interactive)
  (if (derived-mode-p 'jj-status-mode)
      (progn
        (jj--render-status (jj--default-root))
        (message "jj status refreshed"))
    (jj-status (jj--default-root))))

(provide 'jj-status)

;;; jj-status.el ends here

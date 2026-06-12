;;; jj-core.el --- Core helpers for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Guy Lyons
;; Keywords: vc, tools
;; Package-Requires: ((emacs "29.1") (transient "0.13.0") (magit-section "4.0.0"))
;; Version: 0.1.0

;;; Commentary:

;; Core process and repository helpers for jj.el.

;;; Code:

(require 'subr-x)
(require 'ansi-color)
(require 'magit-section)

(defgroup jj nil
  "A Magit-inspired interface for Jujutsu."
  :group 'tools
  :prefix "jj-")

(defcustom jj-executable "jj"
  "Name or path of the jj executable."
  :type 'string
  :group 'jj)

(defcustom jj-log-limit 20
  "Number of recent commits shown in `jj-status'."
  :type 'integer
  :safe #'integerp
  :group 'jj)

(defvar-local jj-root nil
  "Repository root for the current jj buffer.")

(defvar jj-output-buffer-name "*jj-output*"
  "Name of the jj output buffer.")

(define-derived-mode jj-output-mode special-mode "jj-output"
  "Major mode for jj command output buffers."
  (setq truncate-lines t))

(defun jj--repo-root (&optional directory)
  "Return the Jujutsu repository root at or above DIRECTORY.
Signal a user error when DIRECTORY is not inside a jj repository."
  (let* ((start (file-truename (or directory default-directory)))
         (root (locate-dominating-file start ".jj")))
    (unless root
      (user-error "Not inside a Jujutsu repository"))
    (file-name-as-directory (expand-file-name root))))

(defun jj--default-root ()
  "Return the current jj repository root."
  (or jj-root (jj--repo-root default-directory)))

(defun jj--string-empty-p (string)
  "Return non-nil when STRING is nil or empty after trimming."
  (or (null string) (string-empty-p (string-trim string))))

(defun jj--run (root &rest args)
  "Run jj with ARGS in ROOT and return its stdout.
Signal a `user-error' containing stderr when jj exits unsuccessfully."
  (unless (executable-find jj-executable)
    (user-error "Cannot find `%s' in PATH" jj-executable))
  (with-temp-buffer
    (let ((stdout (current-buffer))
          (stderr-file (make-temp-file "jj-stderr-"))
          status error-text)
      (unwind-protect
          (progn
            (setq status
                  (let ((default-directory root))
                    (apply #'process-file jj-executable nil
                           (list stdout stderr-file) nil args)))
            (setq error-text
                  (if (file-readable-p stderr-file)
                      (string-trim
                       (with-temp-buffer
                         (insert-file-contents stderr-file)
                         (buffer-string)))
                    ""))
            (if (and (integerp status) (zerop status))
                (buffer-string)
              (user-error "jj %s failed%s%s"
                          (string-join args " ")
                          (if (jj--string-empty-p error-text) "" ": ")
                          error-text)))
        (when (file-exists-p stderr-file)
          (delete-file stderr-file))))))

(defun jj--run-colored (root &rest args)
  "Run jj ARGS in ROOT with `--color=always' and colorize the output.
Returns the stdout of the command with ANSI escape sequences
converted into Emacs text properties via `ansi-color-apply'."
  (let ((output (apply #'jj--run root (append args (list "--color=always")))))
    (ansi-color-apply output)))

(defun jj--read-revision (prompt &optional default)
  "Read a jj revision with PROMPT and DEFAULT."
  (let* ((default (or default "@"))
         (input (read-string (format-prompt prompt default) nil nil default)))
    (if (jj--string-empty-p input) default input)))

(defun jj--read-message (prompt)
  "Read a non-empty commit/change message using PROMPT."
  (let ((message (read-string prompt)))
    (when (jj--string-empty-p message)
      (user-error "Message must not be empty"))
    message))

(defun jj--display-output (title root args output)
  "Display command OUTPUT for TITLE, ROOT, and ARGS."
  (let ((buffer (get-buffer-create jj-output-buffer-name)))
    (with-current-buffer buffer
      (jj-output-mode)
      (setq default-directory root)
      (setq jj-root root)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize title 'face 'magit-section-heading) "\n")
        (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n")
        (insert (propertize "Command: " 'face 'bold)
                jj-executable " " (string-join args " ") "\n\n")
        (insert (if (jj--string-empty-p output) "(no output)\n" output))
        (unless (bolp)
          (insert "\n"))
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(defun jj--run-and-display (title &rest args)
  "Run jj ARGS and display output under TITLE."
  (let* ((root (jj--default-root))
         (output (apply #'jj--run-colored root args)))
    (jj--display-output title root args output)))

(defun jj--run-and-refresh (message &rest args)
  "Run jj ARGS, show MESSAGE, and refresh status buffers when possible."
  (let* ((root (jj--default-root))
         (output (apply #'jj--run root args)))
    (message "%s%s%s" message
             (if (jj--string-empty-p output) "" ": ")
             (string-trim output))
    (when (and (boundp 'jj-status-buffer-name)
               (get-buffer jj-status-buffer-name))
      (with-current-buffer jj-status-buffer-name
        (when (and jj-root (file-equal-p jj-root root)
                   (fboundp 'jj--render-status))
          (jj--render-status root))))))

(provide 'jj-core)

;;; jj-core.el ends here

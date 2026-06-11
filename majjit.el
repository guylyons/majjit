;;; majjit.el --- Magit-inspired UI for Jujutsu -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Guy Lyons
;; Keywords: vc, tools
;; Package-Requires: ((emacs "29.1") (transient "0.13.0") (magit-section "4.0.0"))
;; Version: 0.1.0

;;; Commentary:

;; majjit provides a Magit-inspired status UI and command
;; dispatcher for Jujutsu repositories.  It does not modify or depend on
;; Magit's Git porcelain; it only uses transient for menus and magit-section
;; for rendering collapsible status sections.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'transient)
(require 'magit-section)
(require 'magit-process nil t)

(defgroup majjit nil
  "A Magit-inspired interface for Jujutsu."
  :group 'tools
  :prefix "majjit-")

(defcustom majjit-executable "jj"
  "Name or path of the jj executable."
  :type 'string
  :group 'majjit)

(defcustom majjit-log-limit 20
  "Number of recent commits shown in `majjit-status'."
  :type 'integer
  :safe #'integerp
  :group 'majjit)

(defvar-local majjit-root nil
  "Repository root for the current majjit buffer.")

(defvar majjit-status-buffer-name "*majjit-status*"
  "Name of the majjit status buffer.")

(defvar majjit-output-buffer-name "*majjit-output*"
  "Name of the majjit output buffer.")

(defvar-keymap majjit-status-mode-map
  :doc "Keymap for `majjit-status-mode'."
  "g" #'majjit-status-refresh
  "l" #'majjit-log
  "d" #'majjit-diff
  "c" #'majjit-describe
  "n" #'majjit-new
  "s" #'majjit-squash
  "u" #'majjit-undo
  "?" #'majjit-dispatch)

(define-derived-mode majjit-status-mode special-mode "majjit-status"
  "Major mode for the majjit status buffer."
  (setq truncate-lines t))

(define-derived-mode majjit-output-mode special-mode "majjit-output"
  "Major mode for majjit command output buffers."
  (setq truncate-lines t))

(defun majjit--repo-root (&optional directory)
  "Return the Jujutsu repository root at or above DIRECTORY.
Signal a user error when DIRECTORY is not inside a jj repository."
  (let* ((start (file-truename (or directory default-directory)))
         (root (locate-dominating-file start ".jj")))
    (unless root
      (user-error "Not inside a Jujutsu repository"))
    (file-name-as-directory (expand-file-name root))))

(defun majjit--default-root ()
  "Return the current jj repository root."
  (or majjit-root (majjit--repo-root default-directory)))

(defun majjit--string-empty-p (string)
  "Return non-nil when STRING is nil or empty after trimming."
  (or (null string) (string-empty-p (string-trim string))))

(defun majjit--run (root &rest args)
  "Run jj with ARGS in ROOT and return its stdout.
Signal a `user-error' containing stderr when jj exits unsuccessfully."
  (unless (executable-find majjit-executable)
    (user-error "Cannot find `%s' in PATH" majjit-executable))
  (with-temp-buffer
    (let ((stdout (current-buffer))
          (stderr-file (make-temp-file "majjit-stderr-"))
          status error-text)
      (unwind-protect
          (progn
            (setq status
                  (let ((default-directory root))
                    (apply #'process-file majjit-executable nil
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
                          (if (majjit--string-empty-p error-text) "" ": ")
                          error-text)))
        (when (file-exists-p stderr-file)
          (delete-file stderr-file))))))

(defun majjit--insert-command-section (title root &rest args)
  "Insert a magit section named TITLE containing output from jj ARGS in ROOT."
  (magit-insert-section (jj-command title t)
    (magit-insert-heading title)
    (condition-case err
        (let ((output (apply #'majjit--run root args)))
          (insert (if (majjit--string-empty-p output)
                      "(no output)\n"
                    output))
          (unless (bolp)
            (insert "\n")))
      (user-error (insert (propertize (error-message-string err)
                                      'face 'error)
                          "\n")))))

(defun majjit--render-status (root)
  "Render status information for ROOT into the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize "Majjit status" 'face 'magit-section-heading) "\n")
    (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n\n")
    (majjit--insert-command-section "Current workspace/change" root
                                      "log" "-r" "@" "--no-graph")
    (insert "\n")
    (majjit--insert-command-section "Summary" root "status")
    (insert "\n")
    (majjit--insert-command-section "Recent log" root
                                      "log" "-n" (number-to-string majjit-log-limit))
    (goto-char (point-min))))

;;;###autoload
(defun majjit-status (&optional directory)
  "Show a jj status buffer for DIRECTORY or `default-directory'."
  (interactive)
  (let* ((root (majjit--repo-root (or directory default-directory)))
         (buffer (get-buffer-create majjit-status-buffer-name)))
    (with-current-buffer buffer
      (majjit-status-mode)
      (setq default-directory root)
      (setq majjit-root root)
      (majjit--render-status root))
    (pop-to-buffer buffer)))

(defun majjit-status-refresh ()
  "Refresh the current majjit status buffer."
  (interactive)
  (let ((root (majjit--default-root)))
    (unless (derived-mode-p 'majjit-status-mode)
      (majjit-status root))
    (majjit--render-status root)
    (message "jj status refreshed")))

(defun majjit--read-revision (prompt &optional default)
  "Read a jj revision with PROMPT and DEFAULT."
  (let* ((default (or default "@"))
         (input (read-string (format-prompt prompt default) nil nil default)))
    (if (majjit--string-empty-p input) default input)))

(defun majjit--read-message (prompt)
  "Read a non-empty commit/change message using PROMPT."
  (let ((message (read-string prompt)))
    (when (majjit--string-empty-p message)
      (user-error "Message must not be empty"))
    message))

(defun majjit--display-output (title root args output)
  "Display command OUTPUT for TITLE, ROOT, and ARGS."
  (let ((buffer (get-buffer-create majjit-output-buffer-name)))
    (with-current-buffer buffer
      (majjit-output-mode)
      (setq default-directory root)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize title 'face 'magit-section-heading) "\n")
        (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n")
        (insert (propertize "Command: " 'face 'bold)
                majjit-executable " " (string-join args " ") "\n\n")
        (insert (if (majjit--string-empty-p output) "(no output)\n" output))
        (unless (bolp)
          (insert "\n"))
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(defun majjit--run-and-display (title &rest args)
  "Run jj ARGS and display output under TITLE."
  (let* ((root (majjit--default-root))
         (output (apply #'majjit--run root args)))
    (majjit--display-output title root args output)))

(defun majjit--run-and-refresh (message &rest args)
  "Run jj ARGS, show MESSAGE, and refresh status buffers when possible."
  (let* ((root (majjit--default-root))
         (output (apply #'majjit--run root args)))
    (message "%s%s%s" message
             (if (majjit--string-empty-p output) "" ": ")
             (string-trim output))
    (when (get-buffer majjit-status-buffer-name)
      (with-current-buffer majjit-status-buffer-name
        (when (and majjit-root (file-equal-p majjit-root root))
          (majjit--render-status root))))))

;;;###autoload
(defun majjit-log (&optional limit)
  "Show recent jj log output.
With prefix argument LIMIT, prompt for the number of changes to show."
  (interactive
   (list (when current-prefix-arg
           (read-number "Number of changes: " majjit-log-limit))))
  (majjit--run-and-display "jj log" "log" "-n"
                              (number-to-string (or limit majjit-log-limit))))

;;;###autoload
(defun majjit-diff (revision)
  "Show `jj diff' for REVISION."
  (interactive (list (majjit--read-revision "Diff revision" "@")))
  (majjit--run-and-display "jj diff" "diff" "-r" revision))

;;;###autoload
(defun majjit-describe (message)
  "Describe the current change with MESSAGE."
  (interactive (list (majjit--read-message "Description: ")))
  (majjit--run-and-refresh "Description updated" "describe" "-m" message))

;;;###autoload
(defun majjit-new (&optional revision)
  "Create a new change after REVISION.
When REVISION is empty, use jj's default parent."
  (interactive
   (list (let ((input (read-string "New change after revision (empty for default): ")))
           (unless (majjit--string-empty-p input) input))))
  (if revision
      (majjit--run-and-refresh "New change created" "new" revision)
    (majjit--run-and-refresh "New change created" "new")))

;;;###autoload
(defun majjit-squash (revision destination)
  "Squash REVISION into DESTINATION."
  (interactive
   (list (majjit--read-revision "Squash revision" "@")
         (majjit--read-revision "Into revision" "@-")))
  (majjit--run-and-refresh "Revision squashed" "squash" "--from" revision "--into" destination))

;;;###autoload
(defun majjit-split ()
  "Run `jj split'.
This command invokes jj directly and may use jj's configured editor."
  (interactive)
  (majjit--run-and-refresh "Revision split" "split"))

;;;###autoload
(defun majjit-abandon (revision)
  "Abandon REVISION after confirmation."
  (interactive (list (majjit--read-revision "Abandon revision" "@")))
  (when (yes-or-no-p (format "Abandon revision %s? " revision))
    (majjit--run-and-refresh "Revision abandoned" "abandon" revision)))

;;;###autoload
(defun majjit-bookmark-move (bookmark revision)
  "Move BOOKMARK to REVISION."
  (interactive
   (list (completing-read "Bookmark: "
                          (split-string
                           (majjit--run (majjit--default-root)
                                          "bookmark" "list" "--template" "name ++ \"\\n\"")
                           "\n" t))
         (majjit--read-revision "Move to revision" "@")))
  (when (majjit--string-empty-p bookmark)
    (user-error "Bookmark must not be empty"))
  (majjit--run-and-refresh "Bookmark moved" "bookmark" "move" bookmark "--to" revision))

;;;###autoload
(defun majjit-git-fetch ()
  "Run `jj git fetch'."
  (interactive)
  (majjit--run-and-refresh "Fetch complete" "git" "fetch"))

;;;###autoload
(defun majjit-git-push ()
  "Run `jj git push'."
  (interactive)
  (majjit--run-and-refresh "Push complete" "git" "push"))

;;;###autoload
(defun majjit-undo ()
  "Run `jj undo' after confirmation."
  (interactive)
  (when (yes-or-no-p "Undo the last jj operation? ")
    (majjit--run-and-refresh "Undo complete" "undo")))

(transient-define-prefix majjit-dispatch ()
  "Dispatch Majjit commands."
  [["Status"
    ("g" "refresh/status" majjit-status)
    ("l" "log" majjit-log)
    ("d" "diff" majjit-diff)]
   ["Change"
    ("c" "describe" majjit-describe)
    ("n" "new" majjit-new)
    ("s" "squash" majjit-squash)
    ("S" "split" majjit-split)
    ("x" "abandon" majjit-abandon)]
   ["Repository"
    ("b" "bookmark move" majjit-bookmark-move)
    ("f" "git fetch" majjit-git-fetch)
    ("p" "git push" majjit-git-push)
    ("u" "undo" majjit-undo)]])

(provide 'majjit)

;;; majjit.el ends here

;;; jj-magit.el --- Magit-inspired UI for Jujutsu -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Guy Lyons
;; Keywords: vc, tools
;; Package-Requires: ((emacs "29.1") (transient "0.13.0") (magit-section "4.0.0"))
;; Version: 0.1.0

;;; Commentary:

;; jj-magit provides a Magit-inspired status UI and command
;; dispatcher for Jujutsu repositories.  It does not modify or depend on
;; Magit's Git porcelain; it only uses transient for menus and magit-section
;; for rendering collapsible status sections.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'ansi-color)
(require 'transient)
(require 'magit-section)

(defgroup jj-magit nil
  "A Magit-inspired interface for Jujutsu."
  :group 'tools
  :prefix "jj-magit-")

(defcustom jj-magit-executable "jj"
  "Name or path of the jj executable."
  :type 'string
  :group 'jj-magit)

(defcustom jj-magit-log-limit 20
  "Number of recent commits shown in `jj-magit-status'."
  :type 'integer
  :safe #'integerp
  :group 'jj-magit)

(defvar-local jj-magit-root nil
  "Repository root for the current jj-magit buffer.")

(defvar jj-magit-status-buffer-name "*jj-magit-status*"
  "Name of the jj-magit status buffer.")

(defvar jj-magit-output-buffer-name "*jj-magit-output*"
  "Name of the jj-magit output buffer.")

(defvar-keymap jj-magit-status-mode-map
  :doc "Keymap for `jj-magit-status-mode'."
  "g" #'jj-magit-status-refresh
  "l" #'jj-magit-log
  "d" #'jj-magit-diff
  "c" #'jj-magit-commit
  "n" #'jj-magit-new
  "s" #'jj-magit-squash
  "u" #'jj-magit-undo
  "?" #'jj-magit-dispatch)

(define-derived-mode jj-magit-status-mode special-mode "jj-magit-status"
  "Major mode for the jj-magit status buffer."
  (setq truncate-lines t))

(define-derived-mode jj-magit-output-mode special-mode "jj-magit-output"
  "Major mode for jj-magit command output buffers."
  (setq truncate-lines t))

(defun jj-magit--repo-root (&optional directory)
  "Return the Jujutsu repository root at or above DIRECTORY.
Signal a user error when DIRECTORY is not inside a jj repository."
  (let* ((start (file-truename (or directory default-directory)))
         (root (locate-dominating-file start ".jj")))
    (unless root
      (user-error "Not inside a Jujutsu repository"))
    (file-name-as-directory (expand-file-name root))))

(defun jj-magit--default-root ()
  "Return the current jj repository root."
  (or jj-magit-root (jj-magit--repo-root default-directory)))

(defun jj-magit--string-empty-p (string)
  "Return non-nil when STRING is nil or empty after trimming."
  (or (null string) (string-empty-p (string-trim string))))

(defun jj-magit--run (root &rest args)
  "Run jj with ARGS in ROOT and return its stdout.
Signal a `user-error' containing stderr when jj exits unsuccessfully."
  (unless (executable-find jj-magit-executable)
    (user-error "Cannot find `%s' in PATH" jj-magit-executable))
  (with-temp-buffer
    (let ((stdout (current-buffer))
          (stderr-file (make-temp-file "jj-magit-stderr-"))
          status error-text)
      (unwind-protect
          (progn
            (setq status
                  (let ((default-directory root))
                    (apply #'process-file jj-magit-executable nil
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
                          (if (jj-magit--string-empty-p error-text) "" ": ")
                          error-text)))
        (when (file-exists-p stderr-file)
          (delete-file stderr-file))))))

(defun jj-magit--run-colored (root &rest args)
  "Run jj ARGS in ROOT with `--color=always' and colorize the output.
Returns the stdout of the command with ANSI escape sequences
converted into Emacs text properties via `ansi-color-apply'."
  (let ((output (apply #'jj-magit--run root (append args (list "--color=always")))))
    (ansi-color-apply output)))

(defun jj-magit--insert-command-section (title root &rest args)
  "Insert a magit section named TITLE containing output from jj ARGS in ROOT."
  (magit-insert-section (jj-command title t)
    (magit-insert-heading title)
    (condition-case err
        (let ((output (apply #'jj-magit--run-colored root args)))
          (insert (if (jj-magit--string-empty-p output)
                      "(no output)\n"
                    output))
          (unless (bolp)
            (insert "\n")))
      (user-error (insert (propertize (error-message-string err)
                                      'face 'error)
                          "\n")))))

(defun jj-magit--render-status (root)
  "Render status information for ROOT into the current buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize "JJ-Magit status" 'face 'magit-section-heading) "\n")
    (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n\n")
    (jj-magit--insert-command-section "Current workspace/change" root
                                      "log" "-r" "@" "--no-graph")
    (insert "\n")
    (jj-magit--insert-command-section "Summary" root "status")
    (insert "\n")
    (jj-magit--insert-command-section "Recent log" root
                                      "log" "-n" (number-to-string jj-magit-log-limit))
    (goto-char (point-min))))

;;;###autoload
(defun jj-magit (&optional directory)
  "Show a jj status buffer for DIRECTORY or `default-directory'."
  (interactive)
  (jj-magit-status directory))

;;;###autoload
(defun jj-magit-status (&optional directory)
  "Show a jj status buffer for DIRECTORY or `default-directory'."
  (interactive)
  (let* ((root (jj-magit--repo-root (or directory default-directory)))
         (buffer (get-buffer-create jj-magit-status-buffer-name)))
    (with-current-buffer buffer
      (jj-magit-status-mode)
      (setq default-directory root)
      (setq jj-magit-root root)
      (jj-magit--render-status root))
    (pop-to-buffer buffer)))

(defun jj-magit-status-refresh ()
  "Refresh the current jj-magit status buffer."
  (interactive)
  (if (derived-mode-p 'jj-magit-status-mode)
      (progn
        (jj-magit--render-status (jj-magit--default-root))
        (message "jj status refreshed"))
    (jj-magit-status (jj-magit--default-root))))

(defun jj-magit--read-revision (prompt &optional default)
  "Read a jj revision with PROMPT and DEFAULT."
  (let* ((default (or default "@"))
         (input (read-string (format-prompt prompt default) nil nil default)))
    (if (jj-magit--string-empty-p input) default input)))

(defun jj-magit--read-message (prompt)
  "Read a non-empty commit/change message using PROMPT."
  (let ((message (read-string prompt)))
    (when (jj-magit--string-empty-p message)
      (user-error "Message must not be empty"))
    message))

(defun jj-magit--display-output (title root args output)
  "Display command OUTPUT for TITLE, ROOT, and ARGS."
  (let ((buffer (get-buffer-create jj-magit-output-buffer-name)))
    (with-current-buffer buffer
      (jj-magit-output-mode)
      (setq default-directory root)
      (setq jj-magit-root root)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize title 'face 'magit-section-heading) "\n")
        (insert (propertize "Repository: " 'face 'bold) (abbreviate-file-name root) "\n")
        (insert (propertize "Command: " 'face 'bold)
                jj-magit-executable " " (string-join args " ") "\n\n")
        (insert (if (jj-magit--string-empty-p output) "(no output)\n" output))
        (unless (bolp)
          (insert "\n"))
        (goto-char (point-min))))
    (pop-to-buffer buffer)))

(defun jj-magit--run-and-display (title &rest args)
  "Run jj ARGS and display output under TITLE."
  (let* ((root (jj-magit--default-root))
         (output (apply #'jj-magit--run-colored root args)))
    (jj-magit--display-output title root args output)))

(defun jj-magit--run-and-refresh (message &rest args)
  "Run jj ARGS, show MESSAGE, and refresh status buffers when possible."
  (let* ((root (jj-magit--default-root))
         (output (apply #'jj-magit--run root args)))
    (message "%s%s%s" message
             (if (jj-magit--string-empty-p output) "" ": ")
             (string-trim output))
    (when (get-buffer jj-magit-status-buffer-name)
      (with-current-buffer jj-magit-status-buffer-name
        (when (and jj-magit-root (file-equal-p jj-magit-root root))
          (jj-magit--render-status root))))))

;;;###autoload
(defun jj-magit-log (&optional limit)
  "Show recent jj log output.
With prefix argument LIMIT, prompt for the number of changes to show."
  (interactive
   (list (when current-prefix-arg
           (read-number "Number of changes: " jj-magit-log-limit))))
  (jj-magit--run-and-display "jj log" "log" "-n"
                             (number-to-string (or limit jj-magit-log-limit))))

;;;###autoload
(defun jj-magit-diff (revision)
  "Show `jj diff' for REVISION."
  (interactive (list (jj-magit--read-revision "Diff revision" "@")))
  (jj-magit--run-and-display "jj diff" "diff" "-r" revision))

;;;###autoload
(defun jj-magit-commit (message)
  "Commit the current change with MESSAGE and create a new change on top."
  (interactive (list (jj-magit--read-message "Commit message: ")))
  (jj-magit--run-and-refresh "Change committed" "commit" "-m" message))

;;;###autoload
(defun jj-magit-describe (message)
  "Describe the current change with MESSAGE."
  (interactive (list (jj-magit--read-message "Description: ")))
  (jj-magit--run-and-refresh "Description updated" "describe" "-m" message))

;;;###autoload
(defun jj-magit-new (&optional revision)
  "Create a new change after REVISION.
When REVISION is empty, use jj's default parent."
  (interactive
   (list (let ((input (read-string "New change after revision (empty for default): ")))
           (unless (jj-magit--string-empty-p input) input))))
  (if revision
      (jj-magit--run-and-refresh "New change created" "new" revision)
    (jj-magit--run-and-refresh "New change created" "new")))

;;;###autoload
(defun jj-magit-squash (revision destination)
  "Squash REVISION into DESTINATION."
  (interactive
   (list (jj-magit--read-revision "Squash revision" "@")
         (jj-magit--read-revision "Into revision" "@-")))
  (jj-magit--run-and-refresh "Revision squashed" "squash" "--from" revision "--into" destination))

;;;###autoload
(defun jj-magit-split ()
  "Run `jj split'.
This command invokes jj directly and may use jj's configured editor."
  (interactive)
  (jj-magit--run-and-refresh "Revision split" "split"))

;;;###autoload
(defun jj-magit-abandon (revision)
  "Abandon REVISION after confirmation."
  (interactive (list (jj-magit--read-revision "Abandon revision" "@")))
  (when (yes-or-no-p (format "Abandon revision %s? " revision))
    (jj-magit--run-and-refresh "Revision abandoned" "abandon" revision)))

;;;###autoload
(defun jj-magit-bookmark-move (bookmark revision)
  "Move BOOKMARK to REVISION."
  (interactive
   (list (completing-read "Bookmark: "
                          (split-string
                           (jj-magit--run (jj-magit--default-root)
                                          "bookmark" "list" "--template" "name ++ \"\\n\"")
                           "\n" t))
         (jj-magit--read-revision "Move to revision" "@")))
  (when (jj-magit--string-empty-p bookmark)
    (user-error "Bookmark must not be empty"))
  (jj-magit--run-and-refresh "Bookmark moved" "bookmark" "move" bookmark "--to" revision))

;;;###autoload
(defun jj-magit-git-fetch ()
  "Run `jj git fetch'."
  (interactive)
  (jj-magit--run-and-refresh "Fetch complete" "git" "fetch"))

;;;###autoload
(defun jj-magit-git-push ()
  "Run `jj git push'."
  (interactive)
  (jj-magit--run-and-refresh "Push complete" "git" "push"))

;;;###autoload
(defun jj-magit-undo ()
  "Run `jj undo' after confirmation."
  (interactive)
  (when (yes-or-no-p "Undo the last jj operation? ")
    (jj-magit--run-and-refresh "Undo complete" "undo")))

;;;###autoload
(defun jj-magit-init (directory &optional colocate)
  "Initialize a new Jujutsu repository in DIRECTORY.

This runs `jj git init', which creates a Jujutsu repo backed by a
Git repo.  With a prefix argument, COLOCATE is non-nil and the repo
is created with `jj git init --colocate', so an existing Git
checkout and jj can share the same working copy.

If DIRECTORY does not exist, the user is offered the chance to
create it.  After initialization, the jj-magit status buffer for
the new repository is opened."
  (interactive
   (list (read-directory-name "Initialize jj repo in: " default-directory)
         current-prefix-arg))
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (args (if colocate
                   (list "git" "init" "--colocate")
                 (list "git" "init"))))
    (unless (file-directory-p directory)
      (if (yes-or-no-p (format "Directory %s does not exist.  Create it? " directory))
          (make-directory directory t)
        (user-error "Aborted: %s does not exist" directory)))
    (let ((output (apply #'jj-magit--run directory args)))
      (jj-magit--display-output "jj git init" directory args output))
    (jj-magit-status directory)))

(transient-define-prefix jj-magit-dispatch ()
  "Dispatch JJ-Magit commands."
  [["Status"
    ("g" "refresh/status" jj-magit-status)
    ("l" "log" jj-magit-log)
    ("d" "diff" jj-magit-diff)]
   ["Change"
    ("c" "commit" jj-magit-commit)
    ("D" "describe" jj-magit-describe)
    ("n" "new" jj-magit-new)
    ("s" "squash" jj-magit-squash)
    ("S" "split" jj-magit-split)
    ("x" "abandon" jj-magit-abandon)]
   ["Repository"
    ("b" "bookmark move" jj-magit-bookmark-move)
    ("f" "git fetch" jj-magit-git-fetch)
    ("p" "git push" jj-magit-git-push)
    ("u" "undo" jj-magit-undo)
    ("I" "init repo" jj-magit-init)]])

(provide 'jj-magit)

;;; jj-magit.el ends here

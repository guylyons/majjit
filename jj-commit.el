;;; jj-commit.el --- Change workflows for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Describe, commit, new, squash, split, abandon, undo, and init workflows.

;;; Code:

(require 'jj-core)
(require 'jj-status)

;;;###autoload
(defun jj-commit (message)
  "Commit the current change with MESSAGE and create a new change on top."
  (interactive (list (jj--read-message "Commit message: ")))
  (jj--run-and-refresh "Change committed" "commit" "-m" message))

;;;###autoload
(defun jj-describe (message)
  "Describe the current change with MESSAGE."
  (interactive (list (jj--read-message "Description: ")))
  (jj--run-and-refresh "Description updated" "describe" "-m" message))

;;;###autoload
(defun jj-new (&optional revision)
  "Create a new change after REVISION.
When REVISION is empty, use jj's default parent."
  (interactive
   (list (let ((input (read-string "New change after revision (empty for default): ")))
           (unless (jj--string-empty-p input) input))))
  (if revision
      (jj--run-and-refresh "New change created" "new" revision)
    (jj--run-and-refresh "New change created" "new")))

;;;###autoload
(defun jj-squash (revision destination)
  "Squash REVISION into DESTINATION."
  (interactive
   (list (jj--read-revision "Squash revision" "@")
         (jj--read-revision "Into revision" "@-")))
  (jj--run-and-refresh "Revision squashed" "squash" "--from" revision "--into" destination))

;;;###autoload
(defun jj-split ()
  "Run `jj split'.
This command invokes jj directly and may use jj's configured editor."
  (interactive)
  (jj--run-and-refresh "Revision split" "split"))

;;;###autoload
(defun jj-abandon (revision)
  "Abandon REVISION after confirmation."
  (interactive (list (jj--read-revision "Abandon revision" "@")))
  (when (yes-or-no-p (format "Abandon revision %s? " revision))
    (jj--run-and-refresh "Revision abandoned" "abandon" revision)))

;;;###autoload
(defun jj-undo ()
  "Run `jj undo' after confirmation."
  (interactive)
  (when (yes-or-no-p "Undo the last jj operation? ")
    (jj--run-and-refresh "Undo complete" "undo")))

;;;###autoload
(defun jj-init (directory &optional colocate)
  "Initialize a new Jujutsu repository in DIRECTORY.

This runs `jj git init', which creates a Jujutsu repo backed by a
Git repo.  With a prefix argument, COLOCATE is non-nil and the repo
is created with `jj git init --colocate', so an existing Git
checkout and jj can share the same working copy.

If DIRECTORY does not exist, the user is offered the chance to
create it.  After initialization, the jj status buffer for the new
repository is opened."
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
    (let ((output (apply #'jj--run directory args)))
      (jj--display-output "jj git init" directory args output))
    (jj-status directory)))

(provide 'jj-commit)

;;; jj-commit.el ends here

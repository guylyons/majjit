;;; jj-branch.el --- Bookmark and Git remote commands for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Bookmark and Git remote commands for Jujutsu repositories.

;;; Code:

(require 'jj-core)

;;;###autoload
(defun jj-bookmark-move (bookmark revision)
  "Move BOOKMARK to REVISION."
  (interactive
   (list (completing-read "Bookmark: "
                          (split-string
                           (jj--run (jj--default-root)
                                    "bookmark" "list" "--template" "name ++ \"\\n\"")
                           "\n" t))
         (jj--read-revision "Move to revision" "@")))
  (when (jj--string-empty-p bookmark)
    (user-error "Bookmark must not be empty"))
  (jj--run-and-refresh "Bookmark moved" "bookmark" "move" bookmark "--to" revision))

;;;###autoload
(defun jj-git-fetch ()
  "Run `jj git fetch'."
  (interactive)
  (jj--run-and-refresh "Fetch complete" "git" "fetch"))

;;;###autoload
(defun jj-git-push ()
  "Run `jj git push'."
  (interactive)
  (jj--run-and-refresh "Push complete" "git" "push"))

(provide 'jj-branch)

;;; jj-branch.el ends here

;;; jj-transient.el --- Transient menus for jj.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;;; Commentary:

;; Transient command menus for jj.el.

;;; Code:

(require 'transient)
(require 'jj-status)
(require 'jj-log)
(require 'jj-diff)
(require 'jj-commit)
(require 'jj-branch)

(transient-define-prefix jj-dispatch ()
  "Dispatch jj commands."
  [["Status"
    ("g" "refresh/status" jj-status)
    ("l" "log" jj-log)
    ("d" "diff" jj-diff)]
   ["Change"
    ("c" "commit" jj-commit)
    ("D" "describe" jj-describe)
    ("n" "new" jj-new)
    ("s" "squash" jj-squash)
    ("S" "split" jj-split)
    ("x" "abandon" jj-abandon)]
   ["Repository"
    ("b" "bookmark move" jj-bookmark-move)
    ("f" "git fetch" jj-git-fetch)
    ("p" "git push" jj-git-push)
    ("u" "undo" jj-undo)
    ("I" "init repo" jj-init)]])

(provide 'jj-transient)

;;; jj-transient.el ends here

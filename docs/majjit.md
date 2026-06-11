Build an Emacs package called jj-magit-lite.el.

Goal:
Create a Magit-inspired UI for Jujutsu (`jj`) repositories, without modifying Magit itself.

Requirements:
- Use lexical-binding.
- Use transient for command menus.
- Use magit-section to render a status buffer.
- Use magit-process where appropriate, or process-file/call-process safely.
- Detect jj repositories by walking upward for `.jj`.
- Provide command `jj-magit-status`.
- Render:
  - current workspace/change from `jj log -r @ --no-graph`
  - recent log from `jj log -n 20`
  - summary from `jj status`
- Provide transient command `jj-magit-dispatch` bound in the status buffer.
- Implement commands:
  - jj-magit-status
  - jj-magit-log
  - jj-magit-diff
  - jj-magit-describe
  - jj-magit-new
  - jj-magit-squash
  - jj-magit-split
  - jj-magit-abandon
  - jj-magit-bookmark-move
  - jj-magit-git-fetch
  - jj-magit-git-push
  - jj-magit-undo
- Keep commands simple at first: prompt with completing-read/read-string where needed.
- Do not attempt to emulate Git staging.
- Include a minimal keymap:
  g refresh
  l log
  d diff
  c describe
  n new
  s squash
  u undo
  ? dispatch
- Include package headers and provide feature `jj-magit-lite`.
- Prefer small, understandable functions over clever abstractions.

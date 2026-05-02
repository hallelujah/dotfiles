---
name: Commit message
interaction: chat
description: Generate a commit message
opts:
  alias: commit
  auto_submit: false
  is_slash_cmd: true
---

## user

You are an expert at following the Conventional Commit specification. Generate a concise, clear commit message for the staged git changes by first running `git diff --staged` to see what's about to be committed.

# Pi context and tool policy

This document records the behavior managed by `pi-kit` for `@earendil-works/pi-coding-agent` `0.84.4` and newer.

## Context budgets

The canonical settings reserve `32768` tokens for model output, retain `40000` recent tokens during compaction, and reserve `32768` tokens for branch summaries. Pi computes summary output from the reserve and model output cap; the target range for branch summaries is 4096 to 8192 tokens.

These values target large coding contexts. They are explicit operational defaults, not a claim that the same values are optimal for every small-context model.

## Reasoning and serialization

The main conversation starts at `high`. Compaction, split-turn prefix summaries, and branch summaries use `low` when the selected model supports reasoning. Summary requests omit historical thinking blocks. Edit tool calls retain only paths and diff statistics instead of source bodies or replacement text.

This keeps the summary focused on decisions, state, and file ownership while avoiding a second copy of large code edits.

## Prompt cache policy

Normal turns remain append-only. Pi does not rewrite an older tool result after every new turn. Truncation and summarization happen together at a compaction boundary, so cache-invalidating history changes occur in epochs rather than as a sliding window.

Keep the system prompt deterministic and avoid changing models without a task reason. A model switch generally prevents reuse of provider-specific prompt cache entries.

## Tool policy

- Use hashline `read`, `replace`, and `insert` for edits. A stale anchor must fail and force a fresh read.
- `anchor_grep` is disabled. Use `rg` through Bash for repository-wide search.
- Built-in `grep`, `find`, and `ls` are not enabled in canonical settings. Use `rg --files`, `fd`, and shell pipelines.
- Use `pi-web-access` for search and static page conversion.
- Use Playwright for dynamic pages, screenshots, traces, and repository end-to-end tests. Install Chromium on demand with `npx playwright install chromium`.

## Protected local state

`auth.json`, `models.json`, `models-store.json`, and sessions are deployment facts. They are deliberately outside the sync contract and must never be copied between machines by `pi-kit`.

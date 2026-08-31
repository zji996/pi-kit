# Pi context and tool policy

This document separates the behavior managed by `pi-kit` from core changes that still require an upstream Pi release. The installer follows the latest published `@earendil-works/pi-coding-agent` and does not replace it with a private fork.

## Context budgets

The canonical settings reserve `32768` tokens for model output, retain `40000` recent tokens during compaction, and reserve `32768` tokens for branch summaries. In published Pi `0.84.4`, branch summaries target 4096 to 8192 output tokens, while main and split-turn summaries still derive larger limits from the reserve. The staged core patch caps all three summary paths at 4096 to 8192 tokens while continuing to honor a lower model output cap.

These values target large coding contexts. They are explicit operational defaults, not a claim that the same values are optimal for every small-context model.

## Reasoning and serialization

The main conversation starts at `high`. Published Pi `0.84.4` already forces compaction, split-turn prefix summaries, and branch summaries to `low` when the selected model supports reasoning.

Historical-thinking omission and compact edit-tool serialization are staged in [`pi-0.84.4-compaction`](https://github.com/zji996/pi-mono/tree/pi-0.84.4-compaction), together with the unified summary output cap. Until that patch is accepted and published upstream, `pi-kit` guarantees the settings and reasoning policy but cannot make the npm release use the hardened serializer.

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

---
name: end-of-task-memory-update
description: "Use at the end of every completed task to persist durable knowledge — split repo-specific facts into the project context file and cross-session lessons into long-term memory, then verify retrievability."
---

# End-of-task memory update

Run this as the final cleanup step of every completed task, immediately after verification and before yielding. Do not wait to be asked.

## 0. The rule that matters most: never retain mutable state

`retain` is **append-mostly and partly irreversible**. The backend decomposes each item into extracted `[facts]` rows, and those rows are **read-only** — `memory_edit` returns `not_editable` for both `update` and `invalidate`. A retained sentence that is true today and false next week is therefore permanent misinformation that keeps resurfacing at high confidence.

So: **only retain statements that cannot expire.**

| Retain | Never retain |
|---|---|
| User preferences and decisions ("X was dismissed as not a risk") | Counts, tallies, progress ("22 items remain", "3 of 5 done") |
| How a tool actually behaves; measured tradeoffs | Which files/lines currently contain something |
| Episodic incidents ("X looked broken because Y was stale") | Any list mirrored from a project context file |
| Techniques and commands | Version numbers or config values that will change |

If you catch yourself writing a status snapshot, stop — that belongs in the project context file.

## 1. Decide what is durable

Ask: *would this change a future decision, and will it still be true in six months?* If either answer is no, store nothing.

## 2. Route by scope

| Content | Destination |
|---|---|
| Repo-specific: file paths, line numbers, module wiring, backlog/audit state, "do not redo" entries | The project context file (e.g. `.omp/AGENTS.md`) |
| Cross-session: user preferences, episodic incidents, general tool behaviour, measured tradeoffs | `retain` |

A lesson that is *both* gets the concrete form in the context file and the generalised form in memory. Never duplicate verbatim — mirroring a context-file section into memory is the single most common way stale rows get created.

## 3. Write it

- Batch related facts into ONE `retain` call.
- Each item self-contained: what, when, why. `context` carries the source situation.
- Generalise the lesson, then name the concrete instance as evidence.

## 4. Check for duplicates and staleness first

- `recall` the topic before writing; auto-capture may already hold transcript chunks and shallow extracted facts.
- Before any `memory_edit update`, `read memory://<id>` in full — recall output is a clipped preview and update replaces content wholesale.
- Prefer `invalidate` over `forget` for working memories that are merely superseded.

## 5. When a stale immutable row already exists

You cannot delete it. Write a **staleness guard** instead: a working-store entry, high importance, that names the unreliable rows and points at the authoritative source. Phrase the guard so it never expires itself — "do not trust any row stating how many X remain; read `<file>`" stays true forever, whereas "there are 22 X" does not.

## 6. Verify

Issue one `recall` phrased the way a future session would ask, and confirm the right entry surfaces. "Stored" is not "retrievable" — and check what *else* ranks above it.

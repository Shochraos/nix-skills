---
name: omp-project-migration
description: "Migrate omp per-project state (memory bank, sessions, history) after moving a repository to a new path"
---

# omp project migration (repo moved to a new absolute path)

omp keys per-project state by absolute cwd. After `mv <repo> <newpath>`:

## 1. Stop omp
No omp session may be running with cwd inside the repo (WAL contention on the bank DB).

## 2. Memory bank
Bank dir: `~/.omp/agent/memories/mnemopi/banks/<bank>/mnemopi.db`.
Bank name = `sanitize(basename(newpath)) + "-" + Bun.hash(newpath).toString(36)`
(Bun.hash = wyhash64, unpadded base36; sanitize = non-alphanumeric -> `-`).
Verify against existing banks before trusting a hand computation; or use the
create-then-replace alternative: start omp once in the new path, quit, then copy
the old bank's `mnemopi.db` over the freshly created one.

Then rename/copy the bank dir to the new name AND update the rows:

```sql
UPDATE working_memory  SET session_id = '<newbank>';
UPDATE facts           SET session_id = '<newbank>';
UPDATE memoria_facts   SET session_id = '<newbank>';
-- plus any other table with a session_id column that holds rows
-- (enumerate with PRAGMA table_info)
```

Skipping the UPDATE is the classic failure: bank loads, retention writes land,
but recall returns empty because recall filters rows by session_id = bank name.
Verified both directions 2026-08-28 (omp 18.0.6).

## 3. Sessions
`~/.omp/agent/sessions/<encoded-cwd>/` where encoded-cwd is the absolute path
with `/` -> `-` (spaces preserved). Rename the dir to the new encoding.
After the move confirm old sessions appear in `omp --resume` picker.

## 4. Prompt history
`~/.omp/agent/history.db` table `history` has a `cwd` column queried with a cwd
filter:

```sql
UPDATE history SET cwd = '<newpath>' WHERE cwd = '<oldpath>';
```

## 5. Threads (optional)
`~/.omp/agent/agent.db` table `threads` (cwd, rollout_path) — usually few rows,
stage1 system, safe to update or ignore.

## Verification
From the new path, print-mode probe asking the agent to call `recall` on a query
with known bank hits and quote raw ids. Model-narrated probes of injected
blocks are unreliable; tool-result output is machine-verifiable.

## Unaffected
memory_embeddings (id-keyed), session_titles (uuid-keyed), blobs/, models.db,
`~/.omp/agent/cache/`, project `.omp/` files (move with the repo).

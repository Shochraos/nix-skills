---
name: omp-rule-and-skill-probe
description: "Verify omp always-apply rule text and skill discovery without switching the system, using a scratch PI_CODING_AGENT_DIR print-mode probe (nixfiles/NixOS home-manager setups)"
---

# Probing omp rules and skill discovery without a switch

Use when a change alters `~/.omp/agent/rules/*.md` or `skills.customDirectories` and you must prove the effect before `nh os switch` (a running omp keeps the rules and config it loaded at startup, so the live process is useless as evidence).

## Setup

`PI_CODING_AGENT_DIR` **is the agent directory itself, not its parent.** Nesting an `agent/` subdir inside it produces `No API key found for anthropic. … or create <dir>/agent.db`.

```bash
hmf=$(nix-store -qR <toplevel> | grep -m1 'home-manager-files$')
d=$(mktemp -d /tmp/ompprobe.XXXX)
cp -rL "$hmf/.omp/agent/rules" "$d/rules"
cp ~/.omp/agent/agent.db ~/.omp/agent/agent.db-wal ~/.omp/agent/agent.db-shm "$d/"
ln -s ~/.omp/agent/cache "$d/cache"

PI_CODING_AGENT_DIR="$d" PI_CONFIG_FILES="$hmf/.omp/agent/nix-config.yml" \
  omp -p '<probe>'
```

Never pass a `--model` flag. Probes run on the primary model exactly as a
normal session does — a cheaper model for throwaway probes is prohibited by
the global `never.md` rule.

Cleanup needs `chmod -R u+w` first — the copied rule files come from the store read-only:
`chmod -R u+w /tmp/ompprobe.* && rm -rf /tmp/ompprobe.*`

## Probe form that works

Ask for **short, distinctive verbatim substrings** with at least one invented negative control, and demand a bare list:

> Bare numbered list, no prose. YES if the token appears verbatim in your injected always-apply rules, NO otherwise: (1) `<short phrase>` (2) `<short phrase>` (3) `glorptastic sediment`

For skills: `Count the entries in your <skills> list, print the count, and print YES if <name> is one of them else NO`, plus `Read skill://<name> and print its description frontmatter value verbatim`.

## Traps that produce wrong answers

- **Long punctuated strings false-negative.** Asking whether `Finishing bullet above, README included.` appears returned NO twice while the built file provably contained it. Use a short fragment like `finish through the same`.
- **Never ask for the model's interpretation.** "Quote the final sentence of the rule" returned the last *bullet*, not the final sentence.
- **`omp read` with a skill URL does not run discovery** — it always reports "Available: none".
- **`--no-tools` omits the `<skills>` block entirely**, so it gives a false negative for discovery.
- **The session jsonl does not store the system prompt**, so you cannot grep it for ground truth; rely on the file on disk plus short-substring probes.
- **Managed skills are absent** from a scratch agent dir — a useful confirmation that the probe is isolated, and it shifts the expected skill count.

## Complementary non-probe evidence

- Read the rule file straight out of the built closure: `sed -n '40,60p' "$hmf/.omp/agent/rules/<name>.md"`.
- Confirm `skills.customDirectories` in `"$hmf/.omp/agent/nix-config.yml"` points at the new payload path.
- Isolate the closure delta against the **live** toplevel when it was built from the same lock: `comm -13`/`-23` over two `nix-store -qR | sort` listings. Expect only the payload, `hm_<rule>.md`, `oh-my-pi-config.yml` and the `home-manager-files`/`-generation`/`unit-home-manager-<user>.service`/`system-units`/`etc`/`toplevel` cascade.

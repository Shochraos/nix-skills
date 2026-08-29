---
name: tracing-nix-eval-warnings
description: "Locate the exact source of an unattributed evaluation warning: from nix build/eval/nixos-rebuild, including warnings coming from flake inputs, and decide whether a lock bump fixes it safely"
---

# Tracing Nix evaluation warnings to their call site

`evaluation warning: ...` lines print no file or line. Do not guess, and do not
assume the warning is in the user's own code — most come from flake inputs.

## 1. Grep the repo first (cheap falsification)

```
grep -rn 'stdenv\.is(Linux|Darwin)' <repo>
```

No match is strong evidence the warning is in an input, not local code.

## 2. Turn the warning into a stack trace

```
nix eval --raw .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath \
  --option abort-on-warn true --show-trace 2>&1 | tail -80
```

`abort-on-warn` aborts on the **first** warning; the trace's deepest frames name
the real call site, e.g.
`«github:oxalica/rust-overlay/<rev>»/lib/mk-aggregated.nix:76`.
Repeat after each fix to surface the next warning. Host attribute names are
case-sensitive — `nix eval` suggests the right one ("Did you mean Azazel?").

Works for any attr: `.#packages.<system>.<name>`, `.#devShells...`, etc.

## 3. Attribute the input

```
jq -r '.nodes | to_entries[]
  | select(.value.inputs != null)
  | select([.value.inputs[]|tostring] | any(test("<input>")))
  | .key' flake.lock
```

That names the direct dependent, i.e. whose lock pin holds the stale rev.
Inspect the source with
`nix flake prefetch --json github:<owner>/<repo>/<rev> | jq -r .storePath`, then
grep that store path for every occurrence — one call site in the trace usually
means several in the file.

## 4. Check upstream before bumping

Read `https://raw.githubusercontent.com/<owner>/<repo>/master/<file>` directly.
If master already uses the non-deprecated form, a pin bump is the whole fix.

## 5. Bump a transitive input and prove it is inert

Nix >= 2.22 takes slash-separated paths:

```
nix flake update <parent>/<input>
```

Test in a throwaway `cp -a` copy first, then prove the change is build-neutral
by comparing derivation hashes before and after:

```
nix eval --raw .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath
```

Identical drv path = eval-only change, zero rebuild, safe even for
boot-critical inputs (bootloaders, initrd tooling). A *changed* drv path means
real rebuild risk: build the affected package explicitly and say so before
applying.

## Notes

- `nix build github:<owner>/<repo>/<rev>` builds the flake's default package —
  it is not a way to fetch source. Use `nix flake prefetch`.
- Deprecated-attr warnings in inputs are cosmetic; never patch a store path or
  add an overlay to silence one. Bump, or wait for upstream.

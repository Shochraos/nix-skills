# nix-skills

The agent skills behind [nixfiles](https://github.com/Shochraos/nixfiles), packaged as Nix derivations and kept fresh by a weekly auto-updater.

> **AI disclaimer:** The Nix packaging, the auto-update workflow and this README were written with AI assistance. Skill content comes from the upstream repositories listed below — except the `managed-skills` payload, which is self-authored. The packaging only rewrites paths and commands inside the upstream skills so their internal references resolve under oh-my-pi's `skill://` scheme, and it fails the build when upstream drift breaks that contract. Read what you install.

## What it packages

| Package | Upstream source | Skills |
| --- | --- | --- |
| `superpowers-skills` | [obra/superpowers](https://github.com/obra/superpowers) | 11 |
| `vendored-skills` | [marceloeatworld/nixos-ai-skill](https://github.com/marceloeatworld/nixos-ai-skill), [TheQtCompanyRnD/agent-skills](https://github.com/TheQtCompanyRnD/agent-skills), [vercel-labs/skills](https://github.com/vercel-labs/skills), [wshobson/agents](https://github.com/wshobson/agents), [anthropics/skills](https://github.com/anthropics/skills), one file from [github/awesome-copilot](https://github.com/github/awesome-copilot) | 29 |
| `managed-skills` | self-authored — promoted from oh-my-pi's `~/.omp/agent/managed-skills/`, source lives in this repo's `skills/` tree | 6 |

The three payloads are deliberately separate derivations — needle edits, `sed` rewrites and verbatim copies respectively — sharing nothing but the `package.nix` shape. `packages.<system>.default` is a `symlinkJoin` of all three for single-directory consumers.

## How it works

- `superpowers-skills` edits upstream with literal `--replace-fail` needles (upstream rewording one of them is a build error, not silent rot) and ends with a banned-pattern gate that greps the payload for content that must never reach an agent (git write commands, hand-rolled install instructions, disabled-skill handoffs).
- `vendored-skills` edits a fast-moving upstream with `sed` rewrites (a literal needle would break on every daily doc refresh) and runs three gates: banned patterns in `*.md`, stricter banned patterns in `SKILL.md` only, and a resolution gate that walks every `skill://` token in the payload and fails if it does not name a skill that exists.
- `managed-skills` copies the self-authored `skills/` tree verbatim — no upstream input, no rewrites — and runs the same gate set as `vendored-skills`. Promotion means copying a skill out of oh-my-pi's `~/.omp/agent/managed-skills/`; the managed copy is deleted once the payload is live.
- `checks.<system>` carries the packages, so `nix flake check` actually builds all three payloads through their gates instead of just evaluating them. The auto-updater relies on this: a red run means nothing lands.
- The six skill sources are flake inputs; the lock is bumped by the workflow, not by hand.
- The `create-readme` skill is a `fetchurl` pinned to a commit sha inside `pkgs/vendored-skills/package.nix`. `nix flake update` can never move it; a refresh means editing the rev and its hash together.

### Auto-update

Every Monday 06:00 UTC (and on manual dispatch), the `update-skill-sources` workflow bumps the six skill inputs, runs `nix flake check`, and pushes `flake.lock` only when the build is green and the lock actually changed. nixpkgs is deliberately not auto-bumped, so the lock diff stays focused on skills. If a gate trips, the run is red and consumers keep building the last pinned rev.

## Usage

Add the input and install the payload directories as oh-my-pi `skills.customDirectories`:

```nix
{
  inputs.nix-skills = {
    url = "github:Shochraos/nix-skills";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
{ inputs, pkgs, ... }:
{
  skills.customDirectories = [
    "${inputs.nix-skills.packages.${pkgs.stdenv.hostPlatform.system}.superpowers-skills}"
    "${inputs.nix-skills.packages.${pkgs.stdenv.hostPlatform.system}.vendored-skills}"
    "${inputs.nix-skills.packages.${pkgs.stdenv.hostPlatform.system}.managed-skills}"
  ];
}
```

## Layout

```
flake.nix                             packages, checks, formatter, devshell
pkgs/superpowers-skills/package.nix   the needle-edited payload
pkgs/vendored-skills/package.nix      the sed-edited payload
pkgs/managed-skills/package.nix       the verbatim self-authored payload
skills/                               the self-authored sources it packages
.github/workflows/update-skill-sources.yml   the weekly auto-updater
```

## Development

`nix develop` provides `nixfmt` and `nixd`. `nix fmt` formats, and `nix build` doubles as the gate run — all three payloads build through `writeShellApplication`-style checks and the banned-pattern gates.

## License

[MIT](LICENSE) © 2026 Shochraos

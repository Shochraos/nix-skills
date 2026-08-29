---
name: verifying-dms-plugin-changes
description: "Use when changing or reviewing a DankMaterialShell (DMS/DankBar) QML plugin and needing to verify it on the live shell - symlink swap, hot reload limits, fake-CLI fixtures, QML error checking, and screenshot measurement on Wayland"
---

# Verifying a DMS plugin change on the live shell

A DMS plugin is plain QML loaded from `~/.config/DankMaterialShell/plugins/<pluginId>`.
There is no build step, so "it parses" is not verification — the component tree has to
be instantiated against the real DMS types.

## 1. Point the shell at your working tree

On a home-manager system the plugin directory is a symlink into the nix store, so
editing the repo changes nothing. Record the original target before swapping:

```sh
cd ~/.config/DankMaterialShell/plugins
readlink <pluginId>                 # save this
ln -sfn /path/to/repo <pluginId>
```

You MUST restore the saved path when done. home-manager does **not** repair this:
its `checkLinkTargets` phase refuses to clobber a path it does not own, so a leftover
swapped symlink hard-fails the next activation with
`Existing file '…/plugins/<pluginId>' would be clobbered`, which fails
`home-manager-<user>.service` and aborts the whole `nixos-rebuild` (exit 4).

Recovery, if that already happened: `rm ~/.config/DankMaterialShell/plugins/<pluginId>`
then re-run the activation — `<generation>/activate` as the user, or the rebuild.

Reviewing someone else's patch: clone their fork into `/tmp` at the PR head and swap the
symlink at that, plus a second clone at the merge base for a before/after pair. Leaves
the user's checkout untouched.

## 2. Hot reload — and what it does not reload

```sh
dms ipc call plugins reload <pluginId>
dms ipc call plugin-scan status <pluginId>     # expect: loaded
dms ipc call plugins status <pluginId>         # expect: loaded, NOT disabled
```

- Component source *is* re-read; the loader cache-busts with `?t=<ms>`.
- The **manifest is cached**. Change `component` in `plugin.json`, or rename the QML
  file, and the shell keeps requesting the old URL: `component error <id> widget
  file://…/Old.qml?t=…: No such file or directory` — and silently keeps serving the
  previously loaded component, so your edits appear to have no effect.
  `plugin-scan rescan <id>` does not fix it. Restart the service.
- A reload that hits a broken component can leave the plugin `disabled`. On a
  home-manager host `settings.json` and `plugin_settings.json` are store symlinks, i.e.
  read-only: `plugins enable <id>` answers `PLUGIN_ENABLE_SUCCESS` yet `plugins status`
  stays `disabled`, because the enable flag cannot be persisted. Only
  `systemctl --user restart dms.service` restores the declared state (~8 s, and the bar
  reappears). Always end a session by re-checking `plugins status`.

## 3. Open the popout, or you have verified nothing

`popoutContent` is a `Component`. Nothing inside it is instantiated — and no error
inside it is reported — until the popout is opened. A clean journal after a bare
reload proves only that the bar pill loaded.

```sh
dms ipc call widget toggle <pluginId>     # opens/closes the popout
dms ipc call widget visibility <pluginId>
```

`widget reveal` is not the same thing; it does not open the popout.

## 4. Read the log

```sh
journalctl --user -u dms.service -n 200 -o cat \
  | grep -viE '<chatty other plugins>' | grep -iE 'error|<pluginId>'
```

QML type errors, unresolved properties, `component error`, and binding loops land here.
`--show-cursor` + `--after-cursor` is nice in theory but the cursor is invalidated by a
service restart (`Failed to seek to cursor: Invalid argument`), so prefer `--since`.

## 5. Screenshot, and measure

The bar exists on one output only — find it, do not assume monitor 0:

```sh
env -u LD_LIBRARY_PATH hyprctl layers -j \
  | jq -r 'to_entries[] | .key as $m | .value.levels | to_entries[] | .value[]
           | select(.namespace|test("dms:bar")) | "\($m) \(.w)x\(.h) at \(.x),\(.y)"'
```

`grim` is usually only in the store; skip `.drv` paths when globbing:

```sh
GRIM=$(echo /nix/store/*-grim-*/bin/grim | tr ' ' '\n' | grep -v '\.drv' | tail -1)
"$GRIM" -g "0,1440 1700x41" /tmp/shot.png     # 'x,y WxH', region inside one output
```

To quantify a pill's width change without a UI inspector, screenshot the same bar strip
before and after and measure the **displacement of a neighbouring widget group** (decode
the PNG, scan the middle row, group runs that differ from the wallpaper). A pill that
sets both `width:` and `implicitWidth:` is a trap: DankBar sizes widgets from
`implicitWidth`, so a `Math.min(…, N)` on `width` alone is dead code and the pill grows
past the intended cap.

## 6. Static check (cheap, weak)

```sh
/nix/store/*-qtdeclarative-*/bin/qmllint \
  -I <dms-shell>/share/quickshell Widget.qml
```

Every `qs.*` import fails to resolve outside quickshell, and that cascades into
`unknown grouped property scope anchors/font/border` noise. Only non-`[import]`,
non-`[unqualified]` diagnostics carry signal. It catches syntax errors; it cannot
catch a broken binding.

## 7. Fixtures instead of real user data

A plugin that wraps a CLI (`todo`, `khal`, …) is testable without touching real data:
write a fake executable that prints a fixture JSON file, and in the throwaway clone
replace the process command with its path.

```sh
cat > /tmp/fake-cli <<'EOF'
#!/bin/sh
cat /tmp/fixture.json
EOF
chmod +x /tmp/fake-cli
sed -i 's|\["todo",|["/tmp/fake-cli",|' TodomanWidget.qml
```

Swapping `/tmp/fixture.json` and reloading exercises edge cases — empty list, only
overdue items, a 90-character title, nothing due — with zero risk of mutating a synced
CalDAV store. Never create/delete real items to test; they sync outward.

## Testing QML logic without a shell

Property bodies and functions in a QML file are plain JS. Extract them from the
source with brace matching and run them under `new Function('root', 'with(root){…}')`
with a fake `root` — bare identifiers then resolve against your fixture object. This
tests the shipped expressions rather than a retyped copy, and pairs well with real
fixtures captured from whatever CLI the plugin wraps.

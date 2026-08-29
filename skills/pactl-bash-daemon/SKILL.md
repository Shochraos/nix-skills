---
name: pactl-bash-daemon
description: "Use when writing, reviewing, or debugging a bash script or daemon that drives PipeWire/PulseAudio through pactl - parsing rules, subscribe event grammar, and a live verification recipe"
---

# pactl-driven bash daemons

Hard-won rules for scripting PipeWire through `pactl`. Every rule below was
confirmed against live output, not inferred.

## Parse `list short`, never the verbose records

`pactl list short <facility>` is tab-separated and stable:

```
536870916	module-remap-sink	sink_name=discord_sink master=alsa_output.usb-… sink_properties=…
70	alsa_output.usb-…	PipeWire	s32le 2ch 48000Hz	RUNNING
```

Parse with `awk -F'\t'` and compare **whole whitespace-split tokens**:

```bash
pactl list short modules | awk -F'\t' -v want="sink_name=$name" '
  $2 != "module-remap-sink" { next }
  { n = split($3, a, /[ \t]+/)
    for (i = 1; i <= n; i++) if (a[i] == want) { print $1; exit } }'
```

Substring matching on the verbose `pactl list modules` record format is broken:
PipeWire module ids are 9 digits (`536870916`), so `Module #53687091` matches
`Module #536870916`, and `sink_name=foo` matches `sink_name=foo_2`.

## Volumes: scan for the percentage token

`pactl get-sink-volume` is locale-dependent — a comma-decimal locale prints
`front-left: 35389 /  54% / -16,06 dB`. Never use a positional field:

```bash
pactl get-sink-volume "$sink" | awk 'NR==1 {
  for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+%$/) { print substr($i, 1, length($i)-1); exit } }'
```

Under `set -euo pipefail`, append `|| true` to that command substitution or a
missing sink makes the assignment fail before your own error message runs.

## Identify your own streams by `Owner Module`

A loopback/remap sink's own sink-input carries `Owner Module: <module id>`;
application streams carry `n/a`. Track the module ids you loaded and skip those
sink-inputs. Prefix-guessing on `node.name` (`output.*`) is a fallback at best.

## `pactl subscribe` grammar and event selection

```
Event '<new|change|remove>' on <sink|sink-input|source|client|module|server> #<id>
```

- Resync sinks only on `'new'`/`'remove'` on **sink** and on **server**.
  `'change' on sink` fires on every volume change — resyncing there means a full
  rebuild on each volume-hotkey press.
- `'remove' on sink-input` needs no routing pass.
- Coalesce bursts: after the first blocking `read`, keep draining with
  `read -r -t 0.05 line || break`, then act once per window.

## Fresh modules are not instantly addressable

After `pactl load-module`, retry the follow-up call instead of sleeping a fixed
guess:

```bash
for ((i = 0; i < 20; i++)); do
  pactl set-sink-volume "$sink" "${pct}%" >/dev/null 2>&1 && return 0
  sleep 0.05
done
```

## Never pipe into the event loop

`pactl subscribe | while read` runs the loop in a subshell that survives SIGTERM
to the parent, orphaning a second daemon that keeps mutating the graph. Use:

```bash
exec 3< <(pactl subscribe 2>/dev/null)
SUBSCRIBER_PID=$!
handle_events <&3
exec 3<&-
```

with `trap 'exit 0' INT TERM` and an `EXIT` trap that kills `$SUBSCRIBER_PID`.
Bonus: the loop runs in the main shell, so cached state stays coherent.

## Resilience shape

Never `exit 1` when the audio graph is not ready yet — a login race is normal.
Loop: sync, route, watch events; on failure log and sleep with doubling backoff
capped at ~30s. Reset the delay whenever a sync succeeds.

## shellcheck shapes that fail `writeShellApplication`

- SC2015 — `A && B || C`: write explicit `if`.
- SC2319 — `$?` right after `[[ ]]`: wrap the test in a *function* and read `$?`
  after calling it (bash returns 2 from `[[ =~ ]]` on an invalid regex, which is
  how you validate a user-supplied ERE at startup).
- SC2234 — `( [[ ]] )`: superfluous subshell.

## Live verification recipe

There is no mock; exercise a real session and restore it afterwards.

```bash
systemctl --user stop <your-unit>            # avoid two daemons fighting
# silent, labelled probe streams:
paplay --client-name="WEBRTC VoiceEngine" --raw --rate=48000 --channels=2 --format=s16le /dev/zero &
# alternate master without touching hardware:
pactl load-module module-null-sink sink_name=probe_alt
pactl set-default-sink probe_alt              # exercises re-master paths
# kill the subscribe child to prove reconnect:
kill "$(pgrep -P "$daemon_pid" pactl)"
```

Check `pactl list sink-inputs | awk '/^Sink Input/{id=$3} /^\tSink:/{s=$2}
/application\.name =/{print id, s, $0}'` for placement, and `ts '%.s'` on the
daemon's stderr to prove backoff intervals. Always restore: kill probes, unload
probe modules, restart the unit, put the user's volumes back.

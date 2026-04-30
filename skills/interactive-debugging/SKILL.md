---
name: interactive-debugging
description: Collaboratively debug a misbehaving Linux desktop app or service in real time with the user. Two modes — live (tail logs while the user reproduces) and retrospective (something just happened, capture evidence before it gets buried). Produces a diagnosis and optionally a written-up bug report with attached log excerpts. Use when the user says "something won't launch", "let's debug this together", "X just crashed", "a bug just happened", or describes an issue they want to reproduce.
---

# Interactive Debugging

Hands-on, conversational debugging session. The user is at the keyboard and can trigger or has just triggered the issue; you drive log collection and analysis.

## Step 1: Pick a mode

Ask the user (or infer from how they phrased it):

- **Live mode** — "It doesn't launch / it freezes / it does X every time." → You will tail logs *while* they reproduce.
- **Retrospective mode** — "It just happened / X just crashed / I caught a bug." → You will pull logs from the last few minutes *before* they roll out of the journal.

If unclear, ask one short question: *"Can you reproduce it on demand, or did it just happen?"*

## Step 2: Get a one-line description

Prompt the user: *"In one sentence, what's the symptom? (e.g. 'Chrome closes immediately when I open a PDF', 'OBS won't launch from the launcher')"*

Capture:
- The app/service/unit name (resolve to a systemd unit, binary name, or `.desktop` ID)
- The trigger action
- The observed symptom (crash, hang, error dialog, silent no-op)

## Step 3a: Live mode — tail then reproduce

1. Identify the right log surface. In order of preference:
   - systemd unit → `journalctl -u <unit> -f`
   - user service → `journalctl --user -u <unit> -f`
   - desktop app launched from shell → run it from a terminal so stderr is visible (suggest the user do this if it's a GUI app: `<binary> 2>&1 | tee /tmp/<binary>-debug.log`)
   - kernel-adjacent (driver, USB, GPU) → `journalctl -kf`
   - everything else → `journalctl -f -p info`

2. Start the tail in a background bash (use `run_in_background: true`) and note the timestamp:
   ```bash
   date -Iseconds  # mark t0
   journalctl -f --since "now" -p info > /tmp/interactive-debug-$(date +%s).log &
   ```

3. Tell the user: *"Tail is running. Reproduce it now, then tell me when you're done."*

4. When they say done, stop the tail and read the captured file. Filter aggressively — keep only lines plausibly related to the binary, unit, or symptom.

## Step 3b: Retrospective mode — pull before it rolls out

The journal has finite retention; act fast. Pull a generous window around "now":

```bash
journalctl --since "5 min ago" --no-pager > /tmp/interactive-debug-retro-$(date +%s).log
journalctl -k --since "5 min ago" --no-pager      # kernel ring
journalctl --user --since "5 min ago" --no-pager  # user services
```

Also check, in parallel:

```bash
ls -lt /var/lib/systemd/coredump/ 2>/dev/null | head -5   # recent core dumps
coredumpctl list --since "10 min ago" 2>/dev/null
dmesg --since "5 min ago" 2>/dev/null
ls -lt ~/.xsession-errors* ~/.local/share/xorg/ 2>/dev/null | head
```

If the user named a specific binary, also grep its name across the window.

## Step 4: Diagnose

Read the captured logs. Look for:
- The first `error`, `fatal`, `segfault`, `Failed`, `core-dump`, `oom`, `cannot`, `denied`
- Stack traces or backtraces
- Repeated lines just before the failure (a loop / retry storm)
- Missing-file, missing-library, permission, or D-Bus errors
- AppArmor / SELinux denials (`audit:`, `apparmor=DENIED`)

Form a hypothesis. State it plainly to the user with the supporting log line(s) quoted, file path and timestamp included. If you're not sure, say so and propose one targeted next check rather than guessing.

## Step 5: Decide — fix now or document?

Ask: *"Want me to attempt a fix, or document this as a bug for later?"*

- **Fix now** → proceed to the fix; verify by re-running the trigger (live mode loop).
- **Document** → write a bug report.

## Step 6 (optional): Write up the bug

If the user wants documentation, ask where it should go. Default destinations in priority order:
1. The current repo's `planning/bugs/` or `docs/bugs/` if one exists
2. `~/Daniel-Workstation-Updates/<YYYY-MM-DD>/` for workstation issues
3. `/tmp/bug-<slug>-<timestamp>.md` if no destination given

Bug report structure:

```markdown
# <one-line symptom>

**Date**: <ISO date>
**Mode**: live | retrospective
**App / unit**: <name>
**Reproducible**: yes / no / intermittent

## Symptom
<what the user observed>

## Trigger
<exact action that causes it>

## Diagnosis
<your hypothesis, with the supporting log lines quoted inline>

## Relevant log excerpts
\`\`\`
<the 5–30 most relevant lines, not the whole file>
\`\`\`

## Full logs
- `<path to captured log file>`
- `<path to coredump if any>`

## Next steps
<what would confirm the diagnosis or fix it>
```

Copy the captured `/tmp/interactive-debug-*.log` files alongside the report so they don't get reaped.

## Step 7: Offer follow-ups

After the report is written, offer (only if relevant):
- File a workstation update writeup if a fix was applied
- Add a persistent journal config check (`validate-persistent-journal`) if retrospective mode came up empty
- Open a crash investigation (`investigate-last-crash`) if the symptom was a freeze or reboot

## Notes

- Don't dump entire log files into chat — quote only the relevant lines, reference paths for the rest.
- In live mode, always start the tail *before* asking the user to reproduce, never after.
- In retrospective mode, the first action is always to pull the window to disk — analysis can wait, log retention can't.
- If the journal returns nothing for the time window, suspect non-persistent journald and check `/run/log/journal` vs `/var/log/journal`.

---
name: journal-inspect
description: Run targeted journalctl queries to surface only the relevant log lines for a debugging task — by unit, time window, priority, boot, or kernel/user scope. Emits structured output (JSON or short-form) suited for AI analysis. Use when the user reports a problem and you need to inspect logs without dumping everything. Assumes systemd + journald (Ubuntu, Debian, Fedora, Arch, etc.).
---

# Journal Inspect

Targeted journalctl queries for AI-assisted debugging. The goal is to retrieve **just enough** log context — never `journalctl -xe` blindly, which floods the context window.

## Decision flow

1. **Scope**: which unit, process, or kernel ring buffer?
2. **Time window**: current boot? previous boot? since a wallclock time? a relative window?
3. **Priority**: errors only, warnings+, or everything?
4. **Format**: human short-form for the user, JSON for structured analysis.

## Common queries

### Unit-scoped, current boot
```bash
journalctl -u <unit> -b --no-pager -p warning
```

### Previous boot (post-crash investigation)
```bash
journalctl -b -1 --no-pager -p err
```
Requires persistent journald — verify with `validate-persistent-journal` if `-b -1` returns nothing.

### Time-windowed
```bash
journalctl --since "10 min ago" -p warning --no-pager
journalctl --since "2026-04-28 14:00" --until "2026-04-28 14:30"
```

### Kernel only (oops, OOM, hardware errors)
```bash
journalctl -k -b -p err --no-pager
journalctl -k --grep "(oom|segfault|oops|BUG|panic)" --no-pager
```

### Structured JSON for analysis
```bash
journalctl -u <unit> -b -p warning -o json --no-pager | jq -r '. | {t: .__REALTIME_TIMESTAMP, u: ._SYSTEMD_UNIT, p: .PRIORITY, m: .MESSAGE}'
```

JSON fields most useful for AI parsing: `MESSAGE`, `PRIORITY`, `_SYSTEMD_UNIT`, `_PID`, `_COMM`, `__REALTIME_TIMESTAMP`, `SYSLOG_IDENTIFIER`.

## Priority levels (numeric)

`0=emerg 1=alert 2=crit 3=err 4=warning 5=notice 6=info 7=debug`

Use `-p N` to include level N and below (more severe). Most debugging starts at `-p warning`.

## Anti-patterns

- **Never** dump `journalctl` with no filter — it's gigabytes.
- Avoid `-f` (follow) inside an agent session unless explicitly reproducing a live event; it blocks.
- Don't use `--no-pager` and then pipe to `head` — use `-n <count>` instead.
- Don't grep raw output for unit names; use `-u <unit>` so journald uses its index.

## Reporting back to the user

After running a query, summarize:
- Time window inspected
- Number of matching lines
- Top 3–5 distinct errors (deduplicated by message pattern)
- Any clusters in time that suggest a triggering event

Quote actual log lines verbatim when reporting suspicious entries — paraphrasing loses precision the user needs to grep their own system.

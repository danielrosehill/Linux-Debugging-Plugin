---
name: inspect-oom-events
description: Find past out-of-memory kill events in the journal — both kernel OOM killer invocations and userspace systemd-oomd / earlyoom kills — and reconstruct what was running at the time. Use when the user reports an unexplained freeze, lost work, or a process disappearing.
---

# Inspect OOM Events

Three actors can kill a process for memory reasons: the **kernel OOM killer** (last resort, runs when allocations fail), **systemd-oomd** (userspace, PSI-based, fires earlier), and **earlyoom** (userspace, free-memory-threshold-based). Each leaves different log signatures.

## 1. Kernel OOM killer

```bash
journalctl -k --no-pager --grep "(killed process|out of memory|oom-kill|oom_reaper)" -b
journalctl -k --no-pager --grep "out of memory" --since "7 days ago"
```

Kernel OOM messages include:
- `Out of memory: Killed process <pid> (<comm>) total-vm:... rss:...`
- A process list dump immediately preceding (the "memcg" or "Tasks state" block)

The dumped process list shows which process the kernel chose and why (highest oom_score). Capture it for the report.

## 2. systemd-oomd

```bash
journalctl -u systemd-oomd --no-pager -b
journalctl -u systemd-oomd --no-pager --since "7 days ago" --grep "(Killed|kill)"
```

oomd messages look like:
- `Killed /user.slice/user-1000.slice/user@1000.service/app.slice/app-firefox.scope due to memory used (...) / total (...)`

The cgroup path tells you exactly which session, app, or scope was killed.

## 3. earlyoom

```bash
journalctl -u earlyoom --no-pager -b --grep "sending SIGTERM"
journalctl -u earlyoom --no-pager --since "7 days ago"
```

## Correlating with system state

For the time window of an OOM event, pull surrounding context:

```bash
T="2026-04-28 14:23"
journalctl --since "$T - 2 min" --until "$T + 2 min" --no-pager -p warning
```

If `sysstat` is installed (set up by `install-debugging-stack` script), look at memory + swap right before the kill:
```bash
sar -r -s 14:20:00 -e 14:25:00
sar -S -s 14:20:00 -e 14:25:00
sar -B -s 14:20:00 -e 14:25:00     # paging activity
```

## Report structure

For each OOM event found, report:
- Wall-clock time
- Which actor fired (kernel / oomd / earlyoom)
- Process or cgroup killed (with cmdline if recoverable)
- RSS at time of kill
- Memory + swap state in the 5 min leading up to the kill (if sysstat available)
- Whether this was a one-off or part of a recurring pattern (count over last 7 days)

If the user has no userspace OOM protection and is hitting kernel OOM, recommend running `setup-oom-protection`.

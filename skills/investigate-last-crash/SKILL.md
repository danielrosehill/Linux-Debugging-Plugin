---
name: investigate-last-crash
description: Open a forensic investigation into the most recent Linux crash, freeze, or unexpected reboot. Collects kernel dumps, previous-boot journal, userspace core dumps, and sar metrics, correlates them around the crash timestamp, and writes a findings report. Use when the user says "investigate the crash", "why did my system reboot", "open a crash investigation", or similar.
---

# Investigate Last Crash

Run a systematic post-mortem on the most recent unexpected shutdown, kernel panic, or hard freeze.

## Step 1: Identify the crash window

Enumerate recent boots and spot abrupt endings:

```bash
journalctl --list-boots --no-pager | tail -10
```

A boot that ends with a "last entry" timestamp close to the next boot's "first entry" with no clean shutdown messages in between is a crash candidate. Clean shutdowns log `systemd-shutdown` / `Reached target Shutdown`; crashes do not.

For each suspicious boot, confirm:

```bash
journalctl -b <boot-id> --no-pager | tail -30
```

Clean shutdown patterns: `Stopped target`, `Reached target Shutdown`, `System Power Off`.
Crash patterns: no shutdown messages, last line mid-operation, or kernel oops/panic messages.

## Step 2: Collect kernel-side evidence

**Kernel core dumps** (if kdump is installed):
```bash
ls -la /var/crash/
```
Each subdirectory is a crash — contains `dmesg.<timestamp>` (human-readable) and `dump.<timestamp>` (full vmcore for `crash` tool analysis).

**pstore** — firmware-backed oops log that survives reboot:
```bash
ls -la /sys/fs/pstore/ 2>/dev/null
```
Read any `dmesg-*` files — they contain the kernel output right before the hang.

**Kernel ring buffer of the crashed boot:**
```bash
journalctl -b -1 -k --no-pager | tail -100
```
Look for: `BUG:`, `Oops:`, `Kernel panic`, `Hardware Error`, `MCE`, `NMI`, `soft lockup`, `hung task`.

## Step 3: Collect userspace evidence

**Core dumps from systemd-coredump:**
```bash
coredumpctl list --since=-1d
```
For each relevant entry:
```bash
coredumpctl info <PID>
```

**Previous-boot journal — last 5 minutes before crash:**
```bash
# Get crash timestamp from journalctl --list-boots, then:
journalctl -b -1 --since "HH:MM:SS" --no-pager
```

Look for: repeated service failures, OOM killer invocations (`Out of memory`), segfaults, GPU resets (`amdgpu`, `i915`, `nvidia`), audio stack errors, disk I/O errors (`blk_update_request`), filesystem corruption.

## Step 4: Correlate with system metrics

If sysstat is running, pull sar data from the crash window:
```bash
# sar rotates daily; -f points to a specific day's file
sar -A -s HH:MM:SS -e HH:MM:SS -f /var/log/sysstat/saXX | head -200
```

Useful individual views:
- `sar -u -f <file>` CPU saturation
- `sar -r -f <file>` memory pressure
- `sar -B -f <file>` paging / swap thrashing
- `sar -d -f <file>` disk I/O
- `sar -n DEV -f <file>` network

## Step 5: Hardware health check

```bash
# Machine Check Exceptions (CPU/RAM hardware errors)
journalctl -b -1 | grep -iE "mce|machine check|hardware error"

# GPU resets
journalctl -b -1 | grep -iE "gpu hang|gpu reset|ring .* timeout|amdgpu|nouveau|i915|nvidia"

# Disk errors
journalctl -b -1 | grep -iE "ata[0-9].*error|i/o error|medium error|smart"

# Thermal
journalctl -b -1 | grep -iE "thermal|throttl|overtemp"
```

## Step 6: Write findings

Save a dated report to `~/Daniel-Workstation-Updates/YYYY-MM-DD/crash-investigation.md` (or whatever workstation-log location the user prefers). Structure:

```markdown
# Crash Investigation — <date> <time>

## Timeline
- Last normal activity: <timestamp>
- First crash indicator: <timestamp> — <event>
- System reboot: <timestamp>

## Evidence
- Kernel dump: <path or "none">
- pstore entries: <count>
- Core dumps: <list>
- Relevant journal lines: <quoted>
- sar anomalies: <summary>

## Root cause hypothesis
<best theory with confidence level>

## Contributing factors
<list>

## Recommended next steps
<actions>
```

## Step 7: Report back

Summarise verbally to the user:
- What triggered the crash (best hypothesis)
- Confidence level (high / medium / low)
- Whether the evidence is conclusive or more data is needed
- What to do if it happens again (e.g. enable netconsole, run memtest, check specific hardware)

## Notes

- If `/var/crash` is empty and the crash was a full hang, kdump may not have been active yet (it needs a reboot after install to arm). Document this so the user knows to expect real data on the next incident.
- If the user lacks any of kdump / sysstat / persistent journal, flag the gap and suggest running the plugin's install script.
- For freezes without any logs at all, recommend enabling netconsole to another LAN host as the next diagnostic step (see `setup-netconsole` skill).

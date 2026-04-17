# Linux Crash Forensics

A Claude Code plugin for instrumenting Linux workstations to capture hard crashes, freezes, and unexpected reboots — then running a systematic post-mortem when one happens.

Ships an idempotent installer that configures the standard crash-capture stack (kdump, persistent journald, sysstat, pstore) plus a set of investigation skills that walk the AI agent through a structured forensic workflow.

## What it installs

| Tool | Purpose |
|---|---|
| `linux-crashdump` (kdump-tools) | Captures full kernel core dumps on panic via kexec, writes to `/var/crash/` |
| `sysstat` | Records CPU / memory / I/O / network every 10 min — `sar` lets you look back at system state right before the freeze |
| Persistent journald | Makes `journalctl -b -1` survive reboot so logs are available after a crash |
| `systemd-coredump` | Captures userspace segfault core dumps (usually already active on Debian/Ubuntu) |
| `pstore` check | Verifies firmware-backed crash storage is available as a belt-and-braces fallback |

## Skills

- **`investigate-last-crash`** — Systematic post-mortem: enumerate boots, identify the crash window, collect kernel + userspace evidence, correlate with sar metrics, write a findings report.
- **`setup-netconsole`** — Configure netconsole to stream kernel oops messages over UDP to another LAN host, for capturing freezes that leave no local log trail.
- **`review-pstore`** — Inspect `/sys/fs/pstore` for firmware-saved panic logs that survive reboots.

## Installation

From the Claude Code marketplace:

```bash
claude plugins install danielrosehill/Linux-Crash-Forensics-Plugin
```

Then run the install script to set up the diagnostic stack on your machine:

```bash
bash ~/.claude/plugins/<path>/scripts/install-crash-forensics.sh
```

Or clone and run directly:

```bash
git clone https://github.com/danielrosehill/Linux-Crash-Forensics-Plugin
cd Linux-Crash-Forensics-Plugin
bash scripts/install-crash-forensics.sh
```

A reboot is required for kdump to become active.

## Usage

After a crash, start a Claude Code session and invoke the investigation skill:

> "Investigate the last crash"

The agent will walk through the boot list, pull kernel dumps, correlate with sar data, and write a dated findings report.

For systems where crashes leave no local trace, run the `setup-netconsole` skill to stream kernel messages to another host.

## Supported platforms

Debian / Ubuntu (tested on Ubuntu 25.10 with KDE Plasma). The install script detects `apt`; other distros will need a manual port.

## License

MIT

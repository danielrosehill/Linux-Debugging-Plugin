# Linux Debugging

A Claude Code plugin for debugging Linux desktops — targeted journal/boot/log inspection skills, plus an idempotent installer that instruments the system with the proactive logging tools needed to catch hard crashes and analyze them after the fact.

**Targets Ubuntu + Wayland desktops.** Most skills work on any systemd Linux; the install script assumes `apt`. Forkable for other distros.

## What it installs (proactive instrumentation)

Run `scripts/install-debugging-stack.sh` once to set up:

| Tool | Purpose |
|---|---|
| Persistent journald | `journalctl -b -1` survives reboot — logs available after a hard crash |
| `linux-crashdump` (kdump-tools) | Full kernel core dumps on panic via kexec, written to `/var/crash/` |
| `sysstat` | Records CPU / memory / I/O / network every 10 min — `sar` lets you look back at system state before a freeze |
| `systemd-coredump` | Captures userspace segfault core dumps |
| `pstore` check | Verifies firmware-backed crash storage as a belt-and-braces fallback |

Userspace OOM protection (systemd-oomd / earlyoom) is handled separately by the `setup-oom-protection` skill.

## Skills

### Live debugging

- **`journal-inspect`** — Targeted `journalctl` queries by unit, time, priority, kernel scope, with structured/JSON output for AI analysis. The default replacement for `journalctl -xe`.
- **`boot-inspect`** — Failed units, `systemd-analyze blame/critical-chain`, kernel boot messages, boot-to-boot diff. Wayland session services included.
- **`log-inspect`** — Non-journal log sources: app state dirs (`~/.cache`, `~/.local/state`), `/var/log/*`, dpkg/apt history, snap/flatpak. Uses ripgrep + jq for AI-friendly output.

### Memory & OOM

- **`setup-oom-protection`** — Configure systemd-oomd (Ubuntu 22.04+) or earlyoom so the desktop kills runaway processes before the kernel hard-locks under memory pressure.
- **`inspect-oom-events`** — Find past OOM kills (kernel + oomd + earlyoom) in the journal and reconstruct what was running, correlated with sar memory/swap data.

### Persistent logging & crash forensics

- **`validate-persistent-journal`** — Verify `/var/log/journal` is active so logs survive reboot. Configure if not. Precondition for any post-crash investigation.
- **`investigate-last-crash`** — Systematic post-mortem after a hard crash: enumerate boots, identify the crash window, collect kernel + userspace evidence, correlate with sar metrics, write a findings report.
- **`setup-netconsole`** — Stream kernel oops messages over UDP to another LAN host, for capturing freezes that leave no local log trail.
- **`review-pstore`** — Inspect `/sys/fs/pstore` for firmware-saved panic logs that survive reboots.

## Installation

From the Claude Code marketplace:

```bash
claude plugins install linux-debugging@danielrosehill
```

Then, optionally, run the proactive instrumentation installer:

```bash
git clone https://github.com/danielrosehill/Linux-Debugging-Plugin
cd Linux-Debugging-Plugin
bash scripts/install-debugging-stack.sh
```

A reboot is required for kdump to become active.

## Usage

Invoke skills naturally in a Claude Code session:

> "Inspect the journal for errors in the last hour"
> "Why is boot taking 45 seconds?"
> "Set up OOM protection on this machine"
> "Investigate the last crash"

## Supported platforms

Ubuntu (tested on Ubuntu 25.10 with KDE Plasma on Wayland). Most skills are systemd-portable; the install script is `apt`-only. Fork and adapt the installer for other distros.

## License

MIT

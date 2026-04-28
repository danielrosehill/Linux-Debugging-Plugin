---
name: log-inspect
description: Inspect non-journal log sources on a Linux desktop — Xorg/Wayland session logs, application logs in ~/.cache and ~/.local/state, /var/log/* leftovers, and dmesg — using AI-friendly tools (ripgrep, jq, structured queries) that produce focused, parseable output instead of raw log dumps. Use when journald doesn't have what you need or when an app writes its own log files.
---

# Log Inspect

Not everything goes through journald. This skill covers the other surfaces, with an emphasis on tools whose output an AI agent can usefully analyze without burning context.

## Tooling preference

- **`rg`** (ripgrep) over `grep` — faster, respects gitignore-like filters, better default output.
- **`jq`** for any JSON log (Chrome, VS Code, modern Node apps).
- **`tail -n N`** with explicit count, never `tail -f` in an agent session.
- **`awk '/pattern/'`** when you need field-level slicing.

Avoid `cat` on large logs — open with `Read` (limit + offset) or pipe through `rg -m N` to cap results.

## Where desktop apps actually log on modern Linux

| Source | Path |
|---|---|
| User systemd unit logs | `journalctl --user -u <unit>` |
| App-managed logs | `~/.cache/<app>/`, `~/.local/state/<app>/`, `~/.config/<app>/logs/` |
| Xorg (legacy) | `~/.local/share/xorg/Xorg.0.log`, `/var/log/Xorg.0.log` |
| Wayland compositor | journald, user scope: `journalctl --user -t kwin_wayland` (KDE), `-t gnome-shell` (GNOME) |
| GPU / Mesa | `dmesg`, plus `MESA_DEBUG=1` runtime env |
| APT / dpkg | `/var/log/apt/`, `/var/log/dpkg.log` |
| Auth | `/var/log/auth.log` (or `journalctl _COMM=sudo`) |
| Cron | `journalctl _COMM=cron` (modern) or `/var/log/syslog` |
| Snap | `journalctl _COMM=snapd`, `snap logs <snap>` |
| Flatpak | `flatpak run --log-session-bus <app>` for live, otherwise journald |

## Patterns

### Find recent errors across an app's state dir
```bash
rg -i --no-ignore -t log -m 5 -e '(error|fatal|panic|traceback|stack)' ~/.local/state/<app>/ ~/.cache/<app>/
```

### Wayland compositor crashes (KDE)
```bash
journalctl --user -t kwin_wayland --since "24 hours ago" --no-pager -p warning
ls -lt ~/.cache/kwin/ ~/.local/share/sddm/ 2>/dev/null
```

### Xorg log (only on legacy X11 sessions — won't exist on a pure Wayland system)
```bash
rg -i -m 20 -e '\(EE\)|\(WW\)|FATAL' ~/.local/share/xorg/Xorg.0.log
```

### Snap / Flatpak app misbehaving
```bash
snap logs <snap-name> -n 200
journalctl --user --since "1 hour ago" --no-pager | rg -i <appname>
```

### dpkg / apt history (correlate a regression with a recent install)
```bash
zcat -f /var/log/dpkg.log* | rg ' (install|upgrade|remove) ' | tail -50
zcat -f /var/log/apt/history.log* | tail -100
```

## When you find a structured log

If the file is JSON-lines:
```bash
jq -c 'select(.level=="error" or .level=="fatal") | {t:.time, m:.msg, ctx:.context}' < log.jsonl | tail -50
```

If it's plain but timestamped, slice by time:
```bash
awk '/^2026-04-28T14:2[0-5]/' app.log
```

## What to feed back to the user

- Which file(s) you inspected and how big they were
- The query you ran (so the user can re-run it themselves)
- A deduplicated, time-ordered list of distinct error patterns (not every line)
- A hypothesis about which subsystem is implicated, or "no signal here, try journald next"

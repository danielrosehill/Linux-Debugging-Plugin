---
name: setup-oom-protection
description: Install and configure userspace OOM protection (systemd-oomd or earlyoom) so a desktop running out of memory kills the offending process before the kernel hard-locks the machine. Use when the user reports freezes under memory pressure, or proactively when setting up a new desktop. Ubuntu 22.04+ ships systemd-oomd by default; this skill verifies its config and falls back to earlyoom on older systems.
---

# Setup OOM Protection

A Wayland desktop under heavy memory pressure (Chrome with 200 tabs, a runaway build, an LLM swallowing RAM) will freeze before the in-kernel OOM killer fires — the system thrashes swap and becomes unresponsive for minutes. Userspace OOM daemons watch pressure metrics (PSI) and kill earlier.

## Decision tree

1. Ubuntu 22.04+ / Fedora 34+ / any systemd 248+ → use **systemd-oomd** (already installed).
2. Older systems, no PSI support, or user prefers a simple daemon → use **earlyoom**.

Check systemd version: `systemctl --version | head -1`

## Path A: systemd-oomd

### Verify it's running
```bash
systemctl status systemd-oomd
systemd-cgls /sys/fs/cgroup/user.slice
oomctl
```

`oomctl` lists which cgroups are being watched. If empty, no slice has `ManagedOOMSwap=kill` or `ManagedOOMMemoryPressure=kill` set.

### Enable for user session (Ubuntu default for desktops)
The Ubuntu default already enables `ManagedOOMSwap=kill` on `user@.service`. Verify:
```bash
systemctl cat user@.service | grep -i ManagedOOM
systemctl cat user.slice | grep -i ManagedOOM
```

If missing, drop in an override:
```bash
sudo systemctl edit user@.service
```
Add:
```
[Service]
ManagedOOMSwap=kill
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=50%
```

Reload and verify with `oomctl`.

### Tune thresholds
Edit `/etc/systemd/oomd.conf.d/local.conf`:
```
[OOM]
SwapUsedLimit=90%
DefaultMemoryPressureLimit=60%
DefaultMemoryPressureDurationSec=20s
```

## Path B: earlyoom

```bash
sudo apt install earlyoom
sudo systemctl enable --now earlyoom
```

Defaults: kill at 10% free RAM and 10% free swap. Tune in `/etc/default/earlyoom`:
```
EARLYOOM_ARGS="-r 60 -m 5 -s 5 --avoid '(^|/)(systemd|sshd|init|bash|kwin_wayland|plasmashell)$' --prefer '(^|/)(chrome|firefox|node|python)'"
```

`-m 5 -s 5` = trigger at 5% free RAM and 5% swap. `--avoid` protects critical desktop processes; `--prefer` targets memory hogs first.

## Verify protection actually works

Stress test (use a VM or be ready to lose unsaved work):
```bash
stress-ng --vm 4 --vm-bytes 90% --timeout 60s
```

Then check what fired:
```bash
journalctl -u systemd-oomd -b --no-pager        # path A
journalctl -u earlyoom -b --no-pager            # path B
```

## Confirm to user

Report:
- Which daemon is active and version
- Which cgroups / processes it's watching
- Current thresholds
- Whether a stress test confirmed it fires before kernel OOM

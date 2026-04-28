---
name: validate-persistent-journal
description: Verify that systemd-journald is configured for persistent storage so logs survive reboot — essential for diagnosing hard crashes and unexpected reboots. Configures it if not. Use proactively on any new desktop, and as a precondition before any post-crash investigation skill.
---

# Validate Persistent Journal

By default on some distros, journald stores logs only in `/run/log/journal` (tmpfs) and they vanish on reboot. For crash forensics you need them in `/var/log/journal` so `journalctl -b -1` works after the system comes back up.

## Check current state

```bash
journalctl --list-boots --no-pager | head -10
ls -la /var/log/journal/ 2>/dev/null
ls -la /run/log/journal/ 2>/dev/null
grep -E '^Storage=' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/*.conf 2>/dev/null
```

Three states to distinguish:
1. **Persistent active**: `/var/log/journal/<machine-id>/` exists and contains `.journal` files; `--list-boots` shows multiple entries.
2. **Volatile only**: only `/run/log/journal/` exists; `--list-boots` shows one entry; previous boots are gone.
3. **Auto mode without dir**: config says `Storage=auto` (the default) but `/var/log/journal/` doesn't exist, so journald falls back to volatile.

## Enable persistent storage

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
journalctl --list-boots --no-pager | head -3
```

For an explicit configuration (not relying on `auto`), drop in:
```bash
sudo tee /etc/systemd/journald.conf.d/persistent.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=2G
SystemKeepFree=1G
SystemMaxFileSize=200M
MaxRetentionSec=1month
ForwardToSyslog=no
EOF
sudo systemctl restart systemd-journald
```

Tune `SystemMaxUse` to taste — 2G holds many weeks of desktop logs.

## Verify it survives a reboot

After enabling, the test is on the next reboot:
```bash
journalctl --list-boots --no-pager | head -5
```
Should show at least 2 entries with distinct timestamps. If `-b -1` returns content, you're good.

## Report

State explicitly:
- Storage mode (persistent / volatile / auto-without-dir)
- Path of journal files
- Number of boots retained
- Disk usage (`journalctl --disk-usage`)
- Whether action was taken or the system was already correctly configured

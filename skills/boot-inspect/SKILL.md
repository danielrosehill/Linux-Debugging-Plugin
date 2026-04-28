---
name: boot-inspect
description: Inspect boot health on a systemd Linux system — failed units, slow services, kernel boot messages, and boot-to-boot comparison. Use when the user reports slow boot, services not starting, or wants to check post-reboot health. Targets Ubuntu/Debian + Wayland desktops but works on any systemd host.
---

# Boot Inspect

Systematic boot-time inspection. Run these in order; stop when you find the cause.

## 1. Failed units (the cheapest signal)

```bash
systemctl --failed --no-pager
```

For each failed unit, get its log:
```bash
journalctl -u <unit> -b --no-pager -p warning
```

Also check user-scope units (Wayland desktop session services often live here):
```bash
systemctl --user --failed --no-pager
```

## 2. Boot timing

```bash
systemd-analyze
systemd-analyze blame --no-pager | head -20
systemd-analyze critical-chain --no-pager
```

`blame` shows per-unit start time. `critical-chain` shows the dependency path that determined total boot time — fixing the slowest unit on the chain is what actually shortens boot.

## 3. Kernel ring buffer for this boot

```bash
dmesg --level=err,warn --ctime
journalctl -k -b -p warning --no-pager
```

Look for: firmware errors, ACPI warnings, GPU driver issues (especially relevant on Wayland — amdgpu/i915/nvidia messages), thermal events, USB errors.

## 4. Compare to previous boot

If a regression appeared after a recent reboot:
```bash
journalctl --list-boots --no-pager | head -10
journalctl -k -b -1 -p warning --no-pager > /tmp/prev-boot.log
journalctl -k -b 0 -p warning --no-pager > /tmp/curr-boot.log
diff /tmp/prev-boot.log /tmp/curr-boot.log
```

Requires persistent journald. If `--list-boots` only shows one entry, run `validate-persistent-journal`.

## 5. Display manager + Wayland session (desktop-specific)

For KDE Plasma on Wayland:
```bash
journalctl -u sddm -b --no-pager -p warning
journalctl --user -t plasmashell -b --no-pager -p warning
journalctl --user -t kwin_wayland -b --no-pager -p warning
```

For GNOME on Wayland:
```bash
journalctl -u gdm -b --no-pager -p warning
journalctl --user -t gnome-shell -b --no-pager -p warning
```

## Reporting

Structure findings as:
- **Boot time**: total + slowest 3 units
- **Failures**: each failed unit with its key log line
- **Kernel concerns**: errors/warnings from dmesg, grouped by subsystem
- **Regression vs previous boot**: yes/no, and diff summary if yes

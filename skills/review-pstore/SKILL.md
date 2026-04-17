---
name: review-pstore
description: Inspect /sys/fs/pstore for kernel oops and panic messages captured in firmware-backed storage (EFI vars, ACPI ERST, or ramoops) that survive a reboot. Use when the user says "check pstore", "any firmware-saved crash logs", or after a hard freeze on a system where kdump may not have worked.
---

# Review pstore

`pstore` is a kernel subsystem that saves the last kernel messages to non-volatile storage (EFI variables, ACPI ERST, or ramoops-reserved RAM) so they survive a crash + reboot even when disk-based logging is unavailable. Complementary to kdump; more likely to capture very early or very hard hangs.

## Step 1: Check availability

```bash
ls -la /sys/fs/pstore/
mount | grep pstore
```

If the directory is empty but pstore is mounted, no crash data has been captured (or it was cleared). If `/sys/fs/pstore` does not exist, the backend is not enabled.

## Step 2: Identify entries

Typical file naming:
- `dmesg-<backend>-<id>` — kernel log fragments
- `console-<backend>-<id>` — console output
- `pmsg-<backend>-<id>` — userspace messages via `/dev/pmsg0`

`<backend>` is one of `efi`, `erst`, `ramoops`.

## Step 3: Read and archive

```bash
# View
sudo less /sys/fs/pstore/dmesg-*

# Archive before the kernel auto-clears (some backends clear on read)
sudo cp /sys/fs/pstore/* ~/crash-archive/pstore-$(date +%Y%m%d-%H%M%S)/
```

Concatenate multi-part dumps in order — pstore splits long oops across multiple files numbered sequentially.

## Step 4: Interpret

Look for:
- **Call trace** — function chain leading to the panic. Top of the trace is the immediate cause.
- **RIP / PC** — instruction pointer at crash.
- **Tainted flags** — e.g. `Tainted: G OE` indicates out-of-tree modules (nvidia, vbox, etc.) were loaded.
- **Hardware errors** — `Machine Check Exception`, `Hardware Error`, `MCE: ...` point at CPU/RAM/firmware faults rather than software bugs.

## Step 5: Clear old entries (optional)

Once archived, clear to make room for the next crash:

```bash
sudo rm /sys/fs/pstore/*
```

## Enabling pstore backends

If pstore is unavailable, enable one of:

- **EFI vars** (most common on modern UEFI):
  ```bash
  sudo modprobe efi_pstore
  ```
  Add `efi_pstore` to `/etc/modules-load.d/pstore.conf` for persistence.

- **ramoops** (works without UEFI, needs reserved memory):
  Add to kernel cmdline: `ramoops.mem_address=0x8000000 ramoops.mem_size=0x200000 ramoops.ecc=1`

- **ACPI ERST** — automatic if firmware supports it; check `dmesg | grep -i erst`.

## Caveats

- EFI vars have limited space (~60 KB on most firmware). Clear old entries or the backend stops capturing new ones.
- Some motherboards leak EFI var writes — pstore spam can brick poorly-designed firmware. Rare but documented.
- ramoops requires reserving RAM at boot; the reserved region is lost from normal system use.

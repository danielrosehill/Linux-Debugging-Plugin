#!/usr/bin/env bash
# Install crash-diagnostic tooling on a Debian/Ubuntu system.
# Idempotent — safe to re-run. Requires sudo.

set -euo pipefail

log() { printf '\033[1;34m[linux-debugging]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[linux-debugging]\033[0m %s\n' "$*" >&2; }
err() { printf '\033[1;31m[linux-debugging]\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

if ! command -v apt-get >/dev/null 2>&1; then
  err "This installer targets Debian/Ubuntu (apt). Detected a non-apt system — aborting."
  exit 1
fi

log "Updating package lists..."
$SUDO apt-get update -qq

log "Installing linux-crashdump (kdump-tools) and sysstat..."
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y linux-crashdump sysstat

log "Enabling persistent journald..."
if [[ ! -d /var/log/journal ]]; then
  $SUDO mkdir -p /var/log/journal
  $SUDO systemd-tmpfiles --create --prefix /var/log/journal
  $SUDO systemctl restart systemd-journald
  log "Persistent journal enabled at /var/log/journal"
else
  log "Persistent journal already enabled"
fi

log "Enabling sysstat data collection..."
if [[ -f /etc/default/sysstat ]]; then
  $SUDO sed -i 's/^ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
fi
$SUDO systemctl enable --now sysstat.service 2>/dev/null || true
$SUDO systemctl enable --now sysstat-collect.timer 2>/dev/null || true
$SUDO systemctl enable --now sysstat-summary.timer 2>/dev/null || true

log "Verifying systemd-coredump is active (userspace crash capture)..."
if systemctl is-active systemd-coredump.socket >/dev/null 2>&1; then
  log "systemd-coredump.socket active"
else
  warn "systemd-coredump not active — attempting to enable"
  $SUDO systemctl enable --now systemd-coredump.socket 2>/dev/null || warn "Could not enable systemd-coredump (may not be available on this system)"
fi

log "Checking pstore (firmware-backed crash storage)..."
if [[ -d /sys/fs/pstore ]]; then
  count=$(ls /sys/fs/pstore 2>/dev/null | wc -l)
  log "pstore mounted — $count entries present"
else
  warn "pstore not available on this system"
fi

log ""
log "=============================================="
log " Install complete. Summary:"
log "=============================================="
log " kdump-tools:     $(dpkg -s kdump-tools 2>/dev/null | awk '/^Status/{print $NF}')"
log " sysstat:         $(dpkg -s sysstat 2>/dev/null | awk '/^Status/{print $NF}')"
log " persistent log:  $([[ -d /var/log/journal ]] && echo enabled || echo disabled)"
log " coredumpctl:     $(command -v coredumpctl >/dev/null && echo available || echo missing)"
log ""
log " Reboot required for kdump to become active."
log " After reboot, verify with:  kdump-config show"
log ""
log " Next crash? Run the investigate-last-crash skill."

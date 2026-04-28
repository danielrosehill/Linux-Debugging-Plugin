#!/usr/bin/env bash
# Reverse the linux-debugging install on Debian/Ubuntu.
# Does NOT delete /var/crash or /var/log/journal contents.

set -euo pipefail

log() { printf '\033[1;34m[linux-debugging]\033[0m %s\n' "$*"; }

if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

log "Disabling sysstat timers..."
$SUDO systemctl disable --now sysstat-collect.timer sysstat-summary.timer sysstat.service 2>/dev/null || true

log "Removing packages (kdump-tools, sysstat, linux-crashdump)..."
$SUDO apt-get remove -y linux-crashdump kdump-tools sysstat || true

log "Persistent journal left intact at /var/log/journal (remove manually if desired)."
log "Uninstall complete."

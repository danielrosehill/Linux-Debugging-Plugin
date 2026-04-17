---
name: setup-netconsole
description: Configure netconsole to stream kernel oops and panic messages over UDP to another host on the LAN, for capturing crashes on systems that hang before writing to disk. Use when the user says "set up netconsole", "stream kernel logs over the network", or is dealing with crashes that leave no local log trail.
---

# Set Up Netconsole

Netconsole streams kernel messages to a remote syslog receiver over UDP at very low level — it keeps working during hangs when disk I/O and userspace are already dead. Essential for diagnosing freezes that leave no local evidence.

## Prerequisites

Ask the user:
1. **Receiver host** — IP of a machine on the same LAN that will collect logs (e.g. a Raspberry Pi, NAS, or router with syslog).
2. **Receiver port** — default `6666` is fine.
3. **Sender interface** — usually the main Ethernet interface. Detect with `ip route get <receiver-ip>`.

## Step 1: Load the module with target config

Identify sender gateway MAC (required by netconsole):

```bash
ip route get <receiver-ip>
# note the dev (e.g. eno1)
arp -n <gateway-ip>
# note the MAC
```

Load `netconsole`:

```bash
sudo modprobe netconsole netconsole=@<sender-ip>/<iface>,<port>@<receiver-ip>/<gateway-mac>
```

Test it:
```bash
echo "netconsole test from $(hostname)" | sudo tee /dev/kmsg
```

On the receiver, you should see the line arrive.

## Step 2: Set up receiver

On the receiver host, either:

**Quick — netcat one-liner:**
```bash
nc -u -l <port> | tee -a netconsole-$(hostname).log
```

**Persistent — systemd-journal-remote or rsyslog:**
Configure rsyslog to listen on UDP and write to `/var/log/netconsole-<sender>.log`.

## Step 3: Persist across reboots

Create `/etc/modules-load.d/netconsole.conf`:
```
netconsole
```

And `/etc/modprobe.d/netconsole.conf`:
```
options netconsole netconsole=@<sender-ip>/<iface>,<port>@<receiver-ip>/<gateway-mac>
```

Note: if the sender uses DHCP, the IPs may shift. Consider configuring a DHCP reservation or switching to dynamic netconsole via configfs (`/sys/kernel/config/netconsole/`).

## Step 4: Verify after reboot

```bash
dmesg | grep netconsole
# should show: netconsole: network logging started
```

## Caveats

- Netconsole is UDP — no guarantee of delivery. For critical cases use a wired LAN, not Wi-Fi.
- Large messages may be truncated. Kernel oops output is designed to fit.
- Does not help with sudden power loss or pre-networking crashes (very early boot).
- Firewalls: ensure UDP/`<port>` is open on the receiver.

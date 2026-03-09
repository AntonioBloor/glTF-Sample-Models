# x-ui / 3x-ui Uninstall Script

This document explains how to use `scripts/uninstall-xui.sh` to completely remove
**x-ui**, **3x-ui**, or **xray-ui** installations from a Linux server.

---

## ⚠️ Safety Warnings

> **This script is destructive.** It permanently stops services, removes Docker
> containers and images, and deletes installation directories. Data that is removed
> cannot be recovered unless you have a backup.

* **Always run `--dry-run` first** to preview everything that will be deleted.
* Back up any configuration files you want to keep (e.g. `/etc/x-ui/`) before proceeding.
* The script requires **root** privileges (`sudo`).
* Removing Docker images will free disk space but any customisations baked into
  those images will be lost permanently.

---

## What the Script Removes

| Category | Items |
|---|---|
| Systemd services | `x-ui`, `3x-ui`, `xray-ui` (stopped and disabled) |
| Systemd unit files | `/etc/systemd/system/{x-ui,3x-ui,xray-ui}.service` (optional) |
| Docker containers | Containers named `x-ui`, `3x-ui`, or `xray-ui` |
| Docker images | Images named `x-ui`, `3x-ui`, or `xray-ui` |
| Install directories | `/usr/local/x-ui`, `/usr/local/3x-ui`, `/etc/x-ui`, `/etc/3x-ui`, `/opt/x-ui`, `/opt/3x-ui` |

---

## Installation

No installation is needed. Download or copy the script to your server:

```bash
curl -fsSL https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/scripts/uninstall-xui.sh \
  -o uninstall-xui.sh
chmod +x uninstall-xui.sh
```

---

## Usage

```
sudo bash uninstall-xui.sh [OPTIONS]
```

### Options

| Option | Description |
|---|---|
| `--dry-run` | Preview all actions without making any changes |
| `--yes` / `-y` | Skip the confirmation prompt (non-interactive / CI use) |
| `--keep-unit-files` | Stop/disable services but leave `.service` unit files in place |
| `--log <file>` | Append log output to `<file>` (default: `/var/log/uninstall-xui.log`) |
| `--help` / `-h` | Print usage information and exit |

---

## Step-by-Step Guide

### 1 — Preview with dry-run (recommended)

```bash
sudo bash uninstall-xui.sh --dry-run
```

Review the output. Nothing is changed. Example output:

```
════════════════════════════════════════════════════════════
  x-ui / 3x-ui / xray-ui  —  Uninstaller v1.0.0
════════════════════════════════════════════════════════════
  *** DRY-RUN MODE — no changes will be made ***

Systemd services detected:
  • x-ui

Systemd unit files to remove:
  • /etc/systemd/system/x-ui.service

Docker containers to remove:
  (none)

Docker images to remove:
  (none)

Directories to remove:
  • /usr/local/x-ui
  • /etc/x-ui
```

### 2 — Run the uninstaller

```bash
sudo bash uninstall-xui.sh
```

You will see the same preview and then be prompted:

```
Proceed with uninstallation? [y/N]
```

Type `y` and press Enter to continue.

### 3 — Verify

```bash
systemctl status x-ui      # should report "not found"
ls /usr/local/x-ui         # should fail with "No such file or directory"
```

---

## Non-Interactive / Scripted Use

Use `--yes` to skip the confirmation prompt when running from automation:

```bash
sudo bash uninstall-xui.sh --yes --log /root/xui-removal.log
```

---

## Keeping Unit Files

If you want to stop the service but preserve the `.service` file for reinstallation
later, pass `--keep-unit-files`:

```bash
sudo bash uninstall-xui.sh --keep-unit-files
```

---

## Log File

By default the script appends timestamped entries to `/var/log/uninstall-xui.log`:

```
[2026-03-01 12:00:00] [INFO ] Starting uninstallation — logging to /var/log/uninstall-xui.log
[2026-03-01 12:00:00] [INFO ] Stopping service: x-ui
[2026-03-01 12:00:01] [INFO ] Disabling service: x-ui
[2026-03-01 12:00:01] [INFO ] Removing unit file: /etc/systemd/system/x-ui.service
[2026-03-01 12:00:01] [INFO ] Reloading systemd daemon
[2026-03-01 12:00:02] [INFO ] Removing directory: /usr/local/x-ui
[2026-03-01 12:00:02] [OK   ] Uninstallation complete.
```

Use a custom path with `--log`:

```bash
sudo bash uninstall-xui.sh --log /tmp/my-removal.log
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `Must be run as root` | Prepend `sudo` to the command |
| Service not detected | The service may already be gone; check with `systemctl list-unit-files` |
| Docker items not detected | Docker may not be installed, or the container/image names differ from the defaults |
| Directory not removed | It may have already been removed; the script will warn rather than error |

---

## Frequently Asked Questions

**Q: Will this remove my Xray/V2Ray binaries?**  
A: Only if they reside inside one of the known install directories
(`/usr/local/x-ui`, `/etc/x-ui`, `/opt/x-ui`, etc.). Binaries installed at
standalone paths (e.g. `/usr/local/bin/xray`) are left untouched.

**Q: Can I run this on Ubuntu, Debian, CentOS, Rocky Linux?**  
A: Yes. The script uses standard POSIX tools and systemd, which are present on all
major Linux server distributions.

**Q: Will it affect other Docker containers?**  
A: No. Only containers and images whose names exactly match `x-ui`, `3x-ui`, or
`xray-ui` are targeted.

**Q: What if the server does not have Docker installed?**  
A: The Docker steps are skipped automatically.

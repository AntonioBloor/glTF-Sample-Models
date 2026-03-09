# x-ui Uninstall Guide

This guide covers how to completely remove **x-ui** (an Xray-based web panel) from a Linux server.
It addresses the two most common installation methods: the official install script / systemd service,
and Docker.

> **Safety note:** Before removing x-ui, ensure you have an alternative way to access your server
> (e.g., direct SSH access) and that no production traffic still depends on the panel. Take a backup
> of any configuration you may need later (`/etc/x-ui/` or `/usr/local/x-ui/`).

---

## Table of Contents

1. [Method 1 — Official Install Script / systemd Service](#method-1--official-install-script--systemd-service)
2. [Method 2 — Docker](#method-2--docker)
3. [Verify Removal](#verify-removal)
4. [Additional Cleanup (Optional)](#additional-cleanup-optional)

---

## Method 1 — Official Install Script / systemd Service

This is the most common installation method. x-ui registers itself as a systemd service and places
its files under `/usr/local/x-ui/` and `/etc/x-ui/`.

### Step 1 — Stop and disable the service

```bash
# Stop the running service
sudo systemctl stop x-ui

# Disable it so it no longer starts on boot
sudo systemctl disable x-ui
```

### Step 2 — Remove the systemd unit file

```bash
sudo rm -f /etc/systemd/system/x-ui.service

# Reload the systemd daemon so it forgets the removed unit
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

### Step 3 — Remove binaries and data directories

```bash
# Remove the main installation directory
sudo rm -rf /usr/local/x-ui

# Remove the configuration directory
sudo rm -rf /etc/x-ui
```

### Step 4 — Remove the management script (if present)

The official installer places a convenience script at `/usr/bin/x-ui`:

```bash
sudo rm -f /usr/bin/x-ui
```

### Step 5 — Remove the log file (optional)

```bash
sudo rm -f /var/log/x-ui/x-ui.log
sudo rmdir /var/log/x-ui 2>/dev/null || true
```

---

## Method 2 — Docker

If x-ui was deployed as a Docker container, use the following steps.

### Step 1 — Stop and remove the container

```bash
# Replace 'x-ui' with your actual container name if different
docker stop x-ui
docker rm x-ui
```

### Step 2 — Remove the Docker image

```bash
# List images to find the exact tag
docker images | grep x-ui

# Remove the image (adjust tag as needed)
docker rmi ghcr.io/alireza0/x-ui:latest
```

### Step 3 — Remove volumes and configuration data

If you mounted host directories into the container (e.g., `/etc/x-ui`):

```bash
sudo rm -rf /etc/x-ui
```

If you used named Docker volumes:

```bash
# List volumes associated with x-ui
docker volume ls | grep x-ui

# Remove each volume
docker volume rm <volume_name>
```

### Step 4 — Remove Docker Compose file (if used)

```bash
# Navigate to where your compose file lives and bring everything down first
docker compose down --volumes --remove-orphans

# Then delete the compose file and any related configuration
rm -f docker-compose.yml  # adjust path as needed
```

---

## Verify Removal

After completing the steps above, confirm x-ui has been fully removed.

### Check that the service is gone

```bash
systemctl status x-ui
# Expected: "Unit x-ui.service could not be found."
```

### Check that no x-ui processes are running

```bash
ps aux | grep x-ui | grep -v grep
# Expected: no output
```

### Check that binaries and directories are gone

```bash
ls /usr/local/x-ui 2>/dev/null && echo "STILL EXISTS" || echo "Removed"
ls /etc/x-ui       2>/dev/null && echo "STILL EXISTS" || echo "Removed"
ls /usr/bin/x-ui   2>/dev/null && echo "STILL EXISTS" || echo "Removed"
```

### Check that no listening ports remain (default x-ui port is 54321)

```bash
# Debian/Ubuntu
ss -tlnp | grep 54321

# CentOS/RHEL
ss -tlnp | grep 54321
```

Expected: no output.

---

## Additional Cleanup (Optional)

### Firewall rules

If you opened firewall ports for x-ui, close them now.

**Debian/Ubuntu (ufw):**

```bash
sudo ufw delete allow 54321/tcp
sudo ufw delete allow 443/tcp    # only if it was added exclusively for x-ui
sudo ufw reload
```

**CentOS/RHEL (firewalld):**

```bash
sudo firewall-cmd --permanent --remove-port=54321/tcp
sudo firewall-cmd --reload
```

### Xray core binary

x-ui bundles the Xray core binary inside `/usr/local/x-ui/`. Removing that directory (Step 3 above)
also removes Xray. If you have a standalone Xray installation you want to keep, do not remove those
paths and instead remove only the x-ui-specific files.

### Created system users

The official installer may create a dedicated system user. Check and remove it if no longer needed:

```bash
# Check if an 'x-ui' user exists
id x-ui 2>/dev/null && echo "user exists" || echo "user not found"

# Remove the user and its home directory (if it exists)
sudo userdel -r x-ui 2>/dev/null || true
```

---

## Quick Reference Summary

| Task | Command |
|---|---|
| Stop service | `sudo systemctl stop x-ui` |
| Disable service | `sudo systemctl disable x-ui` |
| Remove unit file | `sudo rm -f /etc/systemd/system/x-ui.service` |
| Reload systemd | `sudo systemctl daemon-reload` |
| Remove install dir | `sudo rm -rf /usr/local/x-ui` |
| Remove config dir | `sudo rm -rf /etc/x-ui` |
| Remove mgmt script | `sudo rm -f /usr/bin/x-ui` |
| Stop Docker container | `docker stop x-ui && docker rm x-ui` |
| Remove Docker image | `docker rmi ghcr.io/alireza0/x-ui:latest` |
| Verify no process | `ps aux | grep x-ui | grep -v grep` |
| Verify port closed | `ss -tlnp | grep 54321` |

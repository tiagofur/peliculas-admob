#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 VPS. Run as root:
#   ssh root@<ip> 'bash -s' < deploy/bootstrap.sh
# Leaves: Docker, firewall (22/80/443), automatic security updates, fail2ban,
# a `deploy` user with your SSH key, root/password SSH login disabled, swap,
# and /opt/peliculas ready for the app.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "run as root" >&2; exit 1; fi
if [[ ! -s /root/.ssh/authorized_keys ]]; then
	echo "no SSH key in /root/.ssh/authorized_keys: refusing to disable password login" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq
apt-get install -yq ca-certificates curl gnupg ufw fail2ban unattended-upgrades

# Docker from Docker's own apt repository.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# shellcheck source=/dev/null
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
	>/etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -yq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# Deploy user with the same SSH keys as root.
if ! id deploy >/dev/null 2>&1; then
	adduser --disabled-password --gecos "" deploy
fi
usermod -aG docker deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
install -d -o deploy -g deploy /opt/peliculas /opt/peliculas/backups

# SSH: keys only, no root.
cat >/etc/ssh/sshd_config.d/10-hardening.conf <<'CONF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
CONF
systemctl reload ssh

# Firewall. Docker publishes 80/443 itself; the API port is bound to 127.0.0.1.
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

# Security updates without asking.
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

# 2 GB swap so small VPS plans survive memory spikes.
if ! swapon --show | grep -q /swapfile; then
	fallocate -l 2G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

echo "done: log in from now on as  ssh deploy@<ip>"

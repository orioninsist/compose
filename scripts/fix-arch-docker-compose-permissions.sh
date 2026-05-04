#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER}}"
if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="${1:-}"
fi

if [[ -z "${TARGET_USER}" ]]; then
  echo "Usage: sudo $0 <username>"
  exit 2
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run with sudo: sudo $0 ${TARGET_USER}"
  exit 2
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  echo "User not found: ${TARGET_USER}"
  exit 2
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
  echo "Home directory not found for user: ${TARGET_USER}"
  exit 2
fi

echo "==> Installing Docker Compose packages with pacman"
pacman -S --needed --noconfirm docker docker-compose docker-buildx iptables-nft

echo "==> Ensuring docker group exists"
getent group docker >/dev/null || groupadd docker

echo "==> Adding ${TARGET_USER} to docker group"
usermod -aG docker "${TARGET_USER}"

echo "==> Enabling and starting Docker Engine"
systemctl enable --now docker.service

echo "==> Normalizing Docker socket ownership when it already exists"
if [[ -S /var/run/docker.sock ]]; then
  chown root:docker /var/run/docker.sock || true
  chmod 660 /var/run/docker.sock || true
fi

echo "==> Allowing unprivileged user namespaces for rootless/helper tooling"
sysctl -w kernel.unprivileged_userns_clone=1 >/dev/null || true
cat >/etc/sysctl.d/99-docker-compose-local.conf <<'SYSCTL'
kernel.unprivileged_userns_clone = 1
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1024
SYSCTL
sysctl --system >/dev/null || true

echo "==> Keeping Docker bridge/NAT traffic usable with iptables"
modprobe br_netfilter >/dev/null 2>&1 || true
cat >/etc/modules-load.d/docker-compose-local.conf <<'MODULES'
br_netfilter
MODULES
cat >/etc/sysctl.d/98-docker-bridge.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system >/dev/null || true

echo "==> Docker Compose CLI plugin check"
install -d -m 0755 "${TARGET_HOME}/.docker/cli-plugins"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.docker"

echo
echo "Done."
echo "Important: log out and log back in, or run: newgrp docker"
echo "Then verify with:"
echo "  docker version"
echo "  docker compose version"
echo "  docker run --rm hello-world"

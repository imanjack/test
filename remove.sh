#!/bin/bash

echo "⚠️ WARNING: This will remove OpenVPN, Easy-RSA, all keys, configs, and firewall rules."

read -p "Continue? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

echo "==> Stopping OpenVPN..."
systemctl stop openvpn@server || true

echo "==> Disabling OpenVPN..."
systemctl disable openvpn@server || true

echo "==> Removing OpenVPN and Easy-RSA..."
apt purge --remove openvpn easy-rsa -y
apt autoremove -y

echo "==> Deleting configuration and certificates..."
rm -rf /etc/openvpn
rm -rf ~/easy-rsa
rm -rf ~/openvpn-clients

echo "==> Cleaning UFW NAT rules..."
sed -i '/^*nat/,/^COMMIT/d' /etc/ufw/before.rules
sed -i 's/^DEFAULT_FORWARD_POLICY.*/DEFAULT_FORWARD_POLICY="DROP"/' /etc/default/ufw

echo "==> Reloading UFW..."
ufw disable && ufw enable

echo "✅ OpenVPN fully removed. Ready for a fresh install!"

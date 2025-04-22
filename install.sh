#!/bin/bash

set -e

VPN_PORT=443
VPN_PROTOCOL=tcp
VPN_SUBNET="10.8.0.0"
VPN_NETMASK="255.255.255.0"
EASYRSA_DIR=~/easy-rsa
SERVER_DIR=/etc/openvpn/server
SERVER_NAME=server

echo "==> Installing OpenVPN and Easy-RSA..."
apt update && apt install openvpn easy-rsa ufw curl -y

echo "==> Setting up PKI directory..."
make-cadir "$EASYRSA_DIR"
cd "$EASYRSA_DIR"

echo "==> Initializing PKI..."
./easyrsa init-pki
echo | ./easyrsa build-ca nopass
./easyrsa gen-req $SERVER_NAME nopass
echo yes | ./easyrsa sign-req server $SERVER_NAME
./easyrsa gen-dh
openvpn --genkey --secret ta.key

echo "==> Creating OpenVPN server directory..."
mkdir -p "$SERVER_DIR"
cp pki/ca.crt "$SERVER_DIR/"
cp pki/issued/$SERVER_NAME.crt "$SERVER_DIR/"
cp pki/private/$SERVER_NAME.key "$SERVER_DIR/"
cp pki/dh.pem "$SERVER_DIR/"
cp ta.key "$SERVER_DIR/"

echo "==> Creating server.conf..."
cat > "$SERVER_DIR/server.conf" <<EOF
port $VPN_PORT
proto $VPN_PROTOCOL
dev tun
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
dh dh.pem
tls-auth ta.key 0
server $VPN_SUBNET $VPN_NETMASK
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
explicit-exit-notify 1
EOF

echo "==> Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "==> Setting up UFW rules..."
ufw allow OpenSSH
ufw allow $VPN_PORT/$VPN_PROTOCOL

# Detect default network interface
INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5}' | head -1)

# NAT rules
sed -i '/^*filter/i *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 10.8.0.0/8 -o '"$INTERFACE"' -j MASQUERADE\nCOMMIT\n' /etc/ufw/before.rules
sed -i 's/^DEFAULT_FORWARD_POLICY.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
ufw disable && ufw enable

echo "==> Enabling correct OpenVPN service..."
systemctl enable openvpn-server@server
systemctl start openvpn-server@server

echo "✅ OpenVPN Server is installed and running!"

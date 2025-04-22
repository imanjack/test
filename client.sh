#!/bin/bash

set -e

read -p "Enter new client name: " CLIENT_NAME

EASYRSA_DIR=~/easy-rsa
CLIENTS_DIR=~/openvpn-clients/$CLIENT_NAME
SERVER_IP="1.2.3.4"

cd "$EASYRSA_DIR"

echo "==> Generating client key pair for $CLIENT_NAME..."
./easyrsa gen-req $CLIENT_NAME nopass
echo yes | ./easyrsa sign-req client $CLIENT_NAME

echo "==> Preparing client config directory: $CLIENTS_DIR"
mkdir -p "$CLIENTS_DIR"
cp pki/ca.crt "$CLIENTS_DIR/"
cp pki/issued/$CLIENT_NAME.crt "$CLIENTS_DIR/"
cp pki/private/$CLIENT_NAME.key "$CLIENTS_DIR/"
cp ta.key "$CLIENTS_DIR/"

echo "==> Creating .ovpn profile..."
cat > "$CLIENTS_DIR/$CLIENT_NAME.ovpn" <<EOF
client
dev tun
proto tcp
remote $SERVER_IP 443
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
tls-auth ta.key 1
cipher AES-256-CBC
verb 3

<ca>
$(cat "$CLIENTS_DIR/ca.crt")
</ca>

<cert>
$(cat "$CLIENTS_DIR/$CLIENT_NAME.crt")
</cert>

<key>
$(cat "$CLIENTS_DIR/$CLIENT_NAME.key")
</key>

<tls-auth>
$(cat "$CLIENTS_DIR/ta.key")
</tls-auth>
EOF

echo "✅ Client $CLIENT_NAME created!"
echo "📄 Config file: $CLIENTS_DIR/$CLIENT_NAME.ovpn"

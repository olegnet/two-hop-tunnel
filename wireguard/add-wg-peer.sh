#!/bin/bash
set -e

WG_CONF="/etc/wireguard/wg0.conf"
WG_SUBNET_V4="10.8.100"
SERVER_V4="10.8.100.1"
ENDPOINT="111.222.333.444:55555" # <-- change it

CLIENT_NAME="$1"
if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

LAST_V4=$(grep -Eo "$WG_SUBNET_V4\.[0-9]{1,3}" "$WG_CONF" | awk -F. '{print $4}' | sort -n | tail -n 1)
NEXT_V4=$((LAST_V4 + 1))

CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

cat <<EOF >> "$WG_CONF"

# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $WG_SUBNET_V4.$NEXT_V4/32
PersistentKeepalive = 25
EOF

CLIENT_CONF="${CLIENT_NAME}.conf"
cat <<EOF > "$CLIENT_CONF"
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $WG_SUBNET_V4.$NEXT_V4/32
DNS = ${SERVER_V4}
MTU = 1420

[Peer]
PublicKey = $(wg show wg0 public-key)
AllowedIPs = 0.0.0.0/0
Endpoint = ${ENDPOINT}
PersistentKeepalive = 25
EOF

echo "New client $CLIENT_NAME:"
echo "  IPv4: $WG_SUBNET_V4.$NEXT_V4"
echo "Client's config name $CLIENT_CONF"

#!/usr/bin/env bash
# WorkGo - Dial Karya Voice Gateway Launcher (WSL / Linux)

echo "================================================================"
echo "          WorkGo - Dial Karya Voice Gateway Launcher           "
echo "================================================================"

echo "[1/3] Ensuring Asterisk PBX is active..."
sudo systemctl start asterisk

echo "[2/3] Checking Asterisk status..."
sudo asterisk -rx "core show version"

echo "[3/3] Launching SIP Dual Bridge (UDP/TCP + Dynamic Voice RTP)..."
echo "================================================================"
echo "Connect MizuDroid to:"
echo "  Domain / Server : 192.168.1.7:5060"
echo "  Password        : workgoSecretPassword123"
echo "  Dial Extension  : 1000"
echo "================================================================"
echo ""

node backend/scripts/sip_bridge.js

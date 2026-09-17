#!/bin/bash
cat << 'EOF' >> /etc/asterisk/pjsip.conf

[anonymous]
type=endpoint
context=workgo-inbound
disallow=all
allow=ulaw,alaw
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
EOF
asterisk -rx 'pjsip reload'
echo "ANONYMOUS_ADDED"

#!/bin/bash
cat << 'EOF' >> /etc/asterisk/pjsip.conf

[workgo_26089]
type=endpoint
context=workgo-inbound
disallow=all
allow=ulaw,alaw
auth=auth-workgo
aors=workgo_26089
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

[auth-workgo]
type=auth
auth_type=userpass
password=workgoSecretPassword123
username=workgo_26089

[workgo_26089]
type=aor
max_contacts=5
remove_existing=yes
EOF
asterisk -rx 'pjsip reload'
echo "DONE"

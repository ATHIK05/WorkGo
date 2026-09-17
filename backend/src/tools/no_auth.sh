#!/bin/bash
python3 -c "
with open('/etc/asterisk/pjsip.conf', 'r') as f:
    text = f.read()

# Remove auth=auth-gateway and auth=auth-workgo
text = text.replace('auth=auth-gateway\n', '')
text = text.replace('auth=auth-workgo\n', '')

with open('/etc/asterisk/pjsip.conf', 'w') as f:
    f.write(text)

print('Auth removed successfully')
"
asterisk -rx 'pjsip reload'

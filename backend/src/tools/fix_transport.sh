#!/bin/bash
sed -i '/\[transport-udp\]/,/bind=0.0.0.0:5060/c\[transport-udp]\ntype=transport\nprotocol=udp\nbind=0.0.0.0:5060\nlocal_net=172.31.0.0/16\nlocal_net=127.0.0.0/8\nexternal_signaling_address=192.168.1.7\nexternal_media_address=192.168.1.7\nsymmetric_transport=yes' /etc/asterisk/pjsip.conf
asterisk -rx 'pjsip reload'
echo "TRANSPORT_UPDATED"

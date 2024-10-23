#!/bin/bash

modprobe br_netfilter
sysctl -p /etc/sysctl.conf
sysctl -w net.bridge.bridge-nf-call-iptables=1

/home/student/honeypot-group-1a/src/firewall_rules.sh > /home/RESULT 2>&1

# if [ $? -ne 0 ]; then
#   echo "their firewall failed" > /home/RESULT
#   exit 1
# fi

exit 0
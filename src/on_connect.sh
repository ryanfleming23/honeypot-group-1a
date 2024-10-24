#!/bin/bash

if [[ $# -ne 5 ]]; then
    echo "Usage: $0 <delay> <container name> <container IP> <public IP> <mitm port>"
    exit 1
fi

delay=$1
containerName=$2
containerIP=$3
publicIP=$4
mitmPort=$5

SCRIPT_NAME="audacity_setup.sh"

varPath="/home/student/honeypot-group-1a/var/${containerName}.txt"
logPath="/home/student/honeypot-group-1a/log/${containerName}.log"

lineregex="\[Debug\] \[Connection\] Attacker connected: (([0-9]{1,3}\.){3}[0-9]{1,3})"
connectregex="\[Debug\] \[LXC Streams\] New Stream"
disconregex="\[Debug\] \[LXC Streams\] Removed Stream"

tail -F "$logPath" | while read -r line; do
    if [[ "$line" =~ $lineregex ]]; then
        attackerIP="${BASH_REMATCH[1]}"
        echo "$attackerIP" >> "$varPath"
        sudo pkill -P $$
        break
    else 
        sleep 1
    fi
done

attackerIP=""
timeout=60
while [[ -z "$attackerIP" && $timeout -gt 0 ]]; do
    attackerIP=$(sed -n '3p' "$varPath")
    if [[ -z "$attackerIP" ]]; then
        sleep 0.25
        timeout=$((timeout - 1))
    fi
done

if [[ $timeout -eq 0 ]]; then
    exit 1
fi

sudo iptables --insert INPUT -d 127.0.0.1 -p tcp --dport "$mitmPort" --jump DROP
if [[ $delay -ne 0 ]]; then
    if [[ -n "$attackerIP" ]]; then
        pingtime="$(ping -c 1 $attackerIP | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' | awk '{ if ($1 != "") printf "%.3f\n", $1/1000 }')"
    fi
    adjustedDelay=""
    if [[ -n $pingtime ]]; then
        adjustedDelay=$(echo "scale=3; $delay - $pingtime" | bc)
        if (( $(echo "$adjustedDelay < 0" | bc -l) )); then
            adjustedDelay=0
        fi
        sleepTime=$(echo "scale=3; $adjustedDelay / 1000" | bc)
    else
        adjustedDelay=$delay
    fi
    
    sudo touch /var/lib/lxc/$containerName/rootfs/etc/profile.d/$SCRIPT_NAME
    echo "trap '(history 1 | grep -q \"\$BASH_COMMAND\" > /dev/null 2>&1) && sleep "$adjustedDelay"' DEBUG" | sudo tee -a /var/lib/lxc/$containerName/rootfs/etc/profile.d/$SCRIPT_NAME > /dev/null 2>&1
    echo "shopt -u expand_aliases" | sudo tee -a /var/lib/lxc/$containerName/rootfs/etc/profile.d/$SCRIPT_NAME > /dev/null 2>&1
fi
sudo iptables --insert INPUT -s "$attackerIP" -d 127.0.0.1 -p tcp --dport "$mitmPort" --jump ACCEPT
exit 0

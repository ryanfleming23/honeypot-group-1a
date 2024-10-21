#!/bin/bash

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <delay> <container name> <container IP>"
    exit 1
fi

delay=$1
adjustedDelay=$delay
containerName=$2
containerIP=$3

varPath="/home/student/honeypot-group-1a/var/${containerName}.txt"
logPath="/home/student/honeypot-group-1a/log/${containerName}.log"

regex="\[Debug\] \[Connection\] Attacker connected: (([0-9]{1,3}\.){3}[0-9]{1,3})"

if [[ $delay -ne 0 ]]; then
    tail -F $logPath | while read -r line; do
        if [[ "$line" =~ $regex ]]; then
            echo $line | sudo tee -a /home/student/honeypot-group-1a/log/help.txt
            attackerIP="${BASH_REMATCH[1]}"
            if [[ -n "$attackerIP" ]]; then
                pingtime=$(ping -c 10 $attackerIP | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}' | awk '{sum+=$1} END {printf "%.3f\n", sum/(NR * 1000)}')
                echo $pingtime | sudo tee -a /home/student/honeypot-group-1a/log/help.txt
                if [ -n $pingtime ]; then
                    adjustedDelay=$(echo "scale=3; $delay - $pingtime" | bc)
                    echo $adjustedDelay | sudo tee -a /home/student/honeypot-group-1a/log/help.txt
                fi
            fi
            echo "trap 'sleep "$adjustedDelay"' DEBUG" | sudo tee -a /var/lib/lxc/$containerName/rootfs/etc/bash.bashrc
        fi
    done
fi
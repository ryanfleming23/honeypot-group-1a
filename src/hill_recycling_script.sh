#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: hw8script <minutes>"
    exit 1
fi
minutes=$1
if [[ -f "timer" ]]; then
    container=$(head -n 1 cont_name)
    start_time=$(head -n 1 timer)
    cont_min=$(tail -n 1 timer)
    curr_time=$(date +%s)
    elapsed_secs=$((curr_time - start_time))
    elapsed=$((elapsed_secs / 60))
    if [[ $elapsed -ge $cont_min ]]; then
        contIP=$(sudo lxc-info -n "$container" -iH)
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --
        destination 172.30.250.144 --jump DNAT --to-destination "$contIP"
        sudo iptables --table nat --delete POSTROUTING --source "$contIP" --
        destination 0.0.0.0/0 --jump SNAT --to-source 172.30.250.144
        sudo ip addr delete 172.30.250.144/16 brd + dev eth0
        echo "container $container stopped at $(date +"%Y-%m-%d %T")"
        rm timer
        rm cont_name
        exit 0
    else
        echo "container $container not ready to be recycled"
        exit 0
    fi
else
    container=$(shuf -e -n 1 container1 container2 container3)
    echo "container $container started at $(date +"%Y-%m-%d %T")"
    echo "$container" >>cont_name
    date +%s >>timer
    echo "$minutes" >>timer
    sudo ip addr add 172.30.250.144/16 brd + dev eth0
    contIP=$(sudo lxc-info -n "$container" -iH)
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --
    destination 172.30.250.144 --jump DNAT --to-destination "$contIP"
    sudo iptables --table nat --insert POSTROUTING --source "$contIP" --
    destination 0.0.0.0/0 --jump SNAT --to-source 172.30.250.144
    exit 0
fi
exit 0

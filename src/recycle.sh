#!/bin/bash

if [ $# -ne 0 ]; then
    echo "Usage: "$0" (no arguments required)";
    exit 1
fi

MITM_PATH="/home/student/MITM/mitm.js"
LOG_PATH="/home/student/honeypot-group-1a/log/"
VAR_PATH="/home/student/honeypot-group-1a/var/"

RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

MAX_MIN=30
IDLE_MIN=4

declare -A CONTAINERS;
CONTAINERS["c1"]="172.30.250.112"; # Ryan Internal IP
CONTAINERS["c2"]="172.30.250.144"; # Andrew Internal IP
CONTAINERS["c3"]="172.30.250.108"; # Jacob Internal IP

create_container () {
    name=$1
    public_ip=$2
    count=$3
    port=$((count + 9804))

    echo -e "${GREEN}Creating New Container \"$name\"...${RESET}"
    sudo lxc-create -n "$name" -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n "$name"

    ip=""
    timeout=60
    while [[ -z "$ip" && $timeout -gt 0 ]]; do
        ip=$(sudo lxc-info -iH "$name")
        sleep 0.25
        ((timeout--))
    done

    if [[ -z "$ip" ]]; then
        echo "ERROR: Failed to obtain IP address for container \"$name\"."
        exit 1
    fi

    sudo ip addr add "$public_ip"/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --jump DNAT --to-destination "$ip"
    sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"

    sudo lxc-attach -n "$name" -e -- sudo apt-get --assume-yes install openssh-server

    # Has to work with three IPs
    if sudo forever list | grep -q "$name"; then
        sudo forever stop "$name"
    fi
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1

    # TODO real log storage and data processing system (this is temporary)
    if [[ -f "$LOG_PATH""$name".log ]]; then
        echo "Saving old log file to \""$name_"$(date +%Y-%m-%dT%H:%M:%S%z).log\"..."
        mv "$LOG_PATH""$name".log "$LOG_PATH""$name"_"$(date +%Y-%m-%dT%H:%M:%S%z)".log
        rm -f "$LOG_PATH""$name".log
    fi

    sudo forever --id "$name" -l "$LOG_PATH""$name".log start "$MITM_PATH" -n "$name" -i "$ip" -p "$port" --auto-access --auto-access-fixed 3 --debug
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"

    date +%s >> "$VAR_PATH""$name".txt

    echo -e "${GREEN}Created Container \"$name\".${RESET}"
}

destroy_container () {
    name=$1
    public_ip=$2
    count=$3
    port=$((count + 9804))

    ip=$(sudo lxc-info -iH "$name")

    if [[ "$ip" = "" ]]; then
        echo "ERROR: Container Does Not Exist"
        exit 1
    fi

    echo -e "${RED}Removing Container \"$name\"...${RESET}"

    sudo iptables -w --table nat --delete POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"
    sudo iptables -w --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --jump DNAT --to-destination "$ip" 
    sudo ip addr delete "$public_ip"/16 brd + dev eth0 

    sudo iptables -w --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"
    sudo forever stop "$name"

    sudo lxc-stop -n "$name"
    sudo lxc-destroy -n "$name"

    echo "Saving old log file to \""$name_"$(date +%Y-%m-%dT%H:%M:%S%z).log\"..."
    mv "$LOG_PATH""$name".log "$LOG_PATH""$name"_"$(date +%Y-%m-%dT%H:%M:%S%z)".log
    rm -f "$LOG_PATH""$name".log

    echo -e "${RED}Removed Container \"$name\".${RESET}"
}

containers=$(sudo lxc-ls -f)

pids=()
count=0
for container_name in "${!CONTAINERS[@]}"; do
    if [[ "$containers" = *"$container_name"* ]]; then
        ( destroy_container "$container_name" "${CONTAINERS[$container_name]}" $count) &
    else
        ( create_container "$container_name" "${CONTAINERS[$container_name]}" $count) &
    fi
    pids+=($!)
    ((count++))
done 

for pid in "${pids[@]}"; do
    wait $pid
    if [ $? -ne 0 ]; then
        echo "ERROR: A background process failed (PID $pid)"
    else
        echo "Background process $pid finished successfully."
    fi
done
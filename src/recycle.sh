#!/bin/bash

if [ $# -gt 1 ]; then
    echo "Usage: "$0" (-d optional)";
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
DELAYS=(0 1 2 5 10 30)

declare -A CONTAINERS;
CONTAINERS["DESKTOP-1AJRJA"]="128.8.238.194";
CONTAINERS["DESKTOP-2AJRJA"]="128.8.238.101";
CONTAINERS["DESKTOP-3AJRJA"]="128.8.238.173";
CONTAINERS["DESKTOP-4AJRJA"]="128.8.238.212";
CONTAINERS["DESKTOP-5AJRJA"]="128.8.238.206";
CONTAINERS["DESKTOP-6AJRJA"]="128.8.238.209";

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
        if [[ -z "$ip" ]]; then
            sleep 0.25
            ((timeout--))
        fi
    done

    if [[ -z "$ip" ]]; then
        echo "ERROR: Failed to obtain IP address for container \"$name\"."
        exit 1
    fi

    sudo lxc-attach -n "$name" -- sudo apt-get install ssh -y

    sudo ip link set dev eth3 up
    sudo ip addr add "$public_ip"/24 brd + dev eth3

    sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --jump DNAT --to-destination "$ip"

    # Has to work with IPs
    if sudo forever list | grep -q "$name"; then
        sudo forever stop "$name"
    fi
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1

    if [[ -f "$LOG_PATH""$name".log ]]; then
        /home/student/honeypot-group-1a/.venv/bin/python /home/student/honeypot-group-1a/src/logparse.py $name
    fi

    sudo forever --id "$name" -l "$LOG_PATH""$name".log start "$MITM_PATH" -n "$name" -i "$ip" -p "$port" --auto-access --auto-access-fixed 3 --debug
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"

    date +%s > "$VAR_PATH""$name".txt

    # Prelimary Honey Copying (Not the Focus)
    /home/student/honeypot-group-1a/src/honey.sh $name

    delay=$(printf "%s\n" "${DELAYS[@]}" | shuf -n 1)
    echo $delay >> "$VAR_PATH""$name".txt
    
    /home/student/honeypot-group-1a/src/on_connect.sh $delay $name $ip $public_ip $port &
    echo $! >> "$VAR_PATH""$name".txt

    echo -e "${GREEN}Created Container \"$name\".${RESET}"
}

destroy_container () {
    name=$1
    public_ip=$2
    count=$3
    port=$((count + 9804))

    var_file="$VAR_PATH$name.txt"

    if ! sudo lxc-ls | grep -q "$name"; then
        echo "ERROR: Container Name Not Found"
        exit 1
    fi

    sudo iptables -w --delete INPUT -d 127.0.0.1 -p tcp --dport "$port" --jump DROP
    sudo iptables -w --delete INPUT -s $(sed -n '4p' "$var_file") -d 127.0.0.1 -p tcp --dport "$port" --jump ACCEPT

    echo -e "${RED}Removing Container \"$name\"...${RESET}"

    sudo iptables -w --delete INPUT --source 0.0.0.0/0 --destination 127.0.0.1 --jump DROP

    sudo ip addr delete "$public_ip"/24 brd + dev eth3 

    sudo iptables -w --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"

    ip=$(sudo lxc-info -iH "$name")
    if [[ "$ip" != "" ]]; then
        sudo iptables -w --table nat --delete POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"
        sudo iptables -w --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --jump DNAT --to-destination "$ip" 
    fi

    sudo pkill $(sed -n '3p' "$var_file")
    sudo pkill -P $(sed -n '3p' "$var_file")

    sudo forever stop "$name"

    sudo lxc-stop -n "$name"
    sudo lxc-destroy -n "$name"

    /home/student/honeypot-group-1a/.venv/bin/python /home/student/honeypot-group-1a/src/logparse.py $name
    
    echo -e "${RED}Removed Container \"$name\".${RESET}"
}

doCreate=true

while getopts ":d" option; do
    case $option in
        d) # Delete
            doCreate=false;;
        \?) # Invalid
            exit;;
    esac
done

pids=()
count=0
for name in "${!CONTAINERS[@]}"; do
    if [ "$doCreate" = false ]; then
        ( destroy_container "$name" "${CONTAINERS[$name]}" $count)
    else
        if sudo lxc-ls | grep -q "$name"; then
            keep_running=true

            log_file="$LOG_PATH$name.log"
            var_file="$VAR_PATH$name.txt"

            # if grep -q "{\"level\":\"error\",\"message\"" "$log_file"; then
            #     echo -e "${RED}ERROR in creating container \"$name\".${RESET}"
            #     keep_running=false
            # fi
            if grep -q "Attacker connected:" "$log_file"; then
                if grep -q "Attacker ended the shell" "$log_file"; then
                    echo -e "${RED}Attacker Closed Connection in \"$name\".${RESET}"
                    keep_running=false
                elif (( $(date +%s) - $(stat -c %Y "$log_file") > IDLE_MIN * 60 )); then
                    echo -e "${RED}Attacker Went Idle in \"$name\".${RESET}"
                    keep_running=false
                fi
            fi
            if (( $(date +%s) - $(sed -n '1p' "$var_file") > MAX_MIN * 60 )); then
                echo -e "${RED}Container Reached Maximum Time in \"$name\".${RESET}"
                keep_running=false
            fi
            if [ "$keep_running" = false ]; then
                destroy_container "$name" "${CONTAINERS[$name]}" $count 
                ( create_container "$name" "${CONTAINERS[$name]}" $count) &
                pids+=($!)
            else
                echo -e "${GREEN}Keeping Container \"$name\".${RESET}"
            fi
        else
            ( create_container "$name" "${CONTAINERS[$name]}" $count) &
            pids+=($!)
        fi
    fi
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
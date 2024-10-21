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
        if [[ -z "$ip" ]]; then
            sleep 0.25
            ((timeout--))
        fi
    done

    if [[ -z "$ip" ]]; then
        echo "ERROR: Failed to obtain IP address for container \"$name\"."
        exit 1
    fi

    sudo ip addr add "$public_ip"/24 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --jump DNAT --to-destination "$ip"
    sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"

    sudo lxc-attach -n "$name" -e -- sudo apt-get --assume-yes install openssh-server

    # Has to work with three IPs
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
    # sudo cp -r /home/student/honeypot-group-1a/honey.zip /var/lib/lxc/$name/rootfs/home/ubuntu/honey.zip
    /home/student/honeypot-group-1a/src/honey.sh $name

    delay=$(printf "%s\n" "${DELAYS[@]}" | shuf -n 1)
    
    /home/student/honeypot-group-1a/src/on_connect.sh $delay $name $ip &
    # if [ $delay -ne 0 ]; then
    #     echo "trap 'sleep "$delay"' DEBUG" | sudo tee -a /var/lib/lxc/$name/rootfs/etc/bash.bashrc
    # fi

    echo $delay >> "$VAR_PATH""$name".txt

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

    sudo iptables --delete INPUT --protocol tcp --source 0.0.0.0/0 --destination "$public_ip" --dport 22 --match connlimit --connlimit-above 1 --jump REJECT

    sudo ip addr delete "$public_ip"/24 brd + dev eth0 

    sudo iptables -w --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$public_ip" --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"

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

containers=$(sudo lxc-ls -f)

pids=()
count=0
for name in "${!CONTAINERS[@]}"; do
    if [ "$doCreate" = false ]; then
        ( destroy_container "$name" "${CONTAINERS[$name]}" $count)
    else
        if [[ "$containers" = *"$name"* ]]; then
            keep_running=true

            log_file="$LOG_PATH$name.log"
            var_file="$VAR_PATH$name.txt"

        if grep -q "Attacker authenticated and is inside container" "$log_file"; then
            if grep -q "Attacker closed connection" "$log_file"; then
                echo -e "${RED}Attacker Closed Connection in \"$name\".${RESET}"
                keep_running=false
            elif (( $(date +%s) - $(stat -c %Y "$log_file") > IDLE_MIN * 60 )); then
                echo -e "${RED}Attacker Went Idle in \"$name\".${RESET}"
                keep_running=false
            fi
        fi
        if (( $(date +%s) - $(head -n 1 "$var_file") > MAX_MIN * 60 )); then
            echo -e "${RED}Container Reached Maximum Time in \"$name\".${RESET}"
            keep_running=false
        fi
        if [ "$keep_running" = false ]; then
            ( destroy_container "$name" "${CONTAINERS[$name]}" $count)
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

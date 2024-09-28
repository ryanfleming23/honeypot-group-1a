#!/bin/bash

create_container () {
    name=$1
    public_ip=$2
    count=$3
    port=$((count + 9804))

    echo "Creating New Container \"$name\"..."
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
        echo "ERROR: Failed to obtain IP address for container \"$container\"."
        exit 1
    fi

    echo "Configuring IP Mapping on $ip..."
    sudo ip addr add $public_ip/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $public_ip --jump DNAT --to-destination "$ip"
    sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"

    echo "Installing SSH server inside \"$name\"..."
    sudo lxc-attach -n "$name" -e -- sudo apt-get --assume-yes install openssh-server

    echo "Configuring MITM server inside \"$name\"..."
    # Has to work with three IPs
    if sudo forever list | grep -q "$name"; then
        sudo forever stop $name
    fi
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1
    if [[ -f /home/student/honeypot-group-1a/log/$name.log ]]; then
        echo "Saving Log file to \"$name_$(date +%Y-%m-%dT%H:%M:%S%z).log\"..."
        mv /home/student/honeypot-group-1a/log/"$name".log /home/student/honeypot-group-1a/log/"$name"_"$(date +%Y-%m-%dT%H:%M:%S%z)".log
        rm -f /home/student/honeypot-group-1a/log/"$name".log
    fi

    
    sudo forever --id $name -l /home/student/honeypot-group-1a/log/"$name".log start /home/student/MITM/mitm.js -n "$name" -i "$ip" -p $port --auto-access --auto-access-fixed 3 --debug
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $public_ip --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"
}

destroy_container () {
    name=$1
    public_ip=$2

    ip=$(sudo lxc-info -iH $name)

    if [[ $ip = "" ]]; then
        echo "ERROR: Container Does Not Exist"
        exit 1
    fi

    echo "Removing NAT rules..."
    sudo iptables --table nat --delete POSTROUTING --source $ip --destination 0.0.0.0/0 --jump SNAT --to-source $public_ip 
    sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination $public_ip --jump DNAT --to-destination $ip 
    sudo ip addr delete $public_ip/16 brd + dev eth0 

    echo "Removing MITM server configuration..."
    sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination $public_ip --protocol tcp --dport 22 --jump DNAT --to-destination "127.0.0.1:$port"
    sudo forever stop $name

    echo "Removing container..."
    sudo lxc-stop -n "$name"
    sudo lxc-destroy -n "$name"

    echo "Container removed."
}

if [ $# -ne 0 ]; then
    echo "Usage: $0";
    exit 1
fi

# Define dictionary with container names and public IP addresses
declare -A container_pub_ips;
container_pub_ips["c1"]="172.30.250.112"; # Ryan Internal IP
container_pub_ips["c2"]="172.30.250.144"; # Andrew Internal IP
container_pub_ips["c3"]="172.30.250.108"; # Jacob Internal IP

containers=$(sudo lxc-ls -f)

pids=()
count=0
for container_name in "${!container_pub_ips[@]}"; do
    if [[ $containers = *"$container_name"* ]]; then
        ( destroy_container "$container_name" "${container_pub_ips[$container_name]}" ) &
    else
        ( create_container "$container_name" "${container_pub_ips[$container_name]}" $count) &
        ((count++))
    fi
    pids+=($!)
done 

for pid in "${pids[@]}"; do
    wait $pid
    if [ $? -ne 0 ]; then
        echo "ERROR: A background process failed (PID $pid)"
    else
        echo "Background process $pid finished successfully."
    fi
done
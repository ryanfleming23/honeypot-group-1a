#!/bin/bash

if [ $# -ne 0 ]; then
    echo "Usage: $0";
fi

# Define dictionary with container names and public IP addresses
declare -A container_ips;
container_ips["c1"]="172.30.250.112"; # ACES Internal IP Address
# container_ips["c2"]="";
# container_ips["c3"]="";

for container_name in "${!container_ips[@]}"; do
    echo "$container_name: ${container_ips[$container_name]}";
done
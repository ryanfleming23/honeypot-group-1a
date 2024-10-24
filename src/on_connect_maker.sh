#!/bin/bash

declare -A CONTAINERS;
# CONTAINERS["DESKTOP-1AJRJA"]="128.8.238.194";
# CONTAINERS["DESKTOP-2AJRJA"]="128.8.238.101";
# CONTAINERS["DESKTOP-3AJRJA"]="128.8.238.173";
CONTAINERS["DESKTOP-4AJRJA"]="128.8.238.212";
CONTAINERS["DESKTOP-5AJRJA"]="128.8.238.206";
# CONTAINERS["DESKTOP-6AJRJA"]="128.8.238.209";

mkdir -p /home/student/honeypot-group-1a/src/on_connect
if [ "$(ls -A ./on_connect)" ]; then
    rm -f /home/student/honeypot-group-1a/src/on_connect/*
fi

for i in {4..5}
do
    cp /home/student/honeypot-group-1a/src/on_connect.sh /home/student/honeypot-group-1a/src/on_connect/on_connect_"$i".sh
    sudo chmod 777 /home/student/honeypot-group-1a/src/on_connect/on_connect_"$i".sh
done
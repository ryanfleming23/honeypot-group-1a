#!/bin/bash

if [ $# -gt 2 ]
then
   echo "Usage: $0 container_name"
   exit 1
fi

cont_name=$1
zip_path=/home/student/honeypot-group-1a/honey/hbooth.zip

sudo lxc file push "$zip_path" "$cont_name"/root/home
sudo lxc-attach -n "$cont_name" -- sudo apt install unzip
sudo lxc-attach -n "$cont_name" -- unzip /root/home/hbooth.zip -d /root/home
sudo lxc_attach -n "$cont_name" -- rm /root/home/hbooth.zip

exit 0


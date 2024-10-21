#!/bin/bash

if [ $# -gt 2 ]
then
   echo "Usage: $0 container_name"
   exit 1
fi

cont_name=$1
zip_path=/home/student/honeypot-group-1a/honey/hbooth.zip

sudo unzip "$zip_path" -d /var/lib/lxc/"$cont_name"/rootfs/home
sudo lxc-attach -n "$cont_name" -- sudo useradd -d /home/hbooth hbooth
sudo lxc-attach -n "$cont_name" -- sudo cp -r /home/ubuntu/* /home/hbooth

exit 0


#!/bin/bash

if [ $# -ne 1 ]
then
   echo "Usage: $0 [Container Name]"
   exit 1
fi

container=$1
public_ip=172.30.250.112

containers=$(sudo lxc-ls -f)

if [[ $containers = *"$container"* ]]
then
   echo "WARNING: Container already exists!"
   echo "  1. Delete and Continue Execution"
   echo "  2. End Execution"
   read -r selection
   if [[ $selection = "2" ]]
   then
      echo "Ending Execution"
      exit 2
   elif [[ $selection = "1" ]]
   then
      echo "Deleting Container..."
      /home/student/HACS101/honeypot/destroy_honeypot.sh "$container"
   else
      echo "ERROR: Invalid Response"
      exit 3
   fi
fi

echo "Creating New Container \"$container\"..."
sudo lxc-create -n "$container" -t download -- -d ubuntu -r focal -a amd64 > /dev/null
sudo lxc-start -n "$container" > /dev/null

ip=""
while [[ $ip = "" ]]
do
   ip=$(sudo lxc-info -iH "$container")
done

echo "Configuring IP Mapping on $ip..."
sudo ip addr add $public_ip/16 brd + dev eth0
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $public_ip --jump DNAT --to-destination "$ip"
sudo iptables --table nat --insert POSTROUTING --source "$ip" --destination 0.0.0.0/0 --jump SNAT --to-source "$public_ip"

echo "Installing SSH server inside \"$container\"..."
sudo lxc-attach -n "$container" -e -- sudo apt-get --assume-yes install openssh-server > /dev/null

echo "Configuring MITM server inside \"$container\"..."
sudo forever stopall > /dev/null 2>&1
sudo sysctl -w net.ipv4.conf.all.route_localnet=1 > /dev/null 2>&1

if [[ -f /home/student/HACS101/mitm_logs/$1.log ]]
then
   echo "WARNING: Log file already exists!"
   echo "   1. Delete Log File"
   echo "   2. Save Log File"
   read -r selection
   if [[ $selection = "2" ]]
   then
      echo "Saving Log file to \"$1_$(date +%Y-%m-%dT%H:%M:%S%z).log\"..."
      mv /home/student/HACS101/mitm_logs/"$1".log /home/student/HACS101/mitm_logs/"$1"_"$(date +%Y-%m-%dT%H:%M:%S%z)".log
      rm -f /home/student/HACS101/mitm_logs/"$1".log
   elif [[ $selection = "1" ]]
   then
      echo "Removing Log File $1.log..."
      rm -f /home/student/HACS101/mitm_logs/"$1".log
   else
      echo "ERROR: Invalid Response (Resetting Honeypot)"
      /home/student/HACS101/honeypot/destroy_honepot.sh
   fi
fi

sudo forever -l /home/student/HACS101/mitm_logs/"$1".log start /home/student/MITM/mitm.js -n "$1" -i" $ip" -p 9804 --auto-access --auto-access-fixed 2 --debug > /dev/null 2>&1
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $public_ip --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:9804 > /dev/null

echo "Creating Honey inside \"$container\"..."
sudo cp -r /home/student/HACS101/honeypot/create_honey.sh /var/lib/lxc/"$container"/rootfs/home/ubuntu/create_honey.sh
sudo cp -r /home/student/HACS101/honeypot/create_honey /var/lib/lxc/"$container"/rootfs/home/ubuntu/create_honey
sudo cp -r /home/student/HACS101/honeypot/names.txt /var/lib/lxc/"$container"/rootfs/home/ubuntu/names.txt
sudo lxc-attach -n "$container" -- chmod 777 /home/ubuntu/create_honey.sh
sudo lxc-attach -n "$container" -- bash -c "cd /home/ubuntu && ./create_honey.sh" > /dev/null
sudo lxc-attach -n "$container" -- rm -f /home/ubuntu/create_honey.sh
sudo lxc-attach -n "$container" -- rm -f /home/ubuntu/create_honey
sudo lxc-attach -n "$container" -- rm -f /home/ubuntu/names.txt

echo "Honeypot created successfully."

exit 0

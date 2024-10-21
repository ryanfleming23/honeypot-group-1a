#!/bin/bash

sudo ip route add default via 172.30.0.1 table c1
sudo ip route add default via 172.30.0.1 table c2
sudo ip route add default via 172.30.0.1 table c3
sudo ip route add default via 172.30.0.1 table c4
sudo ip route add default via 172.30.0.1 table c5

exit 0

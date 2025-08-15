#! /bin/bash
## get interface name (ovs_eth0 below) via ip link. Currenly ovs_bond0 as Virtual Machine is installed and bond used
ip link add macvlan0 link ovs_bond0 type macvlan mode bridge
# Set address of the host to 192.168.1.48/32
ip addr add 192.168.1.48/32 dev macvlan0
# Up internface
ip link set macvlan0 up
# Add the route for range 192.168.1.48/28
ip route add 192.168.1.48/28 dev macvlan0

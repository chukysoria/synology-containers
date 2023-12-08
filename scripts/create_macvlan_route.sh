#! /bin/bash
# Configure to execute after Synology reboot
# get interface name (ovs_eth0 below) via ip link. Currenly ovs_nomd0 as Virtual Machine is installed and bond used
ip link add macvlan0 link ovs_bond0 type macvlan mode bridge
# Set address of the host to 192.168.1.48 within he macvlan network of ip range 192.168.1.48/28
ip addr add 192.168.1.48/28 dev macvlan0
# Up internface
ip link set macvlan0 up

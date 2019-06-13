#!/bin/bash

CNI_CONTAINERID=b55249rct
CNI_IFNAME=eth0
CNI_COMMAND=ADD
CNI_NETNS=/proc/6137/ns/net

case $CNI_COMMAND in 
ADD) 
  # 1. set up the bridge
  # ====================

  # get the pod cidr
  podcidr=$(cat /dev/stdin | jq -r ".podcidr") # 10.240.0.0/24
  podcidr_gw=$(echo $podcidr | sed "s:0/24:1:g") # 10.240.0.1

  # create a new bridge, if not exists on the node
  brctl addbr cni0
  ip link set cni0 up
  # assign 10.240.0.1/24 to cni0 bridge
  ip addr add "${podcidr_gw}/24" dev cni0

  # 2. create veth pair
  # ===================

  # calc a rand name for the device on the host
  host_ifname="veth$n" # n=1,2,3,4"
  # one end is CNI_IFNAME, other end is host device, create pair
  # eth0 is still in host network ns
  ip link add $CNI_IFNAME type veth peer name $host_ifname
  # enable
  ip link set $host_ifname up

  # 3. create network namespace and attach
  # ======================================

  # connect veth1 to bridge
  ip link set $host_ifname master cni0

  # create a sym link to the network ns
  ln -sfT $CNI_NETNS /var/run/netns/$CNI_CONTAINERID

  # set veth pair's container end to the network namespace
  # after this eth0 will be in pod network ns
  ip link set $CNI_IFNAME netns $CNI_CONTAINERID 

 
  # TODO: calculate an IP address, DHCP, increment, local address etc
 
  # 4. Apply the IP address
  # =======================

  # bring eth0 up
  ip netns exec $CNI_CONTAINERID ip link set $CNI_IFNAME up
  
  # apply IP address to eth0
  ip netns exec $CNI_CONTAINERID ip addr add $ip/24 dev $CNI_IFNAME

  # add podcidr GW as the default route 
  ip netns exec $CNI_CONTAINERID ip route add default via $podcidr_gw dev $CNI_IFNAME
;;


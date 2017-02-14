########################
#                      #
# /usr/sbin/routing.sh #
#                      #
########################

#!/bin/bash
# Reconfigure this, based on specific instance.
WAN=eth0
BRIDGE=br0

function test_firewall() {
  iptables -L | grep ssh
  if [ $? -ne 0 ] ; then
    echo "No ssh"
    return -1
  fi
  return 0
}

function test_network() {
  ping -w 3 -c 1 www.kernel.org
  if [ $? -ne 0 ] ; then
    echo "No ping"
    return -2
  fi
  return 0
}

function firewall_teardown() {
  iptables -F
  iptables -X
  iptables -t nat -F
  iptables -t nat -X
  iptables -t mangle -F
  iptables -t mangle -X
  iptables -t raw -F
  iptables -t raw -X
}

function firewall_setup() {
  ####################### FORWARDING #####################
  # Enable IP forwarding
  echo 1 > /proc/sys/net/ipv4/ip_forward

  # Allow forwarding of traffic LAN -> WAN
  iptables -A FORWARD -i ${BRIDGE} -o ${WAN} -j ACCEPT

  # Allow traffic WAN -> LAN but only as reply to communication initiated from the LAN
  iptables -A FORWARD -i ${WAN} -o ${BRIDGE} -m state --state RELATED,ESTABLISHED -j ACCEPT

  # Drop anything else
  iptables -A FORWARD -j DROP

  ####################### MASQUERADING ########################

  # Do the nat
  iptables -t nat -A POSTROUTING -o ${WAN} -j MASQUERADE


  ###################### INPUT #############################
  # Allow local connections
  iptables -A INPUT -i lo -j ACCEPT

  iptables -A INPUT -i ${BRIDGE} -j ACCEPT
  iptables -A INPUT -p tcp --dport 22 -i ${WAN} -j ACCEPT
  iptables -A INPUT -i ${WAN} -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -j DROP


  ###################### OUTPUT #############################
  iptables -A OUTPUT -j ACCEPT
}

function wan_reconnect() {
  ifdown eth0
  sleep 3
  ifup eth0
}

function wan_randomize_ip() {
  ifdown eth0
  ifconfig eth0 hw ether `hexdump -n6 -e '/1 ":%02X"' /dev/random|sed s/^://g`
  ifup eth0
}


set -x
UPTIME=`cat /proc/uptime | cut -d . -f 1`
if [ $UPTIME -lt 120 ] ; then
  wan_randomize_ip
fi

test_network
if [ $? -ne 0 ] ; then
  wan_reconnect
fi

test_firewall
if [ $? -ne 0 ] ; then
  echo `date` >>  /root/log.txt
  firewall_teardown
  firewall_setup
fi


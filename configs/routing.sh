#!/bin/bash
# Reconfigure this, based on specific instance.
WAN=eth0
BRIDGE=br0
LOGFILE=/root/log.txt
PING_URLS="google.fi google.com amazon.com"
KNOCK_PORT_1=1
KNOCK_PORT_2=2
KNOCK_PORT_3=3

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White


#LOGFILE=/dev/null

# set verbose level to info
__VERBOSE=5

declare -A LOG_LEVELS
# https://en.wikipedia.org/wiki/Syslog#Severity_level
LOG_LEVELS=([0]="emerg"${Color_Off} [1]="alert"${Color_Off} [2]="crit"${Color_Off} [3]="err"${Color_Off} [4]="warning"${Color_Off} [5]=${BGreen}"notice"${Color_Off} [6]=${Yellow}"info"${Color_Off} [7]=${Yellow}"debug"${Color_Off})

function log() {
  local LEVEL=${1}
  local MESSAGE=${2}
  shift
  if [ ${__VERBOSE} -ge ${LEVEL} ]; then
    echo -e `date` "[${LOG_LEVELS[$LEVEL]}]" ${MESSAGE} >> ${LOGFILE}
  fi
}

function test_firewall() {
  log 6 "test firewall"
  iptables -L | grep ${KNOCK_PORT_1}
  if [ $? -ne 0 ] ; then
    log 3 "No knock"
    return -1
  fi
  return 0
}

function ping_test() {
  for url in $PING_URLS ; do
    ping -w 2 -c 1 $url
    if [ $? -eq 0 ] ; then
      return 0
    fi
  done
  return -1
}

function test_network() {
  log 6 "test network"
  ping_test
  if [ $? -ne 0 ] ; then
    log 4 "No ping, retrying"
    sleep 5
    ping_test
    if [ $? -ne 0 ] ; then
      log 3 "No ping, failing"
      return -2
    fi
  fi
  return 0
}

function firewall_teardown() {
  log 6 "firewall teardown"
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
  log 6 "firewall setup"
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
  iptables -A INPUT -i ${WAN} -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -i ${WAN} -p tcp --dport ${KNOCK_PORT_1} -j ACCEPT
  iptables -A INPUT -i ${WAN} -p udp --dport ${KNOCK_PORT_1} -j ACCEPT
  iptables -A INPUT -i ${WAN} -p tcp --dport ${KNOCK_PORT_2} -j ACCEPT
  iptables -A INPUT -i ${WAN} -p udp --dport ${KNOCK_PORT_2} -j ACCEPT
  iptables -A INPUT -i ${WAN} -p tcp --dport ${KNOCK_PORT_3} -j ACCEPT
  iptables -A INPUT -i ${WAN} -p udp --dport ${KNOCK_PORT_3} -j ACCEPT
# Do not enable ssh: knockd will turn it on when needed
#  iptables -A INPUT -p tcp --dport 22 -i ${WAN} -j ACCEPT
  iptables -A INPUT -j DROP

  ###################### OUTPUT #############################
  iptables -A OUTPUT -j ACCEPT
}

function wan_reconnect() {
  log 6 "wan reconnect"
  ifdown eth0
  sleep 3
  ifup eth0
}

function wan_randomize_ip() {
  log "randomize ip"
  ifdown eth0
  ifconfig eth0 hw ether `hexdump -n6 -e '/1 ":%02X"' /dev/random|sed s/^://g`
  ifup eth0
}

function normal_test() {
# Try to get a new IP on boot
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
    log 5 "reset wan and firewall"
    firewall_teardown
    firewall_setup
    systemctl restart knockd
  fi
}


##set -x

# Default to normal test
if [ -z ${action+x} ]; then
  action="normal"
fi

if [ "$action" = "normal" ]; then
  log 6 "Normal test"
  normal_test
elif [ "$action" = "randomize" ]; then
  log 6 "randomize"
  wan_randomize_ip
elif [ "$action" = "firewall" ]; then
  log 6 "firewall"
  firewall_teardown
  firewall_setup
elif [ "$action" = "knockd" ]; then
  log 6 "knockd"
  systemctl restart knockd
fi

                                 

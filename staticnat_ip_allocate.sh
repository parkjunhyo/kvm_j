#! /usr/bin/env bash

## accept the enviornment file
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Check the Variable to create VM machine
if [[ $# -ne 2 ]]
then
 echo "$0 [public ip] [private ip]"
 exit
fi

## Bridge Information to ADD public information
BREXT=${BREXT:='ovsbr_ext'}
BRINT=${BRINT:='ovsbr_int'}

## Check the IP address Formation
FORM_STATUS=$(echo $1 | awk -F"[/]" '{print $1}' | awk -F"[.]" '{if(NF==4){for(i=1; i<=NF; i++){if($i!~/[[:digit:]]+/){print "false"}}}else{print "false"}}')
if [[ $FORM_STATUS = "false" ]]
then
 echo "wrong ip address $1 format, please confirm it is correct!"
 exit
fi
FORM_STATUS=$(echo $2 | awk -F"[/]" '{print $1}' | awk -F"[.]" '{if(NF==4){for(i=1; i<=NF; i++){if($i!~/[[:digit:]]+/){print "false"}}}else{print "false"}}')
if [[ $FORM_STATUS = "false" ]]
then
 echo "wrong ip address $2 format, please confirm it is correct!"
 exit
fi

## Check the Public IP address usage
## In this process, the public ip address will be setted with 32bit host subnet
PUBIP=`echo $1 | awk -F'[/]' '{print $1}'`/32
INPUT_PUBIP=`echo $PUBIP | awk -F'[/]' '{print $1}'`

## Check the Private IP address usage
## In this processing, the private ip address will be checked by system status
## Check IP address subnet size (force to match the subnet by system)
INTERN_NETWORK=$(ip addr show $BRINT | grep -i "\<inet\>" | awk '{print $2}')
SUBNET_NUM=`ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk '{print $4}'`
SYSTEM_MIN=`ipcalc $INTERN_NETWORK | grep -i 'HostMin' | awk '{print $2}'`
SYSTEM_MAX=`ipcalc $INTERN_NETWORK | grep -i 'HostMax' | awk '{print $2}'`
if [[ `echo $2 | grep -i "/"` ]]
then
 INPUT_IPADDR=$2
 INPUT_IP_MIN=`ipcalc $2 | grep -i 'HostMin' | awk '{print $2}'`
 INPUT_IP_MAX=`ipcalc $2 | grep -i 'HostMax' | awk '{print $2}'`
 if [[ $SYSTEM_MIN != $INPUT_IP_MIN || $SYSTEM_MAX != $INPUT_IP_MAX ]]
 then
  echo "This system has $INTERN_NETWORK, Your input is something wrong!"
  echo "The system will change the subnet size....first checking!"
  INPUT_IPADDR=$(echo $2| awk -F'[/]' '{print $1}')/$SUBNET_NUM
 fi
else
 SUBNET_NUM=`ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk '{print $4}'`
 INPUT_IPADDR=$2/$INPUT_IPADDR
fi

## Check IP address range (member check!)
if [[ $(ipcalc $INPUT_IPADDR | grep -i 'HostMin' | awk '{print $2}') != $SYSTEM_MIN || $(ipcalc $INPUT_IPADDR | grep -i 'HostMax' | awk '{print $2}') != $SYSTEM_MAX ]]
then
 echo "wrong ip address agains system $INTERN_NETWORK, please check your inputs!"
 exit
fi
PRIIP=$INPUT_IPADDR
INPUT_PRIIP=`echo $PRIIP | awk -F'[/]' '{print $1}'`

## Check Public IP usage status
if [[ `ip addr show $BREXT | grep -i "\<inet\>" | awk -F'[ /]' '{print $6}'` ]]
then
 set `ip addr show $BREXT | grep -i "\<inet\>" | awk -F'[ /]' '{print $6}'`
 for USEDIP in $@
 do
  if [ $USEDIP = $INPUT_PUBIP ]
  then
   echo "This ip $INPUT_PUBIP address has been already located!"
   exit
  fi
 done 
fi

## Check Internal IP usage status by /etc/hosts
if [[ ! `cat /etc/hosts | grep -i "\<$INPUT_PRIIP\>"` ]]
then
 echo "there is no VM (IP : $PRIIP), create the VM!"
 exit
fi

## Quagga IP insertation
$(find / -name Q_telnet.py) add-ip $BREXT $PUBIP

## Create SNAT and DNAT
GW_IFACE=`route | grep -i 'default' | awk '{print $8}'`
iptables -t nat -I POSTROUTING 2 -s $PRIIP -o $GW_IFACE -j SNAT --to-source $INPUT_PUBIP
iptables -t nat -I PREROUTING -d $PUBIP -j DNAT --to-destination $INPUT_PRIIP
iptables-save > $working_directory/iptables.rules

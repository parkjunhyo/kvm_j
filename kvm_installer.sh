#! /usr/bin/env bash

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## CPU virtualization confirmation
set `egrep '(vmx|svm)' --color=always /proc/cpuinfo | awk '{print NR}'`
if [[ $# -lt 1 ]]
then
 echo "This CPU does not support virtualization!"
 exit
fi

## Installation KVM Packages
apt-get install -y git ubuntu-virt-server python-vm-builder kvm-ipxe
## Installation IP address calculation
apt-get install -y sipcalc ipcalc

## Upgrade Libvrirt for Openvswitch Supports
if [[ ! -d $working_directory/libvirt_upgrade ]]
then
 git clone https://github.com/parkjunhyo/libvirt_upgrade.git
 cd $working_directory/libvirt_upgrade
 ./setup_upgrade.sh
 cd $working_directory
fi

## Installation Openvswitch (kernel module installation)
if [[ ! -d $working_directory/ovs_j ]]
then
 git clone https://github.com/parkjunhyo/ovs_j.git
 cd $working_directory/ovs_j
 ./setup.sh
 cd $working_directory
fi

## Add the user authentication for libvirtd and KVM
adduser `id -un` libvirtd
adduser `id -un` kvm

## Installation Quagga Software Router
if [[ ! -d $working_directory/quagga_j ]]
then
 git clone https://github.com/parkjunhyo/quagga_j.git
 cd $working_directory/quagga_j
 sed -i "s/hostlo=\${hostlo:='change_lo'}//" ./netcfg.info
 echo "hostlo=$LOOPBACK" >> ./netcfg.info
 ./setup.sh
 ### Enable OSPF routing Protocol
 $(find / -name Q_telnet.py) enable-ospf $(echo $LOOPBACK | awk -F'[/]' '{print $1}')
 ### ADD default GW network in OSPF
 GW_IFACE=$(route | grep -i 'default' | awk '{print $8}')
 GW_NETWORK=$(ip addr show $GW_IFACE | grep -i 'inet' | grep -i $GW_IFACE | awk '{print $2}')
 $(find / -name Q_telnet.py) add-ospf-net $GW_NETWORK $OSPF_AREA
 cd $working_directory
fi

## Create the Virtual Network using OPENVSWITCH
INTERN_NETWORK=${INTERN_NETWORK:='10.210.0.1/24'}
INTERN_GW=$(ipcalc $INTERN_NETWORK | grep -i 'HostMin' | awk '{print $2}')
INTERN_NETMASK=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk '{print $2}')
INTERN_SUBNET=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk -F'[ =]' '{print $7}')
IPADDR_A=$(echo $INTERN_GW | awk -F'[.]' '{print $1}')
IPADDR_B=$(echo $INTERN_GW | awk -F'[.]' '{print $2}')
IPADDR_C=$(echo $INTERN_GW | awk -F'[.]' '{print $3}')
INTERN_DHCP=$IPADDR_A.$IPADDR_B.$IPADDR_C.$(expr $(echo $INTERN_GW | awk -F'[.]' '{print $4}') + '1')
INTERN_DHCP_START=$IPADDR_A.$IPADDR_B.$IPADDR_C.$(expr $(echo $INTERN_GW | awk -F'[.]' '{print $4}') + '2')
INTERN_DHCP_END=$(ipcalc $INTERN_NETWORK | grep -i 'HostMax' | awk '{print $2}')
if [[ ! `ip link show | grep -i 'ovsbr_ext'` ]]
then
 ovs-vsctl add-br ovsbr_ext
 echo " " >> /etc/network/interfaces
 echo "auto ovsbr_ext" >> /etc/network/interfaces
 echo " iface ovsbr_ext inet manual" >> /etc/network/interfaces
 echo " up ip link set \$IFACE up promisc on" >> /etc/network/interfaces
fi
if [[ ! `ip link show | grep -i 'ovsbr_int'` ]]
then
 ovs-vsctl add-br ovsbr_int
 echo " " >> /etc/network/interfaces
 echo "auto ovsbr_int" >> /etc/network/interfaces
 echo " iface ovsbr_int inet manual" >> /etc/network/interfaces
 echo " up ip link set \$IFACE up promisc on" >> /etc/network/interfaces
 $(find / -name Q_telnet.py) add-ip ovsbr_int $INTERN_GW/$INTERN_SUBNET
fi

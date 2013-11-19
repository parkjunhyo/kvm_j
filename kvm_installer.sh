#! /usr/bin/env bash

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Loop devicse Increasement for the KVM generation
## This paramter will be affected the multiple installation
## Ubunut has default as 8, in this time, it will be changed as 128
LOOPDEV=${LOOPDEV:=128}
sed -i "s/\<loop\>/loot max_loop=$LOOPDEV/" /etc/modules
modprobe loop
let "LOOPDEV = $LOOPDEV - 1"
for LoID in $(seq 0 $LOOPDEV)
do
 if [[ ! -b /dev/loop$LoID ]]
 then
  mknod -m0660 /dev/loop$LoID b 7 $LoID
  chown root.disk /dev/loop$LoID
 fi 
done
if [[ ! `cat /etc/rc.local | grep -i "increase_loopdev.sh"` ]]
then
 sed -i "/exit 0/d" /etc/rc.local
 echo "$(find / -name increase_loopdev.sh)" >> /etc/rc.local
 echo "exit 0" >> /etc/rc.local
fi

## CPU virtualization confirmation
## This parameter will decide the CPU can be virualized, at this time
if [[ `egrep '(vmx|svm)' --color=always /proc/cpuinfo | awk 'END{print NR}'` ]]
then
 set `egrep '(vmx|svm)' --color=always /proc/cpuinfo | awk 'END{print NR}'`
 if [[ $# -lt 1 ]]
 then
  echo "This CPU does not support virtualization!"
  exit
 fi
else
 echo "This CPU does not support vitrualization!"
 exit
fi

## Installation SSH-Key GIT server
apt-get install -y expect libexpat1-dev libcurl4-gnutls-dev gettext zlib1g-dev libssl-dev
## Installation KVM Packages
apt-get install -y git ubuntu-virt-server python-vm-builder kvm-ipxe lvm2
## Installation IP address calculation
apt-get install -y sipcalc ipcalc

## Upgrade Libvrirt for Openvswitch Supports
if [[ ! -d $working_directory/libvirt_upgrade ]]
then
 git clone https://github.com/parkjunhyo/libvirt_upgrade.git
 cd $working_directory/libvirt_upgrade
 ./setup_upgrade.sh
 cd $working_directory
 # remove default libvirt(virtual) network
 virsh net-destroy default
 virsh net-undefine default
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
## OSPF routing protocol will be enabled and Ethernet interface will be setted up
GW_IFACE=$(route | grep -i 'default' | awk '{print $8}')
if [[ ! -d $working_directory/quagga_j ]]
then
 git clone https://github.com/parkjunhyo/quagga_j.git
 cd $working_directory/quagga_j
 sed -i "s/hostlo=\${hostlo:='change_lo'}//" ./netcfg.info
 LOOPBACK=${LOOPBACK:="192.168.0.2/32"}
 echo "hostlo=$LOOPBACK" >> ./netcfg.info
 ./setup.sh
 ### Enable OSPF routing Protocol
 $(find / -name Q_telnet.py) enable-ospf $(echo $LOOPBACK | awk -F'[/]' '{print $1}')
 ### ADD default GW network in OSPF
 GW_NETWORK=$(ip addr show $GW_IFACE | grep -i 'inet' | grep -i $GW_IFACE | awk '{print $2}')
 $(find / -name Q_telnet.py) add-ospf-net $GW_NETWORK $OSPF_AREA
 cd $working_directory
fi

## Create the Virtual Network using OPENVSWITCH
## Internal Network Creation
## This Internal Network will be used for the vm interfaces
BREXT=${BREXT:='ovsbr_pub'}
BRINT=${BRINT:='ovsbr_pri'}
INTERN_NETWORK=${INTERN_NETWORK:='10.210.0.1/24'}
INTERN_GW=$(ipcalc $INTERN_NETWORK | grep -i 'HostMin' | awk '{print $2}')
INTERN_NETMASK=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk '{print $2}')
INTERN_SUBNET=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk -F'[ =]' '{print $7}')
IPADDR_A=$(echo $INTERN_GW | awk -F'[.]' '{print $1}')
IPADDR_B=$(echo $INTERN_GW | awk -F'[.]' '{print $2}')
IPADDR_C=$(echo $INTERN_GW | awk -F'[.]' '{print $3}')
NATMASK=${NATMASK:='16'}
INTERN_NATNET=`ipcalc $INTERN_GW/$NATMASK | grep -i 'Network' | awk '{print $2}'`
INTERN_DHCP=$IPADDR_A.$IPADDR_B.$IPADDR_C.$(expr $(echo $INTERN_GW | awk -F'[.]' '{print $4}') + '1')
INTERN_DHCP_START=$IPADDR_A.$IPADDR_B.$IPADDR_C.$(expr $(echo $INTERN_GW | awk -F'[.]' '{print $4}') + '2')
INTERN_DHCP_END=$(ipcalc $INTERN_NETWORK | grep -i 'HostMax' | awk '{print $2}')
if [[ ! `ip link show | grep -i $BREXT` ]]
then
 ovs-vsctl add-br $BREXT
 echo " " >> /etc/network/interfaces
 echo "auto $BREXT" >> /etc/network/interfaces
 echo " iface $BREXT inet manual" >> /etc/network/interfaces
 echo " up ip link set \$IFACE up promisc on" >> /etc/network/interfaces
 echo " " >> /etc/network/interfaces
fi
if [[ ! `ip link show | grep -i $BRINT` ]]
then
 ovs-vsctl add-br $BRINT
 $(find / -name Q_telnet.py) add-ip $BRINT $INTERN_GW/$INTERN_SUBNET
 ## Defaullt NAT Rule Creation
 SNAT_IP=`ifconfig $GW_IFACE | grep -i 'inet addr' | awk -F'[ :]' '{print $13}'`
 iptables -t nat -I POSTROUTING -s $INTERN_NETWORK -d $INTERN_NATNET -j ACCEPT
 iptables -t nat -A POSTROUTING -s $INTERN_NETWORK -o $GW_IFACE -j SNAT --to-source $SNAT_IP
 iptables-save > $working_directory/iptables.rules
 ## Rule Auto-startup 
 echo " " >> /etc/network/interfaces
 echo "auto $BRINT" >> /etc/network/interfaces
 echo " iface $BRINT inet manual" >> /etc/network/interfaces
 echo " up ip link set \$IFACE up promisc on" >> /etc/network/interfaces
 echo " pre-up iptables-restore < $working_directory/iptables.rules" >> /etc/network/interfaces
 echo " " >> /etc/network/interfaces
fi

## Configuration Change for VMbuilder and Livbrit Option
## This is necessary to accept the openvswitch on the KVM is working
sed -i "s/<source bridge='\$bridge'\/>/<source bridge='\$bridge'\/>\n\t\t<virtualport type='openvswitch'>\n\t\t<\/virtualport>\n/" /etc/vmbuilder/libvirt/libvirtxml.tmpl

## Create the SSH-KEY and Git Server
## this process will be two kind of ssh access method into the vm
## first one is the root password enable
## second is the ssh key creation
if [[ ! -d /gitserver/hypervisor_sshkey ]]
then
 mkdir -p /gitserver
 mkdir -p /gitserver/hypervisor_sshkey
 touch /gitserver/hypervisor_sshkey/authorized_keys
fi
## Generate the GIT enviorment to download the ssh for the vms
if [[ ! -f /root/.ssh/id_rsa ]]
then
 $working_directory/sshkey_generate.exp
 cat /root/.ssh/id_rsa.pub > /gitserver/hypervisor_sshkey/authorized_keys
 ## GIT uploading
 cd /gitserver/hypervisor_sshkey
 git init
 git add .
 git commit -m 'first ssh key upload'
 ## GIT exporting
 cd /gitserver/
 git clone --bare hypervisor_sshkey/
 touch /gitserver/hypervisor_sshkey.git/git-daemon-export-ok
 cd $working_directory
 git daemon --reuseaddr --base-path=/gitserver&
 ## after the system is rebooted, the git server will be restarted!
 sed -i "/exit 0/d" /etc/rc.local
 echo "/usr/bin/git daemon --reuseaddr --base-path=/gitserver&" >> /etc/rc.local
 echo "exit 0" >> /etc/rc.local
fi

## VNC installation processing
if [[ ! -d $working_directory/vnc_j ]]
then
 git clone https://github.com/parkjunhyo/vnc_j.git
 cd vnc_j
 ./setup.sh
 ./shutdown_vnc.sh
 ./startvnc.sh
 cd $working_directory
fi


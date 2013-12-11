#! /usr/bin/env bash

## current directory information and source the env file
working_directory=$(pwd)
env_source_path=$(find `pwd` -name kvm_setup.env)
source $env_source_path

## log file creation
if [ ! -f $LOGFILE ]
then
 touch $LOGFILE
fi

## check the cpu virtualization status
if [[ `egrep '(vmx|svm)' --color=always /proc/cpuinfo | awk 'END{print NR}'` -lt 1 ]]
then
 echo "this hardware does not support for the virtualization"
 exit
fi

## Loop devicse Increasement for the KVM generation
## This paramter will be affected the multiple installation
## Ubunut has default as 8, in this time, it will be changed as 128
if [[ ! `cat $(pwd)/increase_loopdev.sh | grep -i $env_source_path` ]]
then
 sed -i '3i source '$env_source_path'\n' $(pwd)/increase_loopdev.sh
 increase_loop_path=$(find `pwd` -name increase_loopdev.sh)
 echo "[ $(date) $(pwd) ] increse_loopdev.sh file path : $increase_loop_path" >> $LOGFILE
 $increase_loop_path
 ## init daemon insert
 if [[ ! `cat /etc/rc.local | grep -i $increase_loop_path` ]]
 then
  sed -i "/^exit[[:space:]]*[[:digit:]]*/d" /etc/rc.local
  echo "$increase_loop_path" >> /etc/rc.local
  echo "exit 0" >> /etc/rc.local
 fi
fi

## install the basic and necessary package
apt-get install -qqy --force-yes expect libexpat1-dev libcurl4-gnutls-dev gettext zlib1g-dev libssl-dev git ubuntu-virt-server python-vm-builder kvm-ipxe lvm2 sipcalc ipcalc

## libvirt upgrade for openvswitch kernerl build
if [ ! -d $working_directory/libvirt_upgrade ]
then
 cd $working_directory
 git clone https://github.com/parkjunhyo/libvirt_upgrade.git
 cd $working_directory/libvirt_upgrade
 ./setup_upgrade.sh
 cd $working_directory
 virsh net-destroy default
 virsh net-undefine default
 echo "[ $(date) $(pwd) ] livbirtd version : $(libvirtd --version)" >> $LOGFILE
fi

## add the user authentication for libvirtd and kvm
adduser `id -un` libvirtd
adduser `id -un` kvm

## openvswitch installation
if [ ! -d $working_directory/ovs_j ]
then
 cd $working_directory
 git clone https://github.com/parkjunhyo/ovs_j.git
 cd $working_directory/ovs_j
 ./soft_kernel_setup.sh 
 cd $working_directory
fi

## installation quagga software router
LOOPBACK=${LOOPBACK:="192.168.0.2"}
OSPF_AREA=${OSPF_AREA:='0'}
echo "[ $(date) $(pwd) ] LOOPBACK IP: $LOOPBACK, OSPF_AREA : $OSPF_AREA" >> $LOGFILE
if [ ! -d $working_directory/quagga_j ]
then
 cd $working_directory
 git clone https://github.com/parkjunhyo/quagga_j.git
 cd $working_directory/quagga_j
 sed -i "s/#*[[:space:]]*hostlo='change_lo'/hostlo="$LOOPBACK"/" $working_directory/quagga_j/netcfg.info
 ./setup.sh
 $(find $working_directory/quagga_j -name Q_telnet.py) enable-ospf $LOOPBACK
 default_iface=`route | grep -i 'default' | awk '{print $8}'`
 default_network=`ip addr show $default_iface | grep -i '\<inet\>' | awk '{print $2}'`
 echo "[ $(date) $(pwd) ] DEFAULT Interface : $default_iface, DEFAULT NETWORK : $default_network" >> $LOGFILE
 $(find $working_directory/quagga_j -name Q_telnet.py) add-ospf-net $default_network $OSPF_AREA
 echo "[ $(date) $(pwd) ] $(cat /etc/quagga/zebra.conf)" >> $LOGFILE
 echo "[ $(date) $(pwd) ] $(cat /etc/quagga/ospfd.conf)" >> $LOGFILE
 cd $working_directory
fi

#################################################
## Create the Virtual Network using OPENVSWITCH
## Internal Network Creation
## This Internal Network will be used for the vm interfaces
BREXT=${BREXT:='ovsbr_pub'}
BRINT=${BRINT:='ovsbr_pri'}
GW_IFACE=$(route | grep -i 'default' | awk '{print $8}')
INTERN_NETWORK=${INTERN_NETWORK:='10.210.0.1/24'}
INTERN_GW=$(ipcalc $INTERN_NETWORK | grep -i 'HostMin' | awk '{print $2}')
INTERN_NETMASK=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk '{print $2}')
INTERN_SUBNET=$(ipcalc $INTERN_NETWORK | grep -i 'Netmask' | awk -F'[ =]' '{print $7}')
IPADDR_A=$(echo $INTERN_GW | awk -F'[.]' '{print $1}')
IPADDR_B=$(echo $INTERN_GW | awk -F'[.]' '{print $2}')
IPADDR_C=$(echo $INTERN_GW | awk -F'[.]' '{print $3}')
## total private network size
NATMASK=${NATMASK:='16'}
INTERN_NATNET=`ipcalc $INTERN_GW/$NATMASK | grep -i 'Network' | awk '{print $2}'`
echo "[ $(date) $(pwd) ] BREXT : $BREXT, BRINT : $BRINT, INTERNAL NETWORK : $INTERN_NETWORK" >> $LOGFILE
echo "[ $(date) $(pwd) ] INTERNEL GW : $INTERN_GW, INTERNEL_NETMASK : $INTERN_NETMASK, $INTERN_SUBNET" >> $LOGFILE
echo "[ $(date) $(pwd) ] PRIVATE NAT NETWORK : $INTERN_NATNET" >> $LOGFILE
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
echo "[ $(date) $(pwd) ] NETWORK CONFIGURATION : " >> $LOGFILE
echo "$(cat /etc/network/interfaces)" >> $LOGFILE
echo "[ $(date) $(pwd) ] IPTABLES RULE : " >> $LOGFILE
echo "$(iptables -t nat -nvL)" >> $LOGFILE
#################################################

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
 sed -i "/^exit[[:space:]]*[[:digit:]]*/d" /etc/rc.local
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

## Finish the Installation 

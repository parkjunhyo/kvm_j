#! /usr/bin/env bash

## This command for the Creation of VM with Static IP address in use,
## You need information of IP address which you want to setup in VM.

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Check the Variable to create VM machine
BREXT=${BREXT:='ovsbr_ext'}
BRINT=${BRINT:='ovsbr_int'}
if [[ $# -ne 2 ]]
then
 echo "$0 [vm name, up to 10 lower letter] [ip address]"
 exit
fi

## Check IP address format
FORM_STATUS=$(echo $2 | awk -F"[/]" '{print $1}' | awk -F"[.]" '{if(NF==4){for(i=1; i<=NF; i++){if($i!~/[[:digit:]]+/){print "false"}}}else{print "false"}}')
if [[ $FORM_STATUS = "false" ]]
then
 echo "wrong ip address format, please confirm it is correct!"
 exit
fi

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

## SYSTEM PARAMETER to create vm will be setuped at this time
VMNAME=$1
IPADDR=`ipcalc $INPUT_IPADDR | grep -i 'Address' | awk '{print $2}'`
SUBNET=`ipcalc $INPUT_IPADDR | grep -i 'Netmask' | awk '{print $2}'`
GATEWY=`ifconfig $BRINT | grep -i 'inet addr' | awk -F'[ :]' '{print $13}'`


## Check Internal IP usage status by /etc/hosts
if [[ `cat /etc/hosts | grep -i "\<$IPADDR\>"` ]]
then
 echo "This ip address has been already located, check /etc/hosts file!"
 exit
fi

## KVM work place and directory information
VMIMAGE_DIR='/var/lib/libvirt/images'
GUEST_DIR=$VMIMAGE_DIR/$VMNAME


## Create the Guest VM images folder
if [[ -d $GUEST_DIR ]]
then
 echo "Already VM name is existed!"
 exit
fi
mkdir -p $GUEST_DIR/mytemplates/libvirt
cp /etc/vmbuilder/libvirt/* $GUEST_DIR/mytemplates/libvirt

## Create Hardisk Volume information
ROOTVOL=${ROOTVOL:='8000'}
SWAPVOL=${SWAPVOL:='4000'}
VARVOL=${VARVOL:='20000'}
cp $working_directory/imaged_base.vmbuilder.partition $GUEST_DIR/vmbuilder.partition
sed -i 's/rootsize/'$ROOTVOL'/' $GUEST_DIR/vmbuilder.partition
sed -i 's/swapsize/'$SWAPVOL'/' $GUEST_DIR/vmbuilder.partition
sed -i 's/varsize/'$VARVOL'/' $GUEST_DIR/vmbuilder.partition

## Hoding the Time to stable creation
while [[ $(ps aux | grep -i 'vmbuilder' | awk 'END{print NR}') -gt 3 ]]
do
 sleep 60
done

## Create the Virtual Machine with VMbuilder
ARCH=${ARCH:='amd64'}
MEM=${MEM:='1024'}
CPU=${CPU:='2'}
USERNAME=${USERNAME:='useradmin'}
USERPASS=${USERPASS:='userpass'}
cd $GUEST_DIR
vmbuilder kvm ubuntu --suite=precise --flavour=virtual --arch=$ARCH --mirror=http://archive.ubuntu.com/ubuntu -o --libvirt=qemu:///system --ip=$IPADDR --gw=$GATEWY --mask=$SUBNET --dns=8.8.8.8 --part=vmbuilder.partition --templates=mytemplates --user=$USERNAME --name=$USERNAME --pass=$USERPASS --addpkg=vim-nox --addpkg=unattended-upgrades --addpkg=acpid --firstboot=$working_directory/boot.sh --cpus=$CPU --mem=$MEM --hostname=$VMNAME --bridge=$BRINT
cd $working_directory

if [[ -d $GUEST_DIR/ubuntu-kvm ]]
then
 ## Multi-NIC interface Creation and generation
 ## This creation has default Multi-Nic Interface to extention
 VM_Extended_Network="$VMNAME"_xn
 ovs-vsctl add-br $VM_Extended_Network
 sed -i "s/<\/interface>/<\/interface>\n\t<interface type='bridge'>\n\t\t<source bridge='$VM_Extended_Network'\/>\n\t\t<virtualport type='openvswitch'>\n\t\t<\/virtualport>\n\t\t<model type='virtio'\/>\n\t<\/interface>\n/" /etc/libvirt/qemu/$VMNAME.xml
 ## VIRSH define the VM
 virsh define /etc/libvirt/qemu/$VMNAME.xml
 ## update the IP assign information
 ## update the host file to easy VM controller
 echo "$IPADDR $VMNAME" >> /etc/hosts
else
 rm -rf $GUEST_DIR 
fi

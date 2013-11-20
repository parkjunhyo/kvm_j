#! /usr/bin/env bash

## This command for the Creation of VM with Static IP address in use,
## You need information of IP address which you want to setup in VM.

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Check the Variable to create VM machine (two input is necessary)
BREXT=${BREXT:='ovsbr_pub'}
BRINT=${BRINT:='ovsbr_pri'}
if [[ $# -ne 2 ]]
then
 echo "$0 [vm name, up to 10 lower letter] [ip address]"
 exit
fi

## In this process, the IP format will be checked
## first step, check the 4 digit are inserted, such as 10.210.3.1
if [[ $(echo $2 | awk -F"[/]" '{print $1}' | awk -F"[.]" '{if(NF==4){for(i=1; i<=NF; i++){if($i~/[[:alpha:]]+/){print "false";break}}}else{print "false"}}') = "false" ]]
then
 echo "wrong ip address format, please confirm it is correct!"
 exit
fi

## Check IP address subnet size (force to match the subnet by system)
## This process will address the system ip address which already setted on bridge for internal
## Compare the minum and maximu ip address for the subnet is correct
## first step, subnet checking and revise the subnet.
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
  echo "This system has $INTERN_NETWORK, Your subnet is wrong(MIN $INPUT_IP_MIN, MAX $INPUT_IP_MAX)!"
  INPUT_IPADDR=$(echo $2| awk -F'[/]' '{print $1}')/$SUBNET_NUM
  echo "Your input ip address will be changed as $INPUT_IPADDR"
 fi
else
 INPUT_IPADDR=$2/$SUBNET_NUM
fi

## Check IP address range (member check!), again
if [[ $(ipcalc $INPUT_IPADDR | grep -i 'HostMin' | awk '{print $2}') != $SYSTEM_MIN || $(ipcalc $INPUT_IPADDR | grep -i 'HostMax' | awk '{print $2}') != $SYSTEM_MAX ]]
then
 echo "your ip address $INPUT_IPADDR, however the system ip is $INTERN_NETWORK !"
 echo "stop the processing........kvm creation fail.."
 exit
fi

## SYSTEM PARAMETER to create vm will be setuped at this time
VMNAME=$1
VMIMAGE_DIR='/var/lib/libvirt/images'
IPADDR=`ipcalc $INPUT_IPADDR | grep -i 'Address' | awk '{print $2}'`
## check the ip address is used or not
## in this processing, the hosts files will be used
if [[ `cat /etc/hosts | grep -i "\<$IPADDR\>"` ]]
then
 if [[ -f $VMIMAGE_DIR/$VMNAME ]]
 then
  echo "this $IPADDR is used for $VMNAME!"
  exit
 else
  if [[ `ps aux | grep -i 'vmbuilder' | grep $IPADDR` ]]
  then
   echo "this $IPADDR is reserved for other vm"
   exit
  else
   # remove ip address hosts file when the vm images is not existed!
   sed -i "/$IPADDR/d" /etc/hosts
  fi
 fi 
fi
SUBNET=`ipcalc $INPUT_IPADDR | grep -i 'Netmask' | awk '{print $2}'`
GATEWY=`ifconfig $BRINT | grep -i 'inet addr' | awk -F'[ :]' '{print $13}'`
## register the hosts files to prevent the ip conflict during kvm creation
echo "$IPADDR $VMNAME" >> /etc/hosts

## KVM work place and directory information
## VMIMAGE_DIR = /var/lib/libvirt/images
## GUEST_DIR is the VM information
GUEST_DIR=$VMIMAGE_DIR/$VMNAME

## Create the Guest VM images folder
if [[ -d $GUEST_DIR ]]
then
 echo "your required vm name $VMNAME has been existed!"
 echo "stop the processing........kvm creation fail.."
 exit
fi
mkdir -p $GUEST_DIR/mytemplates/libvirt
cp /etc/vmbuilder/libvirt/* $GUEST_DIR/mytemplates/libvirt

## Create Hardisk Volume information (partioning volume size)
ROOTVOL=${ROOTVOL:='8000'}
SWAPVOL=${SWAPVOL:='4000'}
VARVOL=${VARVOL:='20000'}
cp $working_directory/imaged_base.vmbuilder.partition $GUEST_DIR/vmbuilder.partition
cp $working_directory/boot.sh $GUEST_DIR/boot.sh
sed -i 's/rootsize/'$ROOTVOL'/' $GUEST_DIR/vmbuilder.partition
sed -i 's/swapsize/'$SWAPVOL'/' $GUEST_DIR/vmbuilder.partition
sed -i 's/varsize/'$VARVOL'/' $GUEST_DIR/vmbuilder.partition

## Create the Virtual Machine with VMbuilder
ARCH=${ARCH:='amd64'}
MEM=${MEM:='2048'}
CPU=${CPU:='2'}
USERNAME=${USERNAME:='useradmin'}
KERNEL=${KERNEL:='virtual'}
USERPASS=${USERPASS:='userpass'}
cd $GUEST_DIR
vmbuilder kvm ubuntu --suite=precise --flavour=$KERNEL --arch=$ARCH --mirror=http://archive.ubuntu.com/ubuntu -o --libvirt=qemu:///system --ip=$IPADDR --gw=$GATEWY --mask=$SUBNET --dns=8.8.8.8 --part=vmbuilder.partition --templates=mytemplates --user=$USERNAME --name=$USERNAME --pass=$USERPASS --addpkg=vim-nox --addpkg=unattended-upgrades --addpkg=acpid --firstboot=$GUEST_DIR/boot.sh --cpus=$CPU --mem=$MEM --hostname=$VMNAME --bridge=$BRINT
cd $working_directory

## KVM complete status check 
## at this time, multi-nic-interface configuration will be setted up
if [[ -d $GUEST_DIR/ubuntu-kvm ]]
then
 ## extend (multi-nic) virtual network bridge create
 VM_Extended_Network="$VMNAME"_xn
 ovs-vsctl add-br $VM_Extended_Network
 ## libvirt xml file will be edited (this is global xml file)
 sed -i "s/<\/interface>/<\/interface>\n\t<interface type='bridge'>\n\t\t<source bridge='$VM_Extended_Network'\/>\n\t\t<virtualport type='openvswitch'>\n\t\t<\/virtualport>\n\t\t<model type='virtio'\/>\n\t<\/interface>\n/" /etc/libvirt/qemu/$VMNAME.xml
 ## VIRSH define the VM (re-gernerate the xml file)
 virsh define /etc/libvirt/qemu/$VMNAME.xml
else
 ## KVM fail case, the VM and host file will be cleared
 rm -rf $GUEST_DIR 
 sed -i "/$VMNAME/d" /etc/hosts 
fi

#! /usr/bin/env bash

## This command for the Creation of VM with Static IP address in use,
## You need information of IP address which you want to setup in VM.

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Check the Variable to create VM machine
if [[ $# -ne 2 ]]
then
 echo "$0 [vm name, not capital letter] [ip address with subnet, 10.210.0.3/24]"
 exit
fi
VMNAME=$1
IPADDR=`ipcalc $2 | grep -i 'Address' | awk '{print $2}'`
SUBNET=`ipcalc $2 | grep -i 'Netmask' | awk '{print $2}'`
GATEWY=$(ifconfig ovsbr_int | grep -i 'inet addr' | awk -F'[ :]' '{print $13}')

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

## Create the Virtual Machine with VMbuilder
ARCH=${ARCH:='amd64'}
MEM=${MEM:='1024'}
USERNAME=${USERNAME:='useradmin'}
USERPASS=${USERPASS:='userpass'}
cd $GUEST_DIR
vmbuilder kvm ubuntu --suite=precise --flavour=virtual --arch=$ARCH --mirror=http://archive.ubuntu.com/ubuntu -o --libvirt=qemu:///system --ip=$IPADDR --gw=$GATEWY --net=$SUBNET --dns=8.8.8.8 --part=vmbuilder.partition --templates=mytemplates --user=$USERNAME --name=$USERNAME --pass=$USERPASS --addpkg=vim-nox --addpkg=unattended-upgrades --addpkg=acpid --firstboot=$working_directory/boot.sh --mem=$MEM --hostname=$VMNAME --bridge=ovsbr_int
cd $working_directory

## VIRSH define the VM
virsh define /etc/libvirt/qemu/$VMNAME.xml

## update the IP assign information
if [[ ! -f $working_directory/IP_used_resource.txt ]]
then
 touch $working_directory/IP_used_resource.txt
fi


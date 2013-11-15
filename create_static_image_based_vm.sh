#! /usr/bin/env bash

## This command for the Creation of VM with Static IP address in use,
## You need information of IP address which you want to setup in VM.

## Current Directory Information
working_directory=$(pwd)
source $working_directory/kvm_setup.env

## Check the Variable to create VM machine
if [[ $# -ne 2 ]]
then
 echo "$0 [vm name, up to 10 lower letter] [ip address with subnet, 10.210.0.3/24]"
 exit
fi
BREXT=${BREXT:='ovsbr_ext'}
BRINT=${BRINT:='ovsbr_int'}
VMNAME=$1
IPADDR=`ipcalc $2 | grep -i 'Address' | awk '{print $2}'`
SUBNET=`ipcalc $2 | grep -i 'Netmask' | awk '{print $2}'`
GATEWY=`ifconfig $BRINT | grep -i 'inet addr' | awk -F'[ :]' '{print $13}'`

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
vmbuilder kvm ubuntu --suite=precise --flavour=virtual --arch=$ARCH --mirror=http://archive.ubuntu.com/ubuntu -o --libvirt=qemu:///system --ip=$IPADDR --gw=$GATEWY --mask=$SUBNET --dns=8.8.8.8 --part=vmbuilder.partition --templates=mytemplates --user=$USERNAME --name=$USERNAME --pass=$USERPASS --addpkg=vim-nox --addpkg=unattended-upgrades --addpkg=acpid --firstboot=$working_directory/boot.sh --mem=$MEM --hostname=$VMNAME --bridge=$BRINT
cd $working_directory

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

#! /usr/bin/env bash

## Check the Variable to create VM machine
if [[ $# -ne 1 ]]
then
 echo "$0 [vm name, up to 10 lower letter]"
 exit
fi
VMNAME=$1

## Check if the VM is running or not
## if the VM is running, do not start again
if [[ ! `virsh list --all | grep -i "\<$VMNAME\>"` ]]
then
 echo "There is no virtaul machine which has name $VMNAME!"
 echo "create_static_image_based_vm.sh should be done for $VMNAME!"
 exit
fi

## start vm
if [ $(virsh list --all | grep -i "\<$VMNAME\>" | awk '{print $3}') = 'running' ]
then
 echo "$VMNAME has been already started!"
 exit
else
 virsh define /etc/libvirt/qemu/$VMNAME.xml
 virsh start $VMNAME 
fi

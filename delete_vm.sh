#! /usr/bin/env bash

## Check the Variable to create VM machine
if [[ $# -ne 1 ]]
then
 echo "$0 [vm name, up to 10 lower letter]"
 exit
fi
VMNAME=$1

## Check if the VM is running or not
## if the VM is running, shutdown the VM
if [[ ! `virsh list --all | grep -i "\<$VMNAME\>"` ]]
then
 echo "There is no virtaul machine which has name $VMNAME!"
 exit
fi

VMSTATUS=`virsh list --all | grep -i "\<$VMNAME\>" | awk '{print $3}'`
if [ $VMSTATUS = 'running' ]
then
 virsh shutdown $VMNAME
fi

## Undefine and delete VM images files
virsh undefine $VMNAME
rm -rf /var/lib/libvirt/images/$VMNAME
sed -i "/$VMNAME/d" /etc/hosts

## delete extended network
VM_Extended_Network="$VMNAME"_xn
ovs-vsctl del-br $VM_Extended_Network

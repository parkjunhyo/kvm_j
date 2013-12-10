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

## delay is necessary for finishing the shutdown
if [ $(virsh list --all | grep -i "\<$VMNAME\>" | awk '{print $3}') = 'running' ]
then
 virsh shutdown $VMNAME
 sleep 5
fi
## undefine before removing the kvm configure files
virsh undefine $VMNAME

## delete the Volume base 
if [[ `lvdisplay | grep -i $VMNAME` ]]
then
 set `lvdisplay | grep -i $VMNAME | awk '{print $3}'`
 for LVNAME in $@
 do
  lvremove $LVNAME -f
 done
fi

## QCOW2 File VM (remove processing)
## remove all data and backup file
QCOW_FILE="/var/lib/libvirt/images/$VMNAME"
if [[ -d $QCOW_FILE ]]
then
 rm -rf $QCOW_FILE
fi
QCOW_BAK_FILE="/var/lib/libvirt/images/$VMNAME.qcow2.bak"
if [[ -f $QCOW_BAK_FILE ]]
then
 rm -rf $QCOW_BAK_FILE
fi

## Delete the IP information from hostfile
sed -i "/$VMNAME/d" /etc/hosts

## delete extended network and interface
VM_Extended_Network="$VMNAME"_xn
if [[ `ovs-vsctl show | grep -i "\<$VM_Extended_Network\>"` ]]
then
 ovs-vsctl del-br $VM_Extended_Network
 $(find `pwd` -name Q_telnet.py) rm-zebra-iface $VM_Extended_Network
 $(find `pwd` -name Q_telnet.py) rm-ospf-iface $VM_Extended_Network
fi

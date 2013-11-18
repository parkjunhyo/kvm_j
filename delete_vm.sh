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
 sleep 5
fi

## Check the VM mode (raw mode and QCOW2 mode)
## Undefine and delete VM images files
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
## remove all data
if [[ -d /var/lib/libvirt/images/$VMNAME ]]
then
 rm -rf /var/lib/libvirt/images/$VMNAME
fi
if [[ -f "/etc/libvirt/qemu/$VMNAME.xml.bak" ]]
then
 rm -rf /etc/libvirt/qemu/$VMNAME.xml.bak
fi

## Delete the IP information from hostfile
sed -i "/$VMNAME/d" /etc/hosts

## delete extended network and interface
VM_Extended_Network="$VMNAME"_xn
if [[ `ovs-vsctl show | grep -i "\<$VM_Extended_Network\>"` ]]
then
 ovs-vsctl del-br $VM_Extended_Network
 $(find / -name Q_telnet.py) rm-iface $VM_Extended_Network
fi

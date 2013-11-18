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

## Check the VM mode (raw mode and QCOW2 mode)
## Undefine and delete VM images files
virsh undefine $VMNAME
if [[ `ls /dev/$(hostname)/$VMNAME*` ]]
then
 set `ls /dev/$(hostname)/$VMNAME*`
 for VOLDEV in $@
 do
  lvremove $VOLDEV -f
 done
fi

if [[ -d /var/lib/libvirt/images/$VMNAME ]]
then
 rm -rf /var/lib/libvirt/images/$VMNAME
fi
if [[ `ls /etc/libvirt/qemu/$VMNAME.xml*` ]]
then
 set `ls /etc/libvirt/qemu/$VMNAME.xml*`
 for XMLFILE in $@
 do
  rm -rf $XMLFILE
 done
fi

## Delete the IP information from hostfile
sed -i "/$VMNAME/d" /etc/hosts

## delete extended network and interface
VM_Extended_Network="$VMNAME"_xn
ovs-vsctl del-br $VM_Extended_Network
$(find / -name Q_telnet.py) rm-iface $VM_Extended_Network

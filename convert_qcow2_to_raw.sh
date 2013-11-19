#! /usr/bin/env bash

##### This file will be used for converting the QCOW2 file to RAW file
##### RAW file will be used, when the Logical Volum based system
## check the input variable
if [[ $# -ne 1 ]]
then
 echo "$0 [vm name] is necessary!"
 exit
fi

## check the vm existance
if [[ ! `virsh list --all | grep -i "\<$1\>" | awk '{print $2}'` ]]
then
 echo "there is no vm name : $1, please create the vm $1 at first!"
 exit
fi
VMNAME=$1

## check the vm status whether running or not
## if the vm is running, please the stop or shutdown the vm
if [ $(virsh list --all | grep -i "\<$VMNAME\>" | awk '{print $3}') = 'running' ]
then
 virsh shutdown $VMNAME
fi

## Find the Volume size, addtional VOLUME SIZE is necessary
## however, the default 3000 will be added (more space is necessary)
PART_INFO="/var/lib/libvirt/images/$VMNAME/vmbuilder.partition"
XML_INFO="/etc/libvirt/qemu/$VMNAME.xml"
set `cat $PART_INFO | awk 'BEGIN{sum=0}{sum=sum+$2;if($0~/-+/){print sum+3000;sum=0;}}END{print sum+3000;}'`
INDEX=0
for VOLSIZE in $@
do
 VOLNAME=$VMNAME\_$INDEX
 if [ ! -h /dev/$(hostname)/$VOLNAME ]
 then
  lvcreate -L$VOLSIZE -n $VOLNAME $(hostname)
 else
  echo "the logical volume $VOLNAME has been existed!"
  echo "convert qcow2 to raw....fail"
  exit
 fi
 let "INDEX = $INDEX + 1"
done

## backup the qcow2 xml file
XML_BAK=$XML_INFO.qcow2.bak
if [[ ! -f $XML_BAK ]]
then
 cp $XML_INFO $XML_BAK
fi

## replace the xml file (qcow2 to raw)
if [[ `cat $XML_INFO | grep -i "source file" | grep -i 'qcow2'` ]]
then
 set `cat $XML_INFO | grep -i "source file" | awk -F"['/]" '{print $9}'`
 INDEX=0
 for QCOW in $@
 do 
  ## XML file revisoin for sed programe
  QCOW_FILE="\/var\/lib\/libvirt\/images\/$VMNAME\/ubuntu-kvm\/$QCOW"
  RAW_FILE="\/dev\/$(hostname)\/"$VMNAME\_$INDEX
  sed -i 's/'$QCOW_FILE'/'$RAW_FILE'/' $XML_INFO
  ## convert QCOW2 file to raw file
  QCOW_FILE="/var/lib/libvirt/images/$VMNAME/ubuntu-kvm/$QCOW"
  RAW_FILE="/dev/$(hostname)/"$VMNAME\_$INDEX
  qemu-img convert $QCOW_FILE -O raw $RAW_FILE
  ## index update
  let "INDEX = $INDEX + 1"
 done
 sed -i 's/qcow2/raw/' $XML_INFO
fi

## define the raw xml file and re-gerneration raw xml file
virsh define $XML_INFO

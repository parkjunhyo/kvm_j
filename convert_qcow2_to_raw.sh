#! /usr/bin/env bash


## check the input variable
if [[ $# -ne 1 ]]
then
 echo "$0 [vm name] is necessary!"
 exit
fi

## check the vm existance
if [[ ! `virsh list --all | grep -i $1 | awk '{print $2}'` ]]
then
 echo "there is no vm, please create the vm at first!"
 exit
fi
VMNAME=$1

if [ $(virsh list --all | grep -i $VMNAME | awk '{print $3}') = 'running' ]
then
 virsh shutdown $VMNAME
fi

## Find the Volume size, addtional VOLUME SIZE is necessary
PART_INFO="/var/lib/libvirt/images/$VMNAME/vmbuilder.partition"
XML_INFO="/etc/libvirt/qemu/$VMNAME.xml"
set `cat $PART_INFO | awk 'BEGIN{sum=0}{sum=sum+$2;if($0~/-+/){print sum+3000;sum=0;}}END{print sum+3000;}'`
INDEX=0
for VOLSIZE in $@
do
 let "INDEX = $INDEX + 1"
 VOLNAME=$VMNAME\_$INDEX
 if [ ! -h /dev/$(hostname)/$VOLNAME ]
 then
  lvcreate -L$VOLSIZE -n $VOLNAME $(hostname)
 fi
done

## Converter the Image for LOGICAL VOLUME
if [[ ! -f $XML_INFO.bak ]]
then
 cp $XML_INFO $XML_INFO.bak
fi
if [[ `cat $XML_INFO | grep -i "source file" | grep -i 'qcow2'` ]]
then
 set `cat $XML_INFO | grep -i "source file" | awk -F"['/]" '{print $9}'`
 INDEX=0
 for QCOW in $@
 do 
  ## XML file revisoin
  QCOW_DIR="\/var\/lib\/libvirt\/images\/$VMNAME\/ubuntu-kvm"
  let "INDEX = $INDEX + 1"
  RAW_FILE="\/dev\/$(hostname)\/"$VMNAME\_$INDEX
  QCOW_FILE="$QCOW_DIR\/$QCOW"
  sed -i 's/'$QCOW_FILE'/'$RAW_FILE'/' $XML_INFO
  ## convert QCOW2 file to raw file
  QCOW_DIR="/var/lib/libvirt/images/$VMNAME/ubuntu-kvm"
  RAW_FILE="/dev/$(hostname)/"$VMNAME\_$INDEX
  QCOW_FILE="$QCOW_DIR/$QCOW"
  qemu-img convert $QCOW_FILE -O raw $RAW_FILE
 done
 sed -i 's/qcow2/raw/' $XML_INFO
fi

## define the raw xml file
virsh define $XML_INFO



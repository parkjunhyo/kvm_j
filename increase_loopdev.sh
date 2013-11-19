#! /usr/bin/env bash


## Loop devicse Increasement for the KVM generation
## This paramter will be affected the multiple installation
## Ubunut has default as 8, in this time, it will be changed as 128
LOOPDEV=${LOOPDEV:=128}
sed -i "s/\<loop\>/loot max_loop=$LOOPDEV/" /etc/modules
modprobe loop
let "LOOPDEV = $LOOPDEV - 1"
for LoID in $(seq 0 $LOOPDEV)
do
 if [[ ! -b /dev/loop$LoID ]]
 then
  mknod -m0660 /dev/loop$LoID b 7 $LoID
  chown root.disk /dev/loop$LoID
 fi 
done

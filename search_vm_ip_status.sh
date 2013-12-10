#! /usr/bin/env bash

# check the input and vm status
if [ $# != 1 ]
then
 echo "$0 [vm name] is required"
 exit
fi
vmname=$1

if [[ ! `cat /etc/hosts | grep -i "\<$vmname\>"` ]]
then
 echo "there is no created vm, check the vn mane"
 exit
fi

# find the ip address information
for privateip in `cat /etc/hosts | grep -i "\<$vmname\>" | awk '{print $1}'`
do
 echo "--------------------------------------------------------------------------------"
 iptables -t nat -nvL | grep -i "\<$privateip\>" | awk '{print $3"   from:"$8"   to:"$9"   change-"$10}'
done

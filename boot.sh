## This script will run the first time the virtual machine boots
## It is ran as root.
## This file will be located in /root/firstboot.sh

## install open-ssh and git client
apt-get install -qqy --force-yes openssh-server git
apt-get install -y gcc uml-utilities libtool build-essential git pkg-config linux-headers-`uname -r`
apt-get install -y linux-source-*
apt-get install -y kernel-package*
apt-get install -y fakeroot

working_directory=`pwd`

## configuration for root password changement
## default password for root 'startroot'
if [ ! -d /root/root_password_change ]
then
 cd /root
 git clone https://github.com/parkjunhyo/root_password_change.git
 cd /root/root_password_change
 ./setup.sh
fi
cd $working_directory

## GIT SSH Key Inserting this will make more easy to access with ssh
SSHGIT_SERVER=`route | grep -i 'default' | awk '{print $2}'`
if [ ! -d /root/.ssh ]
then
 mkdir -p /root/.ssh
fi
cd /root/.ssh
if [ ! -d /root/.ssh/hypervisor_sshkey ]
then
 git clone git://$SSHGIT_SERVER/hypervisor_sshkey.git
 cp hypervisor_sshkey/authorized_keys .
fi
cd $working_directory

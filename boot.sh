## This script will run the first time the virtual machine boots
## It is ran as root.
## This file will be located in /root/firstboot.sh

working_directory=`pwd`
apt-get install -qqy --force-yes git

## install git client and system package (dependcy)
if [ ! -d /deppkg_j ]
then
 cd /
 git clone https://github.com/parkjunhyo/deppkg_j.git
 cd /deppkg_j
 ./system_deppkg.sh
fi
cd $working_directory

apt-get install -qqy --force-yes openssh-server

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

## rebooting system
$(which reboot)

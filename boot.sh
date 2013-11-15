## This script will run the first time the virtual machine boots
## It is ran as root.
## This file will be located in /root/firstboot.sh

## install open-ssh and git client
apt-get install -qqy --force-yes openssh-server git

## configuration for root password changement
## default password for root 'startroot'
git clone https://github.com/parkjunhyo/root_password_change.git
working_directory=`pwd`
cd /root_password_change
./setup.sh
cd $working_directory

## GIT SSH Key Inserting this will make more easy to access with ssh
SSHGIT_SERVER=`route | grep -i 'default' | awk '{print $2}'`
if [ ! -d /root/.ssh ]
then
 mkdir -p /root/.ssh
fi
cd /root/.ssh
git clone git://$SSHGIT_SERVER/hypervisor_sshkey.git
cp hypervisor_sshkey/authorized_keys .
cd $working_directory

## This script will run the first time the virtual machine boots
## It is ran as root.
## This file will be located in /root/firstboot.sh

## install open-ssh and git client
apt-get install -qqy --force-yes openssh-server git
working_directory=`pwd`

## configuration for root password changement
## default password for root 'startroot'
if [[ ! -d /root_password_change ]]
then
 git clone https://github.com/parkjunhyo/root_password_change.git
 cd /root_password_change
 ./setup.sh
 cd $working_directory
fi

## GIT SSH Key Inserting this will make more easy to access with ssh
SSHGIT_SERVER=`route | grep -i 'default' | awk '{print $2}'`
if [ ! -d /root/.ssh ]
then
 mkdir -p /root/.ssh
fi
cd /root/.ssh
if [[ ! -d /root/.ssh/hypervisor_sshkey ]]
then
 git clone git://$SSHGIT_SERVER/hypervisor_sshkey.git
 cp hypervisor_sshkey/authorized_keys .
fi
cd $working_directory

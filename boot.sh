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



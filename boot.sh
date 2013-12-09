## This script will run the first time the virtual machine boots
## It is ran as root.
## This file will be located in /root/firstboot.sh

working_directory=`pwd`
## create the file J directory file to extend
J_dir="/j_opt_source"
if [ ! -d $J_dir ]
then
 mkdir -p $J_dir
fi

## install git package
apt-get install -qqy --force-yes git

## Soure list update for the system
if [ ! -d $J_dir/sourcelist ]
then
 git clone https://github.com/parkjunhyo/sourcelist.git
 cp $J_dir/sourcelist/sourcelist_CHANGESOURCESLIST /etc/apt/sources.list
 apt-get clean
 apt-get autoclean
 apt-get update
fi

## configuration for root password changement
## default password for root 'startroot'
if [ ! -d $J_dir/root_password_change ]
then
 cd $J_dir
 git clone https://github.com/parkjunhyo/root_password_change.git
 cd $J_dir/root_password_change
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
if [ ! -d $J_dir/hypervisor_sshkey ]
then
 cd $J_dir
 git clone git://$SSHGIT_SERVER/hypervisor_sshkey.git
 cp $J_dir/hypervisor_sshkey/authorized_keys /root/.ssh
 cd $working_directory
fi

## install open-ssh server package
apt-get install -qqy --force-yes openssh-server

## install git client and system package (dependcy)
if [ ! -d $J_dir/deppkg_j ]
then
 cd $J_dir
 git clone https://github.com/parkjunhyo/deppkg_j.git
 cd $J_dir/deppkg_j
 ./system_deppkg.sh
 cd $working_directory
fi

## rebooting system (create firstboo_done)
touch /root/firstboot_done
/sbin/reboot

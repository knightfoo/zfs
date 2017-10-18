#!/bin/bash -x 

#https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.04-Root-on-ZFS

zpool_name=tank0

DISKS_byid=()
DISKS_dev=()

disks() {
	while read d_; 
	do 
		d_id=$(ls -la /dev/disk/by-id/ |grep ${d_}$ | awk '{print $9}')
		DISKS_byid+=("${d_id}")
		DISKS_dev+=("${d_}")
	done< <(lsblk -io KNAME,TYPE| grep disk | awk '{print $1}')
}

clean_disks() {
	for d_ in ${DISKS_dev[@]};
	do
		echo "Czyszcze dysk $d_"
		sgdisk --zap-all /dev/${d_}
	done
}


partition_disks() {
	for d_ in ${DISKS_byid[@]};
	do 
		sgdisk -a1 -n2:34:2047  -t2:EF02 /dev/disk/by-id/${d_} 
	done
}	

create_zpool() {
	

}


disks
echo "Dyski - ${DISKS_dev[@]} "

create_zpool

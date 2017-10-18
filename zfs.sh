#!/bin/bash -x 

#https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.04-Root-on-ZFS


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
	lsblk -io KNAME,TYPE| grep disk | awk '{print $1}' | while read d_; 
	do
		echo "Dysk $d_"
		sgdisk --zap-all /dev/${d_}
	done

}

clean_diskss() {
	for d_ in ${DISKS_dev[@]};
	do
		echo "Czyszcze dysk $d_"
		sgdisk --zap-all /dev/${d_}
	done
}


partition_disks() {
	exit
}


disks
echo "Dyski - ${DISKS_dev[@]} "

clean_diskss

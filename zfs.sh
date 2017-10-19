#!/bin/bash -x 

#https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.04-Root-on-ZFS
# uwzglednic EFI

zpool_name=tank0

DISKS_byid=()
DISKS_dev=()

disks() {
	while read d_; 
	do 
		d_id=$(ls -la /dev/disk/by-id/ |grep ${d_}$ | awk '{print $9}')
		DISKS_byid+=("/dev/disk/by-id/${d_id}")
		DISKS_dev+=("/dev/${d_}")
	done< <(lsblk -io KNAME,TYPE| grep disk | awk '{print $1}')
}

clean_disks() {
	for d_ in ${DISKS_dev[@]};
	do
		echo "Czyszcze dysk $d_"
		sgdisk --zap-all ${d_}
	done
}


partition_disks() {
	for d_ in ${DISKS_byid[@]};
	do 
		sgdisk -a1 -n2:34:2047  -t2:EF02 ${d_} 
	done
}	

create_zpool() {
	SPAN=0
	SPANS=$((${#DISKS_byid[@]}/2))
	dyski=""
	#zpool create -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt tank0 mirror /dev/disk/by-id/ata-VBOX_HARDDISK_VB679d4313-9a878091 /dev/disk/by-id/ata-VBOX_HARDDISK_VB9c66a80e-e138249a mirror /dev/disk/by-id/ata-VBOX_HARDDISK_VBb2041ff0-9c27fdcc /dev/disk/by-id/ata-VBOX_HARDDISK_VBbd4505a1-546c1f04 	
	
	echo "SPAN ${SPAN} - SPANS ${SPANS}"

	dyski=${DISKS_byid[@]}

	echo "Lista $lista"


	while [ "${SPAN}" -lt "${SPANS}" ]
	do
 		if [ ${SPAN} -eq 0 ]
 		then
  			zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt ${zpool_name} mirror `echo | awk -v span=${SPAN} -v zfsparts="${dyski}" '{ split(zfsparts,arr," "); print arr[span+span+1] " " arr[span+span+2] }'`
 		else
  			zpool add -f ${zpool_name} mirror `echo | awk -v span=${SPAN} -v zfsparts="${dyski}" '{ split(zfsparts,arr," "); print arr[span+span+1] " " arr[span+span+2] }'`
			
 		fi
        	SPAN=$((${SPAN}+1))
	done


}


disks
clean_disks
create_zpool

#!/bin/bash -x 

#https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.04-Root-on-ZFS
# uwzglednic EFI

zpool_name=tank0
ubuntu_version=xenial
hostname=$1

DISKS_byid=()
DISKS_dev=()

zpool destroy -f ${zpool_name}

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

create_datasets() {
	zfs create -o canmount=off -o mountpoint=none ${zpool_name}/ROOT
	zfs create -o canmount=noauto -o mountpoint=/ ${zpool_name}/ROOT/ubuntu
	zfs mount ${zpool_name}/ROOT/ubuntu

	zfs create -o setuid=off ${zpool_name}/home
        zfs create -o mountpoint=/root ${zpool_name}/home/root
        zfs create -o canmount=off -o setuid=off  -o exec=off ${zpool_name}/var
	zfs create -o com.sun:auto-snapshot=false             ${zpool_name}/var/cache
	zfs create ${zpool_name}/var/log
	zfs create ${zpool_name}/var/spool
	zfs create -o com.sun:auto-snapshot=false -o exec=on  ${zpool_name}/var/tmp

	zfs create ${zpool_name}/srv
	zfs create ${zpool_name}/var/games
	zfs create ${zpool_name}/var/mail

	# zfs create -o com.sun:auto-snapshot=false \
        #     -o mountpoint=/var/lib/nfs                 ${zpool_name}/var/nfs

}

install_ubuntu() {
	chmod 1777 /mnt/var/tmp
	debootstrap ${ubuntu_version} /mnt
	zfs set devices=off ${zpool_name}
}

configure_os() {

	echo ${hostname_} > /mnt/etc/hostname
	echo "127.0.1.1		${hostname_}" >> /mnt/etc/hosts
	#tee /mnt/etc/hosts <<EOF
	#127.0.1.1       ${hostname_}
	#EOF
	
	tee /mnt/etc/apt/sources.list <<EOF
	deb http://archive.ubuntu.com/ubuntu ${ubuntu_version} main universe
	deb-src http://archive.ubuntu.com/ubuntu ${ubuntu_version} main universe

	deb http://security.ubuntu.com/ubuntu ${ubuntu_version}-security main universe
	deb-src http://security.ubuntu.com/ubuntu ${ubuntu_version}-security main universe

	deb http://archive.ubuntu.com/ubuntu ${ubuntu_version}-updates main universe
	deb-src http://archive.ubuntu.com/ubuntu ${ubuntu_version}-updates main universe
	EOF

	echo "Sieciowanie konfiguruje"
	




}

disks
clean_disks
create_zpool
create_datasets
install_ubuntu


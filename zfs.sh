#!/bin/bash -x 

#https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.04-Root-on-ZFS
# uwzglednic EFI
# https://wiki.archlinux.org/index.php/Installing_Arch_Linux_on_ZFS
#https://newspaint.wordpress.com/2017/04/09/zfs-grub-issues-on-boot/
#https://help.ubuntu.com/community/Grub2/Installing 
#http://www.thecrosseroads.net/2016/02/booting-a-zfs-root-via-uefi-on-debian/
 
zpool_name=tank0
ubuntu_version=xenial
hostname=$1

DISKS_byid=()
DISKS_dev=()

usb_drive=sd666

export ZPOOL_VDEV_NAME_PATH=YES

cleanall() {
	zfs set mountpoint=none tank0
	killall -9 nautilus
	umount -l /mnt
	zpool destroy -f tank0
}

apt_zfs() {
	apt-add-repository universe
	apt update
	apt install --yes debootstrap gdisk zfs-initramfs
}

disks_() {
	while read d_; 
	do 
		d_id=$(ls -la /dev/disk/by-id/ |grep ${d_}$ | grep 'ata-' |awk '{print $9}')
		DISKS_byid+=("/dev/disk/by-id/${d_id}")
		DISKS_dev+=("/dev/${d_}")
	done< <(lsblk -io KNAME,TYPE| grep disk | grep -v ${usb_drive} | awk '{print $1}')
}

disks() {
	size=$1
	echo "Prawilny disk size to = ${size}"
	while read d_; 
	do
		d_s_=$(lsblk -no SIZE /dev/${d_} | grep -Eo '[A-Z,0-9]+')
		if [ "${d_s_}" == "${size}" ];
		then
			echo "Dysk - ${d_} - ${d_s_} == ${size}"
			d_id=$(ls -la /dev/disk/by-id/ |grep ${d_}$ | grep 'ata-' |awk '{print $9}')
			DISKS_byid+=("/dev/disk/by-id/${d_id}")
			DISKS_dev+=("/dev/${d_}")
		else
			echo "Dysk - ${d_} - ${d_s_} == ${size}"
		fi
	done< <(lsblk -io KNAME,TYPE| grep disk | grep -v ${usb_drive} | awk '{print $1}')
}

clean_disks() {
	for d_ in ${DISKS_dev[@]};
	do
		echo "Czyszcze dysk $d_"
		sgdisk --zap-all -o ${d_}
	done
}


partition_disks() {
	for d_ in ${DISKS_dev[@]};
	do 
		#sgdisk -a1 -n2:34:2047  -t2:EF02 ${d_} 
		#parted --script ${d_} mklabel gpt mkpart non-fs 0% 2 mkpart primary 2 100% set 1 bios_grub on set 2 boot on
		#parted --script ${d_} mklabel gpt mkpart non-fs 0% 2 mkpart primary 2 3 mkpart primary 3 100% set 1 bios_grub on set 2 boot on

		sgdisk -Z -n9:-8M:0 -t9:bf07 -c9:Reserved -n2:-8M:0 -t2:ef02 -c2:GRUB -n1:0:0 -t1:bf01 -c1:ZFS ${d_}
		#sgdisk -p ${d_}
	
		#sgdisk -n 0i:0:+2M -t 0:EF02 -c 0:"bios_boot" ${d_}
		#sgdisk -n 0:0:+2M -t 0:8200 -c 0:"linux_swap" ${d_}
		#sgdisk -n 0:0:0 -t 0:8300 -c 0:"data" ${d_}

	done
}	

create_zpool() {
	SPAN=0
	SPANS=$((${#DISKS_byid[@]}/2))
	dyski=""
	echo "SPAN ${SPAN} - SPANS ${SPANS}"
	dyski=${DISKS_byid[@]}
	echo "Lista $dyski"

	while [ "${SPAN}" -lt "${SPANS}" ]
	do
 		if [ ${SPAN} -eq 0 ]
 		then
            echo "Create ${zpool_name} - ${dyski}"
  			zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt ${zpool_name} mirror `echo | awk -v span=${SPAN} -v zfsparts="${dyski}" '{ split(zfsparts,arr," "); print arr[span+span+1]"-part1" " " arr[span+span+2]"-part1" }'`
 		else
            echo "Dodaje dysk ${zpool_name} - ${dyski}"
  			zpool add -f ${zpool_name} mirror `echo | awk -v span=${SPAN} -v zfsparts="${dyski}" '{ split(zfsparts,arr," "); print arr[span+span+1]"-part1" " " arr[span+span+2]"-part1" }'`
			
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

conf_os() {

	echo ${hostname_} > /mnt/etc/hostname
	echo "127.0.1.1		${hostname_}" >> /mnt/etc/hosts
	#tee /mnt/etc/hosts <<EOF
	#127.0.1.1       ${hostname_}
	#EOF

	tee /etc/udev/rules.d/90-zfs.rules <<-EOF
	KERNEL=="sd*[!0-9]", IMPORT{parent}=="ID_*", SYMLINK+="$env{ID_BUS}-$env{ID_SERIAL}"
	KERNEL=="sd*[0-9]", IMPORT{parent}=="ID_*", SYMLINK+="$env{ID_BUS}-$env{ID_SERIAL}-part%n"
	EOF

	udevadm trigger

	ls -l /dev/disk/by-id /dev

	cp /etc/udev/rules.d/90-zfs.rules /mnt/etc/udev/rules.d/90-zfs.rules

	
	tee /mnt/etc/apt/sources.list <<-EOF
	deb http://archive.ubuntu.com/ubuntu ${ubuntu_version} main universe
	deb-src http://archive.ubuntu.com/ubuntu ${ubuntu_version} main universe

	deb http://security.ubuntu.com/ubuntu ${ubuntu_version}-security main universe
	deb-src http://security.ubuntu.com/ubuntu ${ubuntu_version}-security main universe

	deb http://archive.ubuntu.com/ubuntu ${ubuntu_version}-updates main universe
	deb-src http://archive.ubuntu.com/ubuntu ${ubuntu_version}-updates main universe
	EOF

	echo "Sieciowanie konfiguruje"
	def_iface=$(ip route get 8.8.8.8 |awk '{print $5}' )	
	def_ip=$(ip addr show dev "$def_iface" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')

	echo "$def_iface - $def_ip"
	printf "auto %s\niface %s inet dhcp" ${def_iface} ${def_iface} > /mnt/etc/network/interfaces.d/${def_iface} 

	#mount --rbind /dev  /mnt/dev
	#mount --rbind /proc /mnt/proc
	#mount --rbind /sys  /mnt/sys

	for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done

	chroot /mnt locale-gen en_US.UTF-8
	chroot /mnt echo LANG=en_US.UTF-8 > /etc/default/locale
	echo "Europe/Warsaw" > /mnt/etc/timezone 	
	chroot /mnt dpkg-reconfigure -f noninteractive tzdata
	chroot /mnt ln -s /proc/self/mounts /etc/mtab
	chroot /mnt apt update	
	chroot /mnt apt install --yes ubuntu-minimal
	chroot /mnt apt install --yes vim-tiny
	chroot /mnt apt install --yes zfsutils-linux zfs-initramfs linux-image-generic grub2-common grub-pc acpi-support vim-tiny openssh-server

	grub-probe /mnt
	for d_ in ${DISKS_dev[@]};
        do
		grub-install --root-directory=/mnt ${d_}
	done

    echo "Tworze konto admin"
    useradd -d /home/admin -m -G sudo -R /mnt -s /bin/bash admin

    echo "haslo admina"
    #chroot /mnt echo -e "TooR\nTooR" | passwd admin
    echo -e "TooR\nTooR" | chroot /mnt passwd admin

}


if [ "$1" == "apt" ];
then
	apt_zfs

elif [ "$1" == "disk" ]; then
	echo "Dyski sprawdzam"
	disks $2

	for d_ in ${DISKS_dev[@]};
	do 
		echo "Dysk - ${d_}"
	done

	
elif [ "$1" == "clean" ]; then
	for i in /dev /dev/pts /proc /sys /run; do umount -f /mnt$i; done
	cleanall
	zpool destroy -f ${zpool_name}
	disks $2
	clean_disks
else
	echo "Tworze SYSTEM!!!!"
	zpool destroy -f ${zpool_name}
	disks $1
	clean_disks
	partition_disks
    	sleep 5
	create_zpool
	create_datasets
	install_ubuntu
	conf_os
fi


#!/bin/bash

set -e

mkosi_rootfs='mkosi.rootfs'
image_dir='images'
image_mnt='mnt_image'
date=$(date +%Y%m%d)
image_name=pipa-fedora-gnome-${date}-1

# Hardcoded UUID for root filesystem (must match installer_data.json + boot cmdline)
ROOTFS_UUID="cbc96327-b5ac-413c-bc6c-fb701d576972"

if [ "$(whoami)" != 'root' ]; then
    echo "You must be root to run this script."
    exit 1
fi

mkdir -p "$image_mnt" "$mkosi_rootfs" "$image_dir/$image_name"

mkosi_create_rootfs() {
    umount_image
    mkosi clean
    rm -rf .mkosi*
    mkosi
    # not sure how/why this directory is being created by mkosi
    rm -rf $mkosi_rootfs/root/pipa-fedora-builder
}

mount_image() {
    image_path=$(find $image_dir -maxdepth 1 -type d | grep -E "/pipa-fedora-[0-9]{8}-[0-9]" | sort | tail -1)

    [[ -z $image_path ]] && echo -n "image not found in $image_dir\nexiting..." && exit
    [[ -z "$(findmnt -n $image_mnt)" ]] && mount -o loop "$image_path"/root.img $image_mnt
}

umount_image() {
    if [ ! "$(findmnt -n $image_mnt)" ]; then
        return
    fi

    [[ -n "$(findmnt -n $image_mnt)" ]] && umount $image_mnt
}

if [[ $1 == 'mount' ]]; then
    mount_image
    exit
elif [[ $1 == 'umount' ]] || [[ $1 == 'unmount' ]]; then
    umount_image
    exit
fi

make_image() {
    umount_image
    echo "## Making image $image_name"
    echo '### Cleaning up'
    rm -rf $mkosi_rootfs/var/cache/zypper/*
    rm -rf "$image_dir/$image_name/*"

    echo '### Calculating root image size'
    size=$(du -B M -s --exclude=$mkosi_rootfs/boot $mkosi_rootfs | cut -dM -f1)
    echo "### Root Image size: $size MiB"
    size=$(($size + ($size / 8) + 512))
    echo "### Root Padded size: $size MiB"
    truncate -s ${size}M "$image_dir/$image_name/root.img"

    echo '### Creating rootfs ext4 filesystem on root.img '
    MKE2FS_DEVICE_PHYS_SECTSIZE=4096 MKE2FS_DEVICE_SECTSIZE=4096 mkfs.ext4 -U "$ROOTFS_UUID" -L 'fedora_pipa' "$image_dir/$image_name/root.img"

    #echo '### Loop mounting root.img'
    #mount -o loop "$image_dir/$image_name/root.img" "$image_mnt"

    #echo '### Copying files'
    #rsync -aHAX --exclude '/tmp/*' --exclude '/boot/efi' --exclude '/efi' --exclude '/home/*' $mkosi_rootfs/ $image_mnt
    #rsync -aHAX $mkosi_rootfs/home/ $image_mnt/home
    #umount $image_mnt

    #echo '### Loop mounting rootfs root subvolume'
    #mount -o loop "$image_dir/$image_name/root.img" "$image_mnt"

    #sed -i "s/ROOTFS_UUID_PLACEHOLDER/$ROOTFS_UUID/" "$image_mnt/etc/fstab"
    #sed -i "s/ROOTFS_UUID_PLACEHOLDER/$ROOTFS_UUID/" "$image_mnt/etc/cmdline"

    #rm -f $image_mnt/etc/resolv.conf
    #echo "nameserver 1.1.1.1" > $image_mnt/etc/resolv.conf

    #echo -e '\n### Generating Initramfs'
    #arch-chroot $image_mnt dracut --force --regenerate-all --verbose

    #echo '### Reinstalling kernel'
    #local kernel_path="$(arch-chroot $image_mnt bash -c 'find /usr/lib/modules/* -maxdepth 0 -type d')"
    #arch-chroot $image_mnt kernel-install add "$(basename "$kernel_path")" "${kernel_path}/vmlinuz" --verbose

    #echo "### Enabling system services"
    ## Enable services individually to identify failures
    #for service in NetworkManager sshd systemd-resolved qbootctl.service bootmac-bluetooth; do
    #    echo "-> Enabling $service..."
    #    if ! arch-chroot $image_mnt systemctl enable "$service"; then
    #        echo "ERROR: Failed to enable $service"
    #        echo "Debug info: Checking if unit file exists for $service..."
    #        service_name="${service%.service}"
    #        ls -l "$image_mnt/usr/lib/systemd/system/$service_name.service" "$image_mnt/etc/systemd/system/$service_name.service" 2>/dev/null || echo "  Unit file not found in standard locations."
    #        exit 1
    #    fi
    #done

    #echo "-> Disabling iio-sensor-proxy..."
    #arch-chroot $image_mnt systemctl disable iio-sensor-proxy || echo "Warning: Failed to disable iio-sensor-proxy (it might not be installed)"

    #echo "### Disabling systemd-firstboot"
    #arch-chroot $image_mnt rm -f /usr/lib/systemd/system/sysinit.target.wants/systemd-firstboot.service

    #echo "### Setting permission"
    #arch-chroot $image_mnt find /etc/skel -type d -exec chmod 755 {} \;
    #arch-chroot $image_mnt find /etc/skel -type f -exec chmod 644 {} \;
    #arch-chroot $image_mnt find /var/lib/gdm -type d -exec chmod 744 {} \;
    #arch-chroot $image_mnt find /var/lib/gdm -type f -exec chmod 644 {} \;

    #echo "### Creating default user"
    #arch-chroot $image_mnt useradd -m -G audio,video,wheel user
    #echo 'user:147147' | arch-chroot $image_mnt chpasswd

    #echo -e '\n### Cleanup'
    #rm -rf $image_mnt/boot/lost+found/
    #rm -f  $image_mnt/etc/kernel/{entry-token,install.conf}
    #rm -f  $image_mnt/etc/dracut.conf.d/initial-boot.conf
    #rm -f  $image_mnt/etc/yum.repos.d/mkosi*.repo
    #rm -f  $image_mnt/var/lib/systemd/random-seed
    #rm -f $image_mnt/etc/resolv.conf
    #chroot $image_mnt ln -s ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

    #echo -e '\n### Copying boot image'
    #if ls $image_mnt/boot/boot*.img 1>/dev/null 2>&1; then
    #    cp $image_mnt/boot/boot*.img $image_dir/$image_name/boot.img
    #else
    #    echo "boot image files not found!"
    #    exit 1
    #fi

    #echo -e '\n### Unmounting rootfs subvolumes'
    #umount $image_mnt

    echo -e '\n### Compressing'
    rm -f $image_dir/"$image_name".zip
    pushd $image_dir/"$image_name" > /dev/null
    zip -r ../"$image_name".zip .
    popd > /dev/null

    echo '### Done'
}

[[ $(command -v getenforce) ]] && setenforce 0 || echo "Selinux Disabled"
mkosi_create_rootfs
make_image

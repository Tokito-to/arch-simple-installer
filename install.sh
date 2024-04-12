#!/usr/bin/env bash
# Written by Draco (tytydraco @ GitHub)

# Exit on any error
set -e

err() {
	echo -e " \e[91m*\e[39m $*"
	exit 1
}

prompt() {
	echo -ne " \e[92m*\e[39m $*"
}

# Check internet Connection
if ! ping -c1 archlinux.org
then
	err "Connect to Internet & try again!"
fi

# Configuration
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS

prompt "Boot [/dev/sda#]: "
read -r BOOT_EFI
[[ ! -b "$BOOT_EFI" ]] && err "Partition does not exist. Exiting."

prompt "Root [/dev/sda#]: "
read -r ROOT
[[ ! -b "$ROOT" ]] && err "Partition does not exist. Exiting."

# Home Partition setup
prompt "Seprate Home Partition [y/N]: "
read -r HOME_REQUIRED
if [[ "$HOME_REQUIRED" = "y" ]]
then
	prompt "Format Home Partition [y/N]: "
	read -r FORMAT_HOME
	[[ "$FORMAT_HOME" = "y" ]] && FORMAT_HOME=Yes || FORMAT_HOME=No

	prompt "Home [/dev/sda#]: "
	read -r HOME_PARTITION
	[[ ! -b "$HOME_PARTITION" ]] && err "Partition does not exist. Exiting."
fi

prompt "Filesystem [ext4]: "
read -r FILESYSTEM
FILESYSTEM=${FILESYSTEM:-ext4}
! command -v mkfs."$FILESYSTEM" &> /dev/null && err "Filesystem type does not exist. Exiting."

prompt "Timezone [Asia/Kolkata]: "
read -r TIMEZONE
TIMEZONE=${TIMEZONE:-Asia/Kolkata}
[[ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]] && err "/usr/share/zoneinfo/$TIMEZONE does not exist. Exiting."

prompt "Mirror Country [India]: "
read -r COUNTRY
COUNTRY=${COUNTRY:-India}

prompt "Hostname [archlinux]: "
read -r HOSTNAME
HOSTNAME=${HOSTNAME:-archlinux}

prompt "SSH [no]: "
read -r SSH
SSH=${SSH:-no}

prompt "Password [root]: "
read -rs PASSWORD
PASSWORD=${PASSWORD:-root}

echo ""
echo ""
printf "%-16s\t%-16s\n" "CONFIGURATION" "VALUE"
printf "%-16s\t%-16s\n" "Root & Home Filesystem:" "$FILESYSTEM"
printf "%-16s\t%-16s\n" "Boot Partition [EFI]:" "$BOOT_EFI"
printf "%-16s\t%-16s\n" "Root Partition:" "$ROOT"
printf "%-16s\t%-16s\n" "Home Partition:" "$HOME_PARTITION"
printf "%-16s\t%-16s\n" "Format Home Partition:" "$FORMAT_HOME"
printf "%-16s\t%-16s\n" "Timezone:" "$TIMEZONE"
printf "%-16s\t%-16s\n" "Mirror Country:" "$COUNTRY"
printf "%-16s\t%-16s\n" "Hostname:" "$HOSTNAME"
printf "%-16s\t%-16s\n" "Password:" "$(echo "$PASSWORD" | sed 's/./*/g')"
printf "%-16s\t%-16s\n" "SSH:" "$SSH"
echo ""
prompt "Proceed? [y/N]: "
read -r PROCEED
[[ "$PROCEED" != "y" ]] && err "User chose not to proceed. Exiting."

# Unmount for safety
if [ "$HOME_REQUIRED" = "Yes" ]
then
	umount "$HOME_PARTITION" 2> /dev/null || true
fi
umount "$BOOT_EFI" 2> /dev/null || true
umount "$ROOT" 2> /dev/null || true
 

# Timezone
timedatectl set-ntp true

# Formatting partitions
#mkfs.fat -F 32 "$BOOT_EFI"
if [[ $(blkid "$BOOT_EFI" | grep -o 'TYPE="[^"]*"' | awk -F '"' '{print $2}') != "vfat" ]]
then
	err "Unsupported Boot Partition: $BOOT_EFI. Exiting"
fi

echo "Formating Root Partition: $ROOT"
yes | mkfs."$FILESYSTEM" "$ROOT"

if [ "$FORMAT_HOME" = "Yes" ]
then
	echo "Formating Home Partition: $HOME_PARTITION"
	yes | mkfs."$FILESYSTEM" "$HOME_PARTITION"
fi

# Mount our new partition #Delay to avoid race condition
echo "Mounting Root: $ROOT..."
mount "$ROOT" /mnt
sleep 3

if [ "$HOME_REQUIRED" = "y" ]
then
	echo "Mounting Home: $HOME_PARTITION..."
  mount --mkdir "$HOME_PARTITION" /mnt/home
	sleep 3
fi

echo "Mounting Boot: $BOOT_EFI..."
mount --mkdir "$BOOT_EFI" /mnt/boot
sleep 3

# Update Mirrors
pacman -Syy #Force Update Current Package Repo
echo "Backup Current Mirrorlist"
cp -v /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

echo "Updating Mirrors"
reflector --save /etc/pacman.d/mirrorlist --country "$COUNTRY" --sort rate --latest 20 --verbose

# Enable Parallel downloading
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf
sed -i "/Color/"'s/^#//' /etc/pacman.conf

# Initialize base system, kernel, and firmware
pacstrap -K /mnt base linux linux-firmware

# Setup fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot commands
(
	# Time and date configuration
	echo "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
	echo "hwclock --systohc"

	# Setup locales
	echo "sed -i \"s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/\" /etc/locale.gen"
	echo "locale-gen"
	echo "echo \"LANG=en_US.UTF-8\" > /etc/locale.conf"

	# Setup hostname and hosts file
	echo "echo \"$HOSTNAME\" > /etc/hostname"
	echo "echo -e \"127.0.0.1\tlocalhost\" >> /etc/hosts"
	echo "echo -e \"::1\t\tlocalhost\" >> /etc/hosts"
	echo "echo -e \"127.0.1.1\t$HOSTNAME\" >> /etc/hosts"
	echo "echo -e \"$PASSWORD\n$PASSWORD\" | passwd"

	# Install microcode
	echo "pacman -Sy --noconfirm amd-ucode intel-ucode"

	# Install GRUBv2 as a removable drive (universal across hw)
	echo "pacman -Sy --noconfirm grub efibootmgr"

	# Install GRUBv2
	echo "pacman -Sy --noconfirm --needed grub efibootmgr"
	echo "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=\"ArchLinux\" --recheck"
	echo "grub-mkconfig -o /boot/grub/grub.cfg"

	# Install and enable NetworkManager on boot
	echo "pacman -Sy --noconfirm networkmanager iwd"
	echo "systemctl enable NetworkManager"
	
	# Launch Bluetoothd on boot
	echo "pacman -Sy --noconfirm --needed bluez"
	echo "systemctl enable bluetooth"

	# Enable SSH server out of the box
	if [[ "$SSH" == "yes" ]]
	then
		echo "pacman -Sy --noconfirm openssh"
		echo "sed -i \"s/#PermitRootLogin prohibit-password/PermitRootLogin yes/\" /etc/ssh/sshd_config"
		echo "systemctl enable sshd"
	fi
) | arch-chroot /mnt

echo "Basic ArchLinux Install completed."

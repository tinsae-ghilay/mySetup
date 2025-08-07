#!/bin/zsh

# --- Arch Linux Hyprland Installation Script ---
# This script automates the post-manual-partitioning and internet connection steps
# for installing Arch Linux with Hyprland using systemd-boot and greetd with Regreet.

# --- PRE-INSTALLATION CHECKS (Run these manually before executing this script) ---
# 1. Boot Arch Linux Live ISO.
# 2. Partition your disks (e.g., using fdisk, cfdisk, or parted).
# 3. Format your partitions (e.g., mkfs.fat for EFI, mkfs.ext4 for root/home).
#    Make sure your EFI partition is formatted FAT32.
# 4. Mount your partitions:
#    Example:
#    mount /dev/sda2 /mnt         # Mount root partition
#    mkdir /mnt/boot              # Create /mnt/boot directory
#    mount /dev/sda1 /mnt/boot    # Mount EFI partition to /mnt/boot (crucial for systemd-boot)
#    # If you have a separate /home:
#    # mkdir /mnt/home; mount /dev/sda3 /mnt/home
# 5. Connect to the internet (e.g., wifi-menu or iwctl).
echo "the following steps need to be done first"
echo "1. Drive partitioned and mounted"
echo "2. Multilib enabled for lib32 Nvidia utils, and ofcourse, connected to internet"
echo "Start installation script? y (lower case) case sensitive for yes, anything else for no"
read response
# if response is yes
if [ "$response" != "y" ]; then
    echo "ok, exiting."
    exit 0
fi
# Check if reflector is installed
if ! command -v reflector >/dev/null 2>&1; then
    echo "reflector is not installed. Installing..."
    
    # since this is going to be used in a ive env. no need and cant use sudo
    pacman -Sy --noconfirm reflector

    # You can handle errors if the install fails
    if [ $? -ne 0 ]; then
        echo "Failed to install reflector"
        exit 1
    fi
else
    echo "reflector is already installed."
fi

reflector --country 'Austria' --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy
# ---------------------------------------------------------------------------------

echo "--- Starting Arch Linux Hyprland Installation Script with systemd-boot and greetd ---"

echo "Installing base system and essential packages..."

# Core packages for a functioning Arch system with initial drivers and networking.
PACSTRAP_PKGS=(
    base linux linux-firmware intel-ucode sof-firmware \
    mesa nvidia nvidia-utils lib32-nvidia-utils vulkan-intel intel-media-driver \
    networkmanager nm-connection-editor network-manager-applet \
    sudo dosfstools \
    man-db man-pages texinfo \
    neovim nano git gcc gdb efibootmgr
)

pacstrap /mnt "${PACSTRAP_PKGS[@]}" || { echo "Pacstrap failed. Exiting."; exit 1; }

echo "Base system and essential packages installed. copying mirrors to new system"

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
echo "mirror lists copied to new system"

# Generate fstab ---
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || { echo "fstab generation failed. Exiting."; exit 1; }
echo "fstab generated."

echo "please provide path to root partition"
read PATH

curl https://raw.githubusercontent.com/tinsae-ghilay/mySetup/refs/heads/main/setup.sh -o /mnt/setup.sh

# Chroot into the new system and continue configuration ---
echo "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF_CHROOT
    echo "Inside chroot. Continuing configuration..."
	chmod u+x setup.sh
 	./serup.sh "$PATH"
    
EOF_CHROOT

# --- 4. Final Steps (Outside Chroot) ---
echo "--- Arch Linux Hyprland Installation COMPLETE! ---"
echo "You can now unmount your partitions and reboot into your new system."
echo "Example commands: umount -R /mnt; reboot"
echo ""
echo "--- Post-Reboot Steps (Run these as your NEW USER after first login) ---"
echo "1. Log in with your new user in the TTY (or the graphical greetd if it launches)."
echo "   - If greetd launches but you can't log in, switch to TTY2-7 (Ctrl+Alt+F2-F7) and login there."

echo "should we unmount drives and reboot?"
read response

if [ "$response" == "y" ]; then
	umount -R /mnt
	echo "unmounted, now rebooting"
	reboot
fi


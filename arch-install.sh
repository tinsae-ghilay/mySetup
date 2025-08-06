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

# now host, root and user data
echo "please provide host name"
read HOSTNAME_INPUT

# user name
echo "please provide user name"
read USERNAME_INPUT

echo "shoul there be root password? y for yes"
read response

# root password
if [ "$response" = "y" ]; then
	while true; do
		echo "Enter desired root password: " 
		read -s ROOT_PASS
		echo "Confirm root password: " 
		read -s ROOT_PASS_CONFIRM
		if [[ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" ]]; then
  	  		break
  		else
  	  		echo "Passwords do not match. Please try again."
  		fi
	done
fi

# user password
while true; do
	echo "Enter password for user '$USERNAME_INPUT': " 
	read -s USER_PASS
	echo "Confirm user password: " 
	read -s USER_PASS_CONFIRM
  	if [[ "$USER_PASS" == "$USER_PASS_CONFIRM" ]]; then
    		break
  	else
    		echo "Passwords do not match. Please try again."
  	fi
done

echo "--- Starting Arch Linux Hyprland Installation Script with systemd-boot and greetd ---"

# --- 1. Pacstrap the base system and core packages ---
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

# --- 2. Generate fstab ---
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || { echo "fstab generation failed. Exiting."; exit 1; }
echo "fstab generated."

# --- 3. Chroot into the new system and continue configuration ---
echo "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF_CHROOT
    echo "Inside chroot. Continuing configuration..."
    
    # enable parallel downloads
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    # --- 3.1. System Locale, Time, and Keyboard Layout ---
    echo "Setting system locale, timezone, and keyboard layout..."
    # Set locale to en_GB.UTF-8
    echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=en_GB.UTF-8" > /etc/locale.conf
    echo "KEYMAP=de" > /etc/vconsole.conf # Console keyboard layout

    # Set timezone to Europe/Vienna (CET)
    ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
    hwclock --systohc # Set hardware clock to system time

    echo "System locale, timezone, and keyboard layout set."

    # --- 3.2. Hostname ---
    echo "$HOSTNAME_INPUT" > /etc/hostname
    echo "127.0.0.1    localhost" >> /etc/hosts
    echo "::1          localhost" >> /etc/hosts
    echo "127.0.1.1    $HOSTNAME_INPUT.localdomain $HOSTNAME_INPUT" >> /etc/hosts
    echo "Hostname set to $HOSTNAME_INPUT."

    # --- 3.3. User Creation and Sudoers 
			# Check if a root password was provided
			echo "Setting root password" 
    if [[ -n "$ROOT_PASS" ]]; then
        echo "root:$ROOT_PASS" | chpasswd || { echo "Root password setup failed. Exiting chroot."; exit 1; }
        echo "Root password set."
    else
        echo "Root password was not provided. Skipping."
    fi
    # --- 3.4 user password
    # Create user and set password using chpasswd
    useradd -m -G wheel,lp,power "$USERNAME_INPUT" || { echo "User creation failed. Exiting chroot."; exit 1; }
    echo "$USERNAME_INPUT:$USER_PASS" | chpasswd || { echo "User password setup failed. Exiting chroot."; exit 1; }
    echo "User $USERNAME_INPUT created and password set."

    # Uncomment wheel group in sudoers file to allow sudo access
    sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers || { echo "Sudoers modification failed. Exiting chroot."; exit 1; }
    echo "User $USERNAME_INPUT created and added to sudoers."

    # --- 3.5. Enable Multilib ---
    echo "Enabling Multilib repository..."
    # Uncomment the [multilib] section in pacman.conf
    sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf || { echo "Multilib enablement failed. Exiting chroot."; exit 1; }
    pacman -Sy # Sync package databases after enabling multilib
    echo "Multilib enabled. and synced"

    # --- 3.6. Install Hyprland and all other packages ---
    echo "Installing Hyprland and all specified packages..."
    
    # hyprecosystem
    pacman -S --needed --noconfirm hyprland hypridle hyprlock hyprpaper hyprshot hyprpolkitagent || { echo "Hyperecho apps installation failed. Exiting chroot."; exit 1; }
    
    # xdg desktop portal
    pacman -S --needed --noconfirm xdg-desktop-portal-hyprland xdg-desktop-portal-gtk || { echo "XDG istall failed."; exit 1; }
    
    # qt wayland support
    pacman -S --needed --noconfirm qt5-wayland qt6-wayland || { echo "QT packages install failed. Exiting chroot."; exit 1; }
    
    # audio
    pacman -S --needed --noconfirm pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack || { echo "Installing audio tools failed. Exiting chroot."; exit 1; }
    
    # msic needed
    pacman -S --needed --noconfirm swaync kitty wofi firefox code spotify-launcher waybar wl-clip-persist || { echo "Error installing sway kitty and co. Exiting chroot."; exit 1; }
    
    # print bluetooth and brightness services
    pacman -S --needed --noconfirm brightnessctl cups cups-filters gutenprint bluez bluez-utils blueman bluez-cups || { echo "Error installing print, bluetooth and brightness control failsed. Exiting chroot."; exit 1; }
    
    # gnome apps
    pacman -S --needed --noconfirm loupe gnome-text-editor nautilus nwg-look gnome-keyring || { echo "Installing gnome+ apps failed. Exiting chroot."; exit 1; }
    
    # android and ntfs support
    pacman -S --needed --noconfirm ntfs-3g android-udev gvfs scrcpy || { echo "error installing android tools. Exiting chroot."; exit 1; }
    
    # fonts
    pacman -S --needed --noconfirm ttf-bitstream-vera ttf-croscore ttf-dejavu noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ttf-liberation ttf-roboto ttf-opensans cantarell-fonts gnu-free-fonts ttf-gentium-plus ttf-linux-libertine tex-gyre-fonts adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts ttf-anonymous-pro ttf-fira-code ttf-hack ttf-jetbrains-mono adobe-source-code-pro-fonts xorg-fonts-100dpi xorg-fonts-75dpi xorg-fonts-misc xorg-fonts-cyrillic xorg-fonts-type1 || { echo "Error installing fonts. Exiting chroot."; exit 1; }
    
    # X11 support
    pacman -S --needed --noconfirm xorg-xwayland || { echo "error installing xwayland support. Exiting chroot."; exit 1; }
    
    # Display Manager (greetd with Regreet)
    pacman -S --needed --noconfirm greetd greetd-tuigreet || { echo "Error installing greetd. Exiting chroot."; exit 1; }


    echo "all packages installed."

    # --- 3.7. Enable Services ---
    echo "Enabling essential services..."
    systemctl enable NetworkManager.service
    systemctl enable bluetooth.service
    systemctl enable cups.service
    systemctl enable greetd.service

    # Enable PipeWire user services (these will start automatically on first graphical login)
    # systemctl enable pipewire pipewire-pulse wireplumber

    echo "Services enabled."

    # --- 3.8. systemd-boot Bootloader Installation ---
    echo "Installing systemd-boot bootloader..."
    bootctl install || { echo "bootctl install failed. Exiting chroot."; exit 1; }

    # Configure loader.conf for systemd-boot
    echo "Configuring loader.conf..."
    cat <<EOL_LOADER > /boot/loader/loader.conf
default  arch
timeout  3
console-mode max # For fullscreen console
editor   yes      # Allow editing kernel parameters at boot
EOL_LOADER

    # Get UUID of the root partition for boot entries
    ROOT_UUID=$(blkid -s UUID -o value "$(findmnt -no SOURCE /)" | head -n 1)
    if [ -z "$ROOT_UUID" ]; then
        echo "Could not find root partition UUID. Cannot create boot entries. Exiting chroot."
        exit 1
    fi

    echo "Creating arch.conf and fallback-arch.conf..."
    # Create arch.conf (standard boot entry)
    mkdir -p /boot/loader/entries/
    cat <<EOL_ARCH > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw vga=current loglevel=3 rd.udev.log_level=3 nvidia_drm.modset=1 fsck.mode=skip quiet splash
EOL_ARCH

    # Create fallback-arch.conf (fallback boot entry)
    cat <<EOL_FALLBACK > /boot/loader/entries/fallback-arch.conf
title   Arch Linux (Fallback)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=$ROOT_UUID rw vga=current loglevel=3 rd.udev.log_level=3 nvidia_drm.modset=1 fsck.mode=skip quiet splash
EOL_FALLBACK

    echo "systemd-boot configured with arch.conf and fallback-arch.conf."

    # --- 3.9. Configure greetd and TuiGreet ---
    echo "Configuring greetd and TuiGreet..."

    # Create greetd config directory if it doesn't exist
    mkdir -p /etc/greetd

    # Create /etc/greetd/config.toml (greetd's main config)
    cat <<EOL_GREETD_CONFIG > /etc/greetd/config.toml
[terminal]
vt = 7 # Common for graphical greeters, ensures a clean VT

[default_session]
command = "tuigreet --time --asterisks --cmd Hyprland"
user = "greeter"
EOL_GREETD_CONFIG

# copying dot files
echo "copying config files"
git clone https://github.com/tinsae-ghilay/mySetup.git /home/$USERNAME_INPUT/.config && echo "---- DONE CLONING DOT FILES! ----" || { echo "looks like config will have to be cloned manualy !"; }
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
    exit
	umount -R /mnt
	echo "unmounted, now rebooting"
	reboot
fi


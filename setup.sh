#!/bin/bash
echo "Inside chroot. Continuing configuration..."

# now host name, root and user data
echo "please provide host name"
read HOSTNAME_INPUT

# root password
echo "should there be root password? y for yes (recomended no, thus disabling root login"
read response
if [ "$response" = "y" ]; then
	passwd
fi

    
# enable parallel downloads
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# System Locale, Time, and Keyboard Layout ---
echo "Setting system locale, timezone, and keyboard layout..."
# Set locale to en_GB.UTF-8
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# may also need to be interactive, since I may have diferent layout on some laptops
echo "Enter keyboard map example de"
read KEYMAP
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf # Console keyboard layout

# Set timezone to Europe/Vienna (CET)
echo "enter time zone, eg. Europe/Vienna"
read REGION
ln -sf /usr/share/zoneinfo/"$REGION" /etc/localtime
hwclock --systohc # Set hardware clock to system time

echo "System locale, timezone, and keyboard layout set."

# Hostname ---
echo "$HOSTNAME_INPUT" > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $HOSTNAME_INPUT.localdomain $HOSTNAME_INPUT" >> /etc/hosts
echo "Hostname set to $HOSTNAME_INPUT."

# User Creation and Sudoers 
  # Check if a root password was provided
  echo "Setting root password" 
if [[ -n "$ROOT_PASS" ]]; then
    echo "root:$ROOT_PASS" | chpasswd || { echo "Root password setup failed. Exiting chroot."; exit 1; }
    echo "Root password set."
else
    echo "Root password was not provided. Skipping."
fi

# Create user and set password
echo "please provide user name"
read USERNAME_INPUT
useradd -m -G wheel,lp,power "$USERNAME_INPUT" || { echo "User creation failed. Exiting chroot."; exit 1; }
passwd "$USERNAME_INPUT
echo "User $USERNAME_INPUT created and password set."

# allow sudo access to user
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers || { echo "Sudoers modification failed. Exiting chroot."; exit 1; }
echo "User $USERNAME_INPUT created and added to sudoers."

#  Enable Multilib ---
echo "Enabling Multilib repository..."
# Uncomment the [multilib] section in pacman.conf
sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf || { echo "Multilib enablement failed. Exiting chroot."; exit 1; }
pacman -Sy # Sync package databases after enabling multilib
echo "Multilib enabled. and synced"

# Install Hyprland and all other packages ---
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
pacman -S --needed --noconfirm loupe gnome-text-editor nautilus nwg-look gnome-keyring evince || { echo "Installing gnome+ apps failed. Exiting chroot."; exit 1; }

# android and ntfs support
pacman -S --needed --noconfirm ntfs-3g android-udev gvfs scrcpy || { echo "error installing android tools. Exiting chroot."; exit 1; }

# fonts
pacman -S --needed --noconfirm ttf-dejavu noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-roboto cantarell-fonts ttf-fira-code ttf-hack nerd-fonts-jetbrains-mono adobe-source-code-pro-fonts || { echo "Error installing fonts."; }

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
timeout  1
console-mode keep
editor true
EOL_LOADER

# Get UUID of the root partition for boot entries
ROOT_UUID=$(blkid -s UUID -o value "$1" | head -n 1)
# make sure we have it
if [ -z "$ROOT_UUID" ]; then
        echo "Could not find root partition UUID. would you like to enter it manually?"
	read answer
 	if [ "$answer" != "y" ]; then 
        	exit 1
	else
 		while true; do
   			echo "provide the root partition address. eg. 'dev/sdx2'"
   			read id
      			ROOT_UUID=$(blkid -s UUID -o value "$id" | head -n 1)
      			if [ ! -z "$ROOT_UUID" -a "$ROOT_UUID" != " " ]; then
			        break
			fi
	fi
else
	echo "Root UUID ($ROOT_UUID) successfully fetched."
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
# just incase, setting ownership of config files to user
chown -cR $USERNAME_INPUT /home/$USERNAME_INPUT/.config

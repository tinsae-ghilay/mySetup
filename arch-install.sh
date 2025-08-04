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
echo "Start installation script? Y not case sensitive for yes, anything else for no"
read response
# convert to lower case
response = ${response,,}
if [[ "$response" != "y"]] ; then
    echo "ok, exiting."
    exit 0
if 
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
# ---------------------------------------------------------------------------------

# Ensure the script is run as root
# if [ "$(id -u)" -ne 0 ]; then
#    echo "This script must be run as root. Please use sudo."
#    exit 1
# fi

echo "--- Starting Arch Linux Hyprland Installation Script with systemd-boot and greetd ---"

# --- 1. Pacstrap the base system and core packages ---
echo "Installing base system and essential packages..."

# Core packages for a functioning Arch system with initial drivers and networking.
# We are using xf86-video-nouveau for NVIDIA for potential suspend benefits.
PACSTRAP_PKGS=(
    base linux linux-firmware intel-ucode sof-firmware\
    mesa nvidia nvidia-utils lib32-nvidia-utils vulkan-intel intel-media-driver \
    networkmanager nm-connection-editor network-manager-applet \
    sudo dosfstools \
    man-db man-pages texinfo \
    neovim nano git gcc gdb efibootmgr # efibootmgr is needed by bootctl
)

pacstrap /mnt "${PACSTRAP_PKGS[@]}" || { echo "Pacstrap failed. Exiting."; exit 1; }

echo "Base system and essential packages installed."

# --- 2. Generate fstab ---
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || { echo "fstab generation failed. Exiting."; exit 1; }
echo "fstab generated."

# --- 3. Chroot into the new system and continue configuration ---
echo "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF_CHROOT
    echo "Inside chroot. Continuing configuration..."

    # --- 3.1. System Locale, Time, and Keyboard Layout ---
    echo "Setting system locale, timezone, and keyboard layout..."
    # Set locale to en_GB.UTF-8
    echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=en_GB.UTF-8" > /etc/locale.conf
    echo "KEYMAP=de-latin1" > /etc/vconsole.conf # Console keyboard layout

    # Set timezone to Europe/Vienna (CET)
    ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
    hwclock --systohc # Set hardware clock to system time

    echo "System locale, timezone, and keyboard layout set."

    # --- 3.2. Hostname ---
    read -p "Enter desired hostname: " HOSTNAME_INPUT
    echo "$HOSTNAME_INPUT" > /etc/hostname
    echo "127.0.0.1    localhost" >> /etc/hosts
    echo "::1          localhost" >> /etc/hosts
    echo "127.0.1.1    $HOSTNAME_INPUT.localdomain $HOSTNAME_INPUT" >> /etc/hosts
    echo "Hostname set to $HOSTNAME_INPUT."

    # --- 3.3. Root Password ---
    echo "Setting root password..."
    passwd || { echo "Root password setup failed. Exiting chroot."; exit 1; }

    # --- 3.4. User Creation and Sudoers ---
    read -p "Enter desired username: " USERNAME_INPUT
    # Add user to wheel (sudo), lp (printers), and power (suspend/shutdown) groups
    useradd -m -G wheel,lp,power "$USERNAME_INPUT" || { echo "User creation failed. Exiting chroot."; exit 1; }
    echo "Setting password for user $USERNAME_INPUT..."
    passwd "$USERNAME_INPUT" || { echo "User password setup failed. Exiting chroot."; exit 1; }

    # Uncomment wheel group in sudoers file to allow sudo access
    sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //g' /etc/sudoers || { echo "Sudoers modification failed. Exiting chroot."; exit 1; }
    echo "User $USERNAME_INPUT created and added to sudoers."

    # --- 3.5. Enable Multilib ---
    echo "Enabling Multilib repository..."
    # Uncomment the [multilib] section in pacman.conf
    sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf || { echo "Multilib enablement failed. Exiting chroot."; exit 1; }
    pacman -Sy # Sync package databases after enabling multilib
    echo "Multilib enabled."

    # --- 3.6. Install Hyprland and all other packages ---
    echo "Installing Hyprland and all specified packages..."
    FULL_INSTALL_PKGS=(
        hyprland hypridle hyprlock hyprpaper \
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
        qt5-wayland qt6-wayland \
        pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack \
        dunst \
        kitty \
        hyprpolkitagent \
        wofi wlogout\
        waybar \
        wl-clip-persist \
        hyprshot \
        brightnessctl \
        loupe \
        # Printer support
        cups cups-filters gutenprint \
        # Bluetooth support
        bluez bluez-utils blueman \
        # Bluetooth for CUPS (optional, for Bluetooth printers)
        bluez-cups \
        # Font packages (your specified list)
        ttf-bitstream-vera ttf-croscore ttf-dejavu noto-fonts noto-fonts-cjk \
        noto-fonts-emoji noto-fonts-extra ttf-liberation ttf-roboto ttf-opensans \
        cantarell-fonts gnu-free-fonts ttf-gentium-plus ttf-linux-libertine \
        tex-gyre-fonts adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts \
        ttf-anonymous-pro ttf-fira-code ttf-hack ttf-jetbrains-mono \
        adobe-source-code-pro-fonts xorg-fonts-100dpi xorg-fonts-75dpi \
        xorg-fonts-misc xorg-fonts-cyrillic xorg-fonts-type1 \
        # NTFS support
        ntfs-3g \
        # Android/MTP support
        android-udev gvfs scrcpy\
        # XWayland Support (essential for running X11 apps on Wayland)
        xorg-xwayland \
        # Display Manager (greetd with Regreet)
        greetd tuigreet 
    )

    pacman -S --needed "${FULL_INSTALL_PKGS[@]}" || { echo "Package installation failed. Exiting chroot."; exit 1; }
    echo "Hyprland and other packages installed."

    # --- 3.7. Enable Services ---
    echo "Enabling essential services..."
    systemctl enable NetworkManager.service
    systemctl enable bluetooth.service
    systemctl enable cups.service
    systemctl enable greetd.service

    # Enable PipeWire user services (these will start automatically on first graphical login)
    systemctl enable pipewire pipewire-pulse wireplumber

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

EOF_CHROOT

# --- 4. Final Steps (Outside Chroot) ---
echo "--- Arch Linux Hyprland Installation COMPLETE! ---"
echo "You can now unmount your partitions and reboot into your new system."
echo "Example commands: umount -R /mnt; reboot"
echo ""
echo "--- Post-Reboot Steps (Run these as your NEW USER after first login) ---"
echo "1. Log in with your new user in the TTY (or the graphical greetd if it launches)."
echo "   - If greetd launches but you can't log in, switch to TTY2-7 (Ctrl+Alt+F2-F7) and login there."
echo "2. Clone your dotfiles repository to setup your Hyprland configuration:"
echo "   mkdir -p ~/.config"
echo "   git clone https://github.com/yourusername/your-dotfiles.git ~/dotfiles" # Replace with your actual repo URL
echo ""
echo "3. Copy or symlink your configurations from ~/dotfiles/ to their correct locations."
echo "   - For Hyprland config: cp -r ~/dotfiles/.config/hypr ~/.config/"
echo "   - For Waybar config: cp -r ~/dotfiles/.config/waybar ~/.config/"
echo "   - For general dotfile management, consider GNU Stow (sudo pacman -S stow) from ~/dotfiles."
echo ""
echo "4. After applying your dotfiles, start Hyprland from a TTY (if not auto-launched by greetd on login):"
echo "   Hyprland"
echo "   - Ensure 'exec-once = blueman-applet' and other desired autostart commands are in your ~/.config/hypr/hyprland.conf."
echo ""
echo "5. **CRITICAL: Customize Regreet's appearance!** The default `regreet.css` is basic."
echo "   - You will need to edit `/etc/greetd/regreet.css` to match your Hyprlock aesthetic."
echo "   - You may also need to install a background image to `/usr/share/backgrounds/` and update `regreet.toml`."
echo "   - Useful tool: `GTK_DEBUG=interactive regreet` (run from a TTY) to inspect Regreet's widgets."
echo ""
echo "6. Consider installing an AUR helper (like yay or paru) if you need more packages, e.g., 'all-repository-fonts' if you want even more fonts than those installed from official repos."
echo "   Example for yay: git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si; cd ..; rm -rf yay"
echo "should we unmount drives and reboot?"
read response
respnse = ${respnse,,}
if [[ "$response" == "y" ]] ;
then
umount /mnt/boot
umount /mnt
echo "unmounted, now rebooting"
reboot
fi

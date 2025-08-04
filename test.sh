#!/bin/bash


echo "yes or no"
read response

if [[ "${response,,}" != "y" ]] ; then
	echo "answered who cares!"
else
	echo "answered yes"
fi

echo "trying reflector"

# Check if reflector is installed
if ! command -v reflector >/dev/null 2>&1; then
    echo "reflector is not installed. Installing..."
    
    # Assuming you're on an Arch-based system
    sudo pacman -Sy --noconfirm reflector

    # You can handle errors if the install fails
    if [ $? -ne 0 ]; then
        echo "Failed to install reflector"
        exit 1
    fi
else
    echo "reflector is already installed."
fi


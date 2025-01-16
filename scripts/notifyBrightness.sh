#!/bin/bash
# changeBrightness

# Arbitrary but unique message tag (same tag for all brightness changes)
msgTag="BrightnessChange"

# Get the current brightness level
brightness=$(brightnessctl g)

# Maximum brightness value (adjust if necessary)
max_brightness=19200

# Calculate 10% of the maximum brightness (minimum allowed brightness)
min_brightness=$((max_brightness * 10 / 100))

# Step 2: Add the command line argument to the current brightness
# The argument can be positive or negative (e.g., 5 or -5)
brightness_change=$1
new_brightness=$((brightness + brightness_change))

# Step 3: Check if the new brightness is below 10% of the max brightness
if [[ "$new_brightness" -lt "$min_brightness" ]]; then
    # Set to minimum allowed brightness
    new_brightness=$min_brightness
elif [[ "$new_brightness" -gt "$max_brightness" ]]; then
    # Set to maximum allowed brightness
    new_brightness=$max_brightness
fi

# Set the new brightness and notify the user
brightnessctl s "$new_brightness"
percent=$(( new_brightness * 100 / max_brightness ))
# Send notification with a fixed identifier to avoid stacking
dunstify -a "changeBrightness" -u low -i display-brightness-symbolic -h string:x-dunst-stack-tag:"$msgTag" -h int:value:"$percent" "Brightness: ${percent}%"

# Play the brightness changed sound
canberra-gtk-play -i audio-volume-change -d "changeBrightness"


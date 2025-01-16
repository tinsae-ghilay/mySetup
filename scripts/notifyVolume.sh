#!/bin/bash
# changeVolume

# Arbitrary but unique message tag
msgTag="System"

# Change the volume using alsa(might differ if you use pulseaudio)
amixer -q -D pulse sset Master $@

# Query amixer for the current volume and whether or not the speaker is muted
volume="$(amixer sget Master | awk -F"[][]" '/Left:/ { print $2 }')"
mute="$(amixer sget Master | tail -1 | awk '{print $6}' | sed 's/[^a-z]*//g')"
if [[ $volume == 0 || "$mute" == "off" ]]; then
    # Show the sound muted notification
    dunstify -a "changeVolume" -u low -i audio-volume-muted-symbolic -h string:x-dunst-stack-tag:$msgTag "Volume muted" 
else
    # Show the volume notification
    dunstify -a "changeVolume" -u low -i audio-volume-symbolic -h string:x-dunst-stack-tag:$msgTag \
    -h int:value:"$volume" "Volume: ${volume}"
fi

# Play the volume changed sound
canberra-gtk-play -i audio-volume-change -d "changeVolume"

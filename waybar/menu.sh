#!/bin/bash

# if wofi is running, we dont want to relaunch it
# hence we do nothing

if pgrep -x "wofi" < /dev/null; then
    killall wofi
else
    hyprctl dispatch exec wofi;
fi

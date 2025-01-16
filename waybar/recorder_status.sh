#!/bin/bash

# Check if wf-recorder is running
if pgrep wf-recorder > /dev/null; then
    # If wf-recorder is running, return JSON with the red icon and recording status
    echo '{"text": "Recording", "tooltip": "Recording in progress", "class": "active", "icon": ""}'  # Change icon as desired
else
    # If wf-recorder is not running, return JSON with an empty state
    echo '{"text": "", "tooltip": "Not recording", "class": "inactive", "icon": ""}'
fi


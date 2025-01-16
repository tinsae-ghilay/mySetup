#!/bin/sh
# Screen recording setup for hypr-way-land
ID="screen_capture"

# JSON object to return when actively recording and when idle
ACTIVE="{\"text\": \"\", \"tooltip\": \"recording\", \"class\": \"active\"}"
IDLE="{\"text\": \"\", \"tooltip\": \"done\", \"class\": \"idle\"}"

# json result that'll be returned
RESULT=""

DATE=$(date +%s)
# File name and icon for notification
FILE_NAME=~/Videos/Screen/$DATE.mp4

# Handle different cases for screenshots
if [[ "$@" =~ "snap" ]]; then
    FILE_NAME=~/Pictures/Screen/$DATE.png
fi

MONITOR=0  # Default monitor ID

# Function to get the monitor number based on user input
get_monitor_id() {
    # Use hyprctl to list available monitors
    echo "Available monitors:"
    hyprctl monitors | grep "ID"

    # Prompt the user to select a monitor
    echo "Enter the number of the monitor you want to record from:"
    read monitor_number

    # Validate input (ensure it is a number)
    if ! [[ "$monitor_number" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid number."
        return 1
    fi
    
    MONITOR=$monitor_number  # Increment monitor number (fix string issue)
}


# Function to check if there are multiple monitors
get_monitor() {
    # Get the number of available monitors by counting lines in the output of hyprctl
    monitor_count=$(hyprctl monitors | grep -c "ID")

    # Check if there is more than one monitor
    if [ "$monitor_count" -gt 1 ]; then
        get_monitor_id  # Prompt for monitor selection
    else
    	echo "no extra monitors detected"
    fi
}

# Call the get_monitor function to check if there are multiple monitors
get_monitor

MONITOR_NAME=$(hyprctl monitors | grep "ID" | sed -n "${MONITOR}p" | awk '{print $2}')

echo $MONITOR_NAME

# Switch between required tasks
case $@ in
    "snap screen") # screenshot the whole screen
        if [ "$MONITOR" -gt 0 ]; then
            grim -o "$MONITOR_NAME" $FILE_NAME  # Capture from selected monitor
        else
            grim $FILE_NAME  # Capture from all screens if no selection
        fi
        RESULT=$IDLE
        ;;

    "snap region") # capture a selected area. slurp enables that
    	if [ "$MONITOR" -gt 0 ]; then
            slurp | grim -o "$MONITOR_NAME" $FILE_NAME
         else
	    slurp | grim -g - $FILE_NAME
        fi
        RESULT=$IDLE
        ;;

    "record screen") # record the entire screen
        echo "screen recording"
        if [ "$MONITOR" -gt 0 ]; then
            wf-recorder -f $FILE_NAME -o "$MONITOR_NAME" &  # Record from selected monitor
        else
            wf-recorder -f $FILE_NAME &  # Record from all monitors if no selection
        fi
        ACTION=$(dunstify --action="stopRecording,stop" -t 0 "Recording in progress. Click to stop.")
        RESULT=$ACTIVE
        echo "recording ..."

        # Wait for the stop action from the notification (poll dunstctl)
        if [[ "$ACTION" == "stopRecording" ]]; then
            echo "Stop recording action clicked."
            pkill wf-recorder
            echo "stopped"
        fi
        ;;

    "record region") # record a selected region of screen
        echo "region recording"
        if [ "$MONITOR" -gt 0 ]; then
		wf-recorder -f $FILE_NAME -o "$MONITOR_NAME" -g "$(slurp)" &
        else
        	wf-recorder -f $FILE_NAME "$(slurp)" &
        fi
        ACTION=$(dunstify --action="stopRecording,stop" -t 0 "Recording in progress. Click to stop.")
        RESULT=$ACTIVE
        echo "recording ..."

        if [[ "$ACTION" == "stopRecording" ]]; then
            echo "Stop recording action clicked."
            pkill wf-recorder
            echo "stopped"
        fi
        ;;

    *)
        pkill wf-recorder
        RESULT=$IDLE
        ;;
esac

# Output the JSON result
echo $RESULT

exit 0


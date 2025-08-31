#!/usr/bin/env bash

LOG_DIR="~/assistant/Nextcloud/Notes/journal"
LOG_FILE="$LOG_DIR/$(date "+%Y-%m-%d")"

# Create log directory and file if they don't exist
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# Get last 10 unique activities as suggestions with time (HH:MM only)
suggestions=""
if [ -s "$LOG_FILE" ]; then
    suggestions=$(tail -20 "$LOG_FILE" | while read line; do
        # Extract time (HH:MM) and activity from each line
        time_part=$(echo "$line" | cut -d' ' -f2 | cut -d':' -f1-2)
        activity_part=$(echo "$line" | cut -d' ' -f4-)
        echo "$time_part - $activity_part"
    done | sort -t: -k1,1n -k2,2n | uniq -s8 | tail -10)
fi

# Show rofi with suggestions
activity=$(echo "$suggestions" | rofi -dmenu -i -p "Current activity:" -lines 10)

# If user selected an entry with time (contains " - "), extract just the activity part
if [[ "$activity" == *" - "* ]]; then
    activity=$(echo "$activity" | sed 's/^[0-9:]*[[:space:]]*-[[:space:]]*//')
fi

if [ -n "$activity" ]; then
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp - $activity" >> "$LOG_FILE"
    notify-send "Activity Logged" "$activity"
fi

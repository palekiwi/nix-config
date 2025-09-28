{ pkgs, ... }:

pkgs.writeShellScriptBin "dmenu_activity_log" ''
  LOG_DIR="$HOME/ava-ygt/Nextcloud/Notes/ygt/log"
  LOG_FILE="$LOG_DIR/$(date "+%Y-%m-%d").md"

  # Create log directory and file if they don't exist
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  # Get last 10 unique activities as suggestions with time (HH:MM only)
  suggestions=""
  if [ -s "$LOG_FILE" ]; then
      suggestions=$(tail -100 "$LOG_FILE" | while read line; do
          # Extract time (HH:MM) and activity from each line
          time_part=$(echo "$line" | cut -d' ' -f2 | cut -d':' -f1-2)
          activity_part=$(echo "$line" | cut -d' ' -f4-)
          echo "$time_part - $activity_part"
      done | sort -t: -k1,1nr -k2,2nr | uniq -s8 | tail -100)
  fi

  FILTER=""

  # Check if script is called with "--pr" flag
  if [[ "$1" == "--pr" ]]; then
      PR_INFO_FILE="$HOME/code/ygt/spabreaks/.git/pr-info"
      if [[ -f "$PR_INFO_FILE" ]] && GH_PR_NUMBER=$(< "$PR_INFO_FILE" grep -o 'GH_PR_NUMBER=.*' | cut -d= -f2); then
          FILTER="SB#$GH_PR_NUMBER "
      fi
  fi

  # Show rofi with suggestions
  activity=$(echo "$suggestions" | rofi \
    -dmenu -i -fixed-num-lines \
    -kb-accept-entry "" -kb-accept-custom "Return" \
    -p "Current activity:" -lines 10 -filter "$FILTER")

  # If user selected an entry with time (contains " - "), extract just the activity part
  if [[ "$activity" == *" - "* ]]; then
      activity=$(echo "$activity" | sed 's/^[0-9:]*[[:space:]]*-[[:space:]]*//')
  fi

  if [ -n "$activity" ]; then
      timestamp=$(date "+%Y-%m-%d %H:%M")
      echo "$timestamp - $activity" >> "$LOG_FILE"
      notify-send "Activity Logged" "$activity"
  fi
''

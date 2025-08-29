#!/usr/bin/env bash

launcher='rofi -dmenu -i -theme-str "window { width: 40%; location: center; }"'

options="$(sesh list --tmux | grep -- '-agent$')"

choice=$(echo "$options" | eval "$launcher -p 'Tmux Agents'")

[[ -z "$choice" ]] && { exit 1; }

session_name="$choice"

if tmux list-sessions 2>/dev/null | grep -q "^$session_name:.*attached"; then
    # session is already attached, focus it
    wmctrl -Fa $session_name
else
    # session is not attached, open a terminal and attach
    kitty -T $session_name -e sesh connect $session_name
fi

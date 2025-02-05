#!/usr/bin/env bash

launcher="rofi -dmenu -i"

options=$(sesh list --json | jq -r '.[] | (.Score|tostring) + "," + .Name + "," + .Src + "," + .Path + "," + (.Attached | if . > 0 then "*" else " " end)' | sort -k 2,2 -k4,4 -t"," --stable --unique | sort -nk 1 -t"," | cut -d',' -f2- | column -s"," -t)

choice=$(echo "$(printf '%s\n' "${options[@]}")" | $launcher -p 'Tmux sessions')

[[ -z "$choice" ]] && { exit 1; }

session_name=$(echo "$choice" | cut -d' ' -f1)

if [[ $choice =~ \*$ ]]; then
    # session is already attached, focus it
    wmctrl -Fa $session_name
else
    # session is not attached, open a terminal and attach
    kitty -T $session_name -e sesh connect $session_name
fi

echo $attached


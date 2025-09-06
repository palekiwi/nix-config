{ pkgs }:

pkgs.writeShellScriptBin "dmenu_tmux" ''
  flags=$@

  launcher='rofi -dmenu -i -theme-str "window { width: 40%; location: center; }"'

  options=$(sesh list --json $flags \
      | jq -r '.[] | (.Score|tostring) + "," + .Name + "," + .Src + "," + .Path + "," + (.Attached | if . > 0 then "*" else " " end)' \
      | sort -k 2,2 -k 4,4 -t"," --stable --unique \
      | sort -nk 1 -t"," --stable \
      | cut -d',' -f2- \
      | column -s"," -t)

  choice=$(echo "$(printf '%s\n' "''${options[@]}")" | eval "$launcher -p 'Tmux sessions'")

  [[ -z "$choice" ]] && { exit 1; }

  session_name=$(echo "$choice" | cut -d' ' -f1)

  if [[ $choice =~ \*$ ]]; then
      # session is already attached, focus it
      wmctrl -Fa $session_name
  else
      # session is not attached, open a terminal and attach
      kitty -T $session_name -e sesh connect $session_name
  fi
''

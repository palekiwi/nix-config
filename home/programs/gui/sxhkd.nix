{ pkgs, config, ... }:

let
  cplay = pkgs.writeShellScript "cplay" ''
    if ! pgrep -x cmus ; then
      ${pkgs.tmux}/bin/tmux new -d -s "cmus" "cmus"
      sleep 1
      ${pkgs.cmus}/bin/cmus-remote --play
    else
      ${pkgs.cmus}/bin/cmus-remote -u
    fi
  '';

  typeText = pkgs.writeShellScript "typeText" ''
    sleep 0.1 && xdotool type "$@"
  '';

  autostagedPr = pkgs.writeShellScript "autostaged-pr" ''
    clipboard="$(xclip -selection clipboard -o 2>/dev/null)"
    sleep 0.1 && xdotool type "https://pr-$clipboard.staging.spabreaks.com/"
  '';

  screenshot = pkgs.writeShellScript "screenshot" ''
    ${pkgs.maim}/bin/maim --select | xclip -selection clipboard -target image/png
  '';

  switchToSession = pkgs.writeShellScript "switchToSession" ''
    session_name=$1
    tmux list-clients -F '#S' | grep -q "^$session_name$"

    if [[ $? -eq 0 ]]; then
        # session is already attached, focus it
        wmctrl -Fa $session_name
    else
        # session is not attached, open a terminal and attach
        kitty -T $session_name -e sesh connect $session_name
    fi
  '';

  switchToKyomuSession = pkgs.writeShellScript "switchToKyomuSession" ''
    session_name="$1"
    window_name="kyomu:''${session_name}"

    if wmctrl -l | grep -q "\b$window_name\b"; then
        wmctrl -Fa $window_name
    else
        kitty -T $window_name -e ssh pl@kyomu -A -t "sesh connect $session_name"
    fi
  '';

  switchToAppOrLaunch = pkgs.writeShellScript "switchToAppOrLaunch" ''
    window_title="$1"
    cmd="$2"

    if wmctrl -l | grep -q "$window_title"; then
        wmctrl -Fa "$window_title"
    else
        $cmd
    fi
  '';
in
{
  home.packages = with pkgs; [ sxhkd ];

  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + Return" = "dmenu_tmux --tmux";
      "super + Return + control" = "dmenu_remote_tmux --tmux";
      "super + Return + shift" = "dmenu_tmux";
      "super + BackSpace" = "kitty --title $USER";

      "super + l" = "dmenu_activity_log";
      "super + l + control" = "dmenu_activity_log --pr";

      "super + space; n; a" = "${switchToSession} awesome";
      "super + space; n; c" = "${switchToSession} nix-config";
      "super + space; n; e" = "${switchToAppOrLaunch} Claude claude-desktop";
      "super + space; n; t" = "${switchToSession} ava-ygt";
      "super + space; n; v" = "${switchToSession} nvim";

      "super + space; k; e" = "${switchToKyomuSession} spabreaks";
      "super + space; k; d" = "${switchToKyomuSession} spabreaks-dev";

      "super + space; s; c" = "${switchToSession} spabreaks-console";
      "super + space; s; d" = "${switchToSession} spabreaks-dev";
      "super + space; s; e" = "${switchToSession} spabreaks";
      "super + space; s; g" = "${switchToSession} spabreaks-guard";

      "super + space; v; d" = "${switchToSession} vrs-dev";
      "super + space; v; e" = "${switchToSession} vrs";

      "super + 0" = if config.fedora then "flatpak run com.google.Chrome" else "google-chrome-stable";
      "super + 1" = "rofi -show calc -modi calc -no-show-match -no-sort";
      "super + 2" = "~/.nix-profile/bin/firefox";
      "super + 3" = "rofi-pass --root ~/.password-store 2> /tmp/rofi-pass.log";
      "super + Delete" = "dmenu_quit";
      "super + equal" = "virt-manager";
      "super + shift + Escape" = "playerctl -a pause; xscreensaver-command -l";
      "super + control + Escape" = "xscreensaver-command -a";

      "XF86AudioMute" = cplay;
      "{XF86MonBrightnessUp,XF86MonBrightnessDown}" = "light -{A,U} 2";
      "{XF86AudioPlay,XF86AudioPause}" = "playerctl -i cmus play-pause";
      "{button7,button6}" = "pactl set-sink-volume @DEFAULT_SINK@ {-,+}5%";
      "shift + {button7,button6}" = "light -{U,A} 1";
      "{XF86AudioLowerVolume,XF86AudioRaiseVolume}" = "pactl set-sink-volume @DEFAULT_SINK@ {-,+}5%";
      "control + XF86AudioLowerVolume" = "pactl set-sink-volume @DEFAULT_SINK@ 50%; notify-send -t 800 'Master Vol:' 50%";
      "control + XF86AudioRaiseVolume" = "pactl set-sink-volume @DEFAULT_SINK@ 65%; notify-send -t 800 'Master Vol:' 65%";
      "shift + XF86AudioLowerVolume" = "cmus-remote -v -5%";
      "shift + XF86AudioRaiseVolume" = "cmus-remote -v +5%";
      "shift + control + XF86AudioLowerVolume" = "cmus-remote -v 50%; notify-send -t 800 'Cmus Vol:' 50%";
      "shift + control + XF86AudioRaiseVolume" = "cmus-remote -v 75%; notify-send -t 800 'Cmus Vol:' 75%";
      "Print" = screenshot;
      "XF86HomePage; n" = "~/.dmenu/run";
      "XF86HomePage; p" = "~/.dmenu/process";
      "XF86HomePage; x" = "dmenu_xrandr";
      "XF86Search" = "rofi -show window";

      "XF86Launch7; b" = ''${typeText} "[ci skip]"'';
      "XF86Launch7; c" = ''${typeText} "5200 0000 0000 1005"'';
      "XF86Launch7; l; s" = ''${typeText} "localhost:3030"'';
      "XF86Launch7; p" = autostagedPr;
      "XF86Launch7; s" = "${typeText} staging.spabreaks.com";
      "XF86Launch7; w" = ''${typeText} "[WIP] "'';

      "XF86Launch8" = "dmenu_hass";
      "XF86Launch9" = "dmenu_audio-sinks";
    };
  };
}

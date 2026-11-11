{
  config,
  lib,
  pkgs,
  ...
}:

let
  repoPicker = import ../tui/host-repo-picker { inherit pkgs; };
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

    wmctrl -Fa "$window_name" ||
        kitty -T "$window_name" -e ssh pl@kyomu -A -t "sesh connect $session_name"
  '';

  switchToAgentSession = pkgs.writeShellScript "switchToAgentSession" ''
    session_name="$1"
    window_name="agent:''${session_name}"
    wmctrl -Fa "$window_name" ||
        kitty -T "$window_name" -e ssh agent-vm -t "sesh connect $session_name"
  '';

  scratch = import ./tmux-scratch.nix { inherit pkgs; };

  switchToApp = pkgs.writeShellScript "switchToApp" ''
    app_name=$1
    window_name=$2

    if wmctrl -l | grep -qi "\b$window_name\b"; then
        wmctrl -Fa $window_name
    else
        $app_name
    fi
  '';
in
{
  home.packages = with pkgs; [ sxhkd ];

  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + Return" = "${scratch}/bin/tmux-scratch";
      "super + control + Return" = "${repoPicker}/bin/host-repo-picker --desktop --group spabreaks";
      "super + alt + Return" = "${repoPicker}/bin/host-repo-picker --desktop --group palekiwi";
      "super + shift + Return" = "dmenu_remote_tmux agent-vm --prefix agent";
      "super + BackSpace" = "dmenu_tmux --tmux";
      "super + control + BackSpace" = "dmenu_remote_tmux agent-vm --prefix agent --tmux";

      "super + l" = "${switchToApp} rnote Rnote";
      "super + l + control" = "dmenu_activity_log --pr";

      "super + control + space; t; e" = "${switchToSession} cue";
      "super + control + space; t; n" = "${switchToSession} palekiwi-legacy";
      "super + control + space; t; v" = "${switchToSession} cue-nvim";
      "super + control + space; t; t" = "${switchToSession} cast";
      "super + control + space; t; u" = "${switchToSession} cue-platform";

      "super + control + space; c; c" = "${switchToSession} config-cast";
      "super + control + space; c; n" = "${switchToSession} nix-config";
      "super + control + space; c; p" = "${switchToSession} config-pi";

      "super + control + space; m; d" = "${switchToSession} spabreaks/my-account/dev";
      "super + control + space; m; e" = "${switchToSession} spabreaks/my-account";

      "super + control + space; n; p" = "${switchToSession} notes-pl";
      "super + control + space; n; t" = "${switchToSession} notes-sb";

      "super + control + space; k; s; c" = "${switchToKyomuSession} spabreaks/spabreaks/console";
      "super + control + space; k; s; d" = "${switchToKyomuSession} spabreaks/spabreaks/dev";
      "super + control + space; k; s; e" = "${switchToKyomuSession} spabreaks/spabreaks";
      "super + control + space; k; s; t" = "${switchToKyomuSession} terraform";

      "super + control + space; k; n; c" = "${switchToKyomuSession} nix-config";

      "super + control + space; s; c" = "${switchToSession} spabreaks/spabreaks/console";
      "super + control + space; s; d" = "${switchToSession} spabreaks/spabreaks/dev";
      "super + control + space; s; e" = "${switchToSession} spabreaks/spabreaks";
      "super + control + space; s; s" = "${switchToSession} spabreaks/spabreaks-org";
      "super + control + space; s; t" = "${switchToSession} spabreaks/terraform";

      "super + control + space; r; d" = "${switchToSession} vrs/dev";
      "super + control + space; r; e" = "${switchToSession} vrs";

      "super + space; t; e" = "${switchToAgentSession} cue";
      "super + space; t; n" = "${switchToAgentSession} palekiwi";
      "super + space; t; v" = "${switchToAgentSession} cue-nvim";
      "super + space; t; t" = "${switchToAgentSession} cast";
      "super + space; t; u" = "${switchToAgentSession} cue-platform";

      "super + space; c; n" = "${switchToAgentSession} nix-config";

      "super + space; s; c" = "${switchToAgentSession} spabreaks/spabreaks/console";
      "super + space; s; d" = "${switchToAgentSession} spabreaks/spabreaks/dev";
      "super + space; s; e" = "${switchToAgentSession} spabreaks/spabreaks";
      "super + space; s; s" = "${switchToAgentSession} spabreaks/spabreaks-org";
      "super + space; s; t" = "${switchToAgentSession} spabreaks/terraform";

      "super + space; m; d" = "${switchToAgentSession} spabreaks/my-account/dev";
      "super + space; m; e" = "${switchToAgentSession} spabreaks/my-account";

      "super + space; r; d" = "${switchToAgentSession} vrs/dev";
      "super + space; r; e" = "${switchToAgentSession} vrs";

      "super + space; w; d" = "${switchToAgentSession} spabreaks/wss/dev";
      "super + space; w; e" = "${switchToAgentSession} spabreaks/wss";

      "super + control + space; w; d" = "${switchToSession} spabreaks/wss/dev";
      "super + control + space; w; e" = "${switchToSession} spabreaks/wss";

      "super + 0" = "google-chrome-stable --profile-directory='Profile 1'";
      "super + control + 0" = "google-chrome-stable --profile-directory='Profile 2'";
      "super + 1" = "rofi -show calc -modi calc -no-show-match -no-sort";
      "super + 2" = "~/.nix-profile/bin/firefox";
      "super + 3" = "rofi-pass --root ~/.password-store e>| /tmp/rofi-pass.log";
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
      "control + XF86AudioLowerVolume" =
        "pactl set-sink-volume @DEFAULT_SINK@ 50%; notify-send -t 800 'Master Vol:' 50%";
      "control + XF86AudioRaiseVolume" =
        "pactl set-sink-volume @DEFAULT_SINK@ 65%; notify-send -t 800 'Master Vol:' 65%";
      "shift + XF86AudioLowerVolume" = "cmus-remote -v -5%";
      "shift + XF86AudioRaiseVolume" = "cmus-remote -v +5%";
      "shift + control + XF86AudioLowerVolume" = "cmus-remote -v 50%; notify-send -t 800 'Cmus Vol:' 50%";
      "shift + control + XF86AudioRaiseVolume" = "cmus-remote -v 75%; notify-send -t 800 'Cmus Vol:' 75%";
      "Print" = screenshot;
      "XF86HomePage; n" = "dmenu_wrapped_run";
      "XF86HomePage; p" = "dmenu_process";
      "XF86HomePage; x" = "dmenu_xrandr";
      "XF86Search" = "dmenu_windows";

      "XF86Launch7; b" = ''${typeText} "[ci skip]"'';
      "XF86Launch7; c" = ''${typeText} "5200 0000 0000 1005"'';
      "XF86Launch7; l; s" = ''${typeText} "localhost:3030"'';
      "XF86Launch7; p" = autostagedPr;
      "XF86Launch7; s" = "${typeText} staging.spabreaks.com";
      "XF86Launch7; w" = ''${typeText} "[WIP] "'';

      "XF86Launch8" = "dmenu_hass";
      "XF86Launch9" = "dmenu_audio-sinks";
    }
    // lib.optionalAttrs (config.programs.local-tts.enable or false) {
      "control + Pause" = "clipboard-speech-toggle";
    };
  };
}

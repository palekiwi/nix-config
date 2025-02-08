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
    sleep 0.1 && xdotool type $@
  '';

  screenshot = pkgs.writeShellScript "screenshot" ''
    ${pkgs.maim}/bin/maim --select | xclip -selection clipboard -target image/png
  '';
in
{
  home.packages = with pkgs; [ sxhkd ];

  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + space" = "~/.dmenu/tmux";
      "super + BackSpace" = "kitty --title $USER";

      "super + 0" = if config.fedora then "flatpak run com.google.Chrome" else "google-chrome-stable";
      "super + 1" = "rofi -show calc -modi calc -no-show-match -no-sort";
      "super + 2" = "~/.nix-profile/bin/firefox";
      "super + 3" = "rofi-pass --root ~/.password-store 2> /tmp/rofi-pass.log";
      "super + Delete" = "~/.dmenu/quit";
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
      "XF86HomePage; p" = "~/.dmenu/process";
      "XF86HomePage; x" = "~/.dmenu/xrandr";
      "XF86HomePage; n" = "~/.dmenu/run";
      "XF86HomePage; t" = "~/.dmenu/tmux";
      "XF86Search" = "rofi -show window";

      "XF86Launch7; b" = "${typeText} [ci skip]";
      "XF86Launch7; s" = "${typeText} staging.spabreaks.com";
      "XF86Launch7; c" = "${typeText} 4242 4242 4242 4242";

      "XF86Launch8" = "dmenu_hass";
      "XF86Launch9" = "~/.dmenu/audio-sinks";
    };
  };
}

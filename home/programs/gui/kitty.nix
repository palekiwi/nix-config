{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.kitty;
in
{
  options.modules.kitty = {
    enable = mkEnableOption "enable kitty";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ kitty ];

    programs.kitty = {
      enable = true;
      shellIntegration.enableZshIntegration = true;

      settings = {
        confirm_os_window_close = "0";
        copy_on_select = "yes";
        cursor = "none";
        cursor_beam_thickness = "1.0";
        cursor_blink_interval = "0";
        cursor_shape = "block";
        cursor_shape_unfocused = "hollow";
        enable_audio_bell = "no";
        term = "xterm-256color";

        font_family = "FiraCode Nerd Font Mono";
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
        font_size = "16.0";

        foreground = "#c5c8c6";
        background = "#0F1319";

        # black
        color0 = "#282a2e";
        color8 = "#373b41";

        # red
        color1 = "#a54242";
        color9 = "#cc6666";

        # green
        color2 = "#6e9440";
        color10 = "#9dbd68";

        # yellow
        color3 = "#de935f";
        color11 = "#f0c674";

        # blue
        color4 = "#5f819d";
        color12 = "#81a2be";

        # magenta
        color5 = "#85678f";
        color13 = "#b294bb";

        # cyan
        color6 = "#5e8d87";
        color14 = "#8abeb7";

        # white
        color7 = "#707880";
        color15 = "#c5c8c6";
      };
    };
  };
}

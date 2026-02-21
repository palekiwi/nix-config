{ lib, pkgs, config, ... }:

{
  options.modules.handy = with lib; {
    enable = mkEnableOption "Handy speech-to-text application";
  };

  config = lib.mkIf config.modules.handy.enable {
    home.packages = [ pkgs.handy ];

    # Desktop entry for application launchers
    xdg.desktopEntries.handy = {
      name = "Handy";
      exec = "handy";
      icon = "accessories-text-editor";
      categories = [ "Utility" "Accessibility" ];
      type = "Application";
      terminal = false;
      comment = "Free, open source speech-to-text application";
    };
  };
}

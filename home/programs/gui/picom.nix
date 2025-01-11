{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ picom ];

  home.file."${config.xdg.configHome}/picom/picom.conf" = {
	source = ../../config/picom/picom.conf;
  };
}

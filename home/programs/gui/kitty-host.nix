{ config, pkgs, ... }:

{
  home.file."${config.xdg.configHome}/kitty" = {
	source = ../../../config/kitty;
	recursive = true;
  };
}

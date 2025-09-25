{ config, ... }:

{
  home.file."${config.xdg.configHome}/awesome" = {
	  source = ../../config/awesome;
	  recursive = true;
  };
}

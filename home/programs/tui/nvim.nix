{ pkgs, config, ... }:

{
  home.packages = with pkgs; [ neovim ];

  home.file."${config.xdg.configHome}/nvim" = {
	  source = ../../config/nvim;
	  recursive = true;
  };
}

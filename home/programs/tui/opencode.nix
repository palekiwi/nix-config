{ pkgs, config, ... }:

{
  home.packages = with pkgs; [ opencode ];

  home.file."${config.xdg.configHome}/agent-opencode/opencode.json" = {
	source = ../../config/opencode/opencode.json;
  };
}

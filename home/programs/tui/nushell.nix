{ config, ... }:
{
  programs = {
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
  };

  services.gpg-agent.enableNushellIntegration = true;

  home.file."${config.xdg.configHome}/nushell" = {
	  source = ../../config/nushell;
	  recursive = true;
  };
}

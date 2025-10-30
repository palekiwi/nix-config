{
  programs = {
    nushell = {
      enable = true;
    };

    carapace.enable = true;
    carapace.enableNushellIntegration = true;
  };

  services.gpg-agent.enableNushellIntegration = true;

  xdg.configFile."nushell" = {
    source = ../../config/nushell;
    recursive = true;
  };
}

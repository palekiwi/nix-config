let
  port = 10222;
in
{
  services.taskchampion-sync-server = {
    inherit port;

    enable = true;
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ port ];
  };
}


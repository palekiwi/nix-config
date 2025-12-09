let
  port = 10222;
in
{
  services.taskchampion-sync-server = {
    inherit port;

    enable = true;
    host = "0.0.0.0";
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ port ];
  };
}


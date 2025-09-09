{
  services.gotify = {
    enable = true;
    environment.GOTIFY_SERVER_PORT = "8780";
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8780 ];
}

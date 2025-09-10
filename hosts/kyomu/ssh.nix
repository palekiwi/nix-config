{ ... }:
{
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 438 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.allowedTCPPorts = [ 438 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  networking.firewall.enable = true;
}

let
  port = 6379;
in
{
  services.redis.servers.nextcloud = {
    enable = true;
    port = port;

    bind = "127.0.0.1";

    save = [ ]; # Disable RDB snapshots
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 6379 ];
  };
}

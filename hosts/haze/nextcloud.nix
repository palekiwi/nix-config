{ pkgs, config, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;

    extraApps = {
      inherit (config.services.nextcloud.package.packages.apps) contacts calendar notes;
    };
    extraAppsEnable = true;

    hostName = "nc.paradise-liberty.ts.net";
    https = true; # Behind HTTPS proxy (Caddy)

    config = {
      dbtype = "pgsql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql";

      adminuser = "pl";
      adminpassFile = "/run/secrets/nextcloud/admin/password";

      overwriteProtocol = "https";
      trustedProxies = [ "100.73.219.12" ];
      defaultPhoneRegion = "TW";
    };

    configureRedis = true;
  };

  # Override default nginx port (80 → 8088)
  services.nginx.virtualHosts."nc.paradise-liberty.ts.net" = {
    listen = [
      { addr = "100.122.42.74"; port = 8088; }
      { addr = "127.0.0.1"; port = 8088; }
    ];

    # No HTTPS on this nginx (Caddy handles it)
    forceSSL = false;
    enableACME = false;
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 8088 ];
  };
}

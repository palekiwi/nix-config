{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_16;

    settings = {
      port = 5432;
    };

    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
    ];

    authentication = ''
      local   all             all                                     peer
      host    all             all             127.0.0.1/32           scram-sha-256
      host    all             all             ::1/128                scram-sha-256
    '';

    settings = {
      timezone = "Asia/Taipei";
    };

  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 5432 ];
  };
}

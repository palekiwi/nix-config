{ pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    package = pkgs.postgresql_16;

    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
    ];

    authentication = ''
      local   all             postgres                               peer
      host    nextcloud       nextcloud       100.64.0.0/10          scram-sha-256
      host    all             all             127.0.0.1/32           scram-sha-256
    '';

    settings = {
      port = 5432;
      timezone = "Asia/Taipei";
    };

  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 5432 ];
  };
}

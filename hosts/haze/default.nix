{ ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/docker.nix
      ../../modules/server.nix
    ];

  config = {
    modules.docker.enable = false;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "haze";

    networking.networkmanager.enable = true;

    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.pl = {
      extraGroups = [ "dialout" ];
      linger = true;
    };

    environment.shellAliases = {
      gu = "gitui";
      p = "podman";
      v = "nvim";
    };

    services.udev.extraRules = ''
      KERNEL=="ttyUSB0", OWNER="pl"
    '';

    systemd.timers."nextcloud-cron" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        Unit = "nextcloud-cron.service";
      };
    };

    systemd.services."nextcloud-cron" = {
      description = "Cron job for nextcloud";
      requires = ["podman-kube@-home-pl-homelab-nc-kube.yml.service"];
      after = ["podman-kube@-home-pl-homelab-nc-kube.yml.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''podman exec -u www-data nc-nextcloud php -f /var/www/html/cron.php'';
        User = "pl";
      };
    };

    networking.firewall.allowedTCPPorts = [ 8080 8123 5050 ];
    # networking.firewall.allowedUDPPorts = [ ... ];

    virtualisation.podman.enable = true;

    system.stateVersion = "24.11";
  };
}

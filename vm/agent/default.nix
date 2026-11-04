{ pkgs, ... }:
{
  imports = [
    ../../users/pl/default.nix
    ./nvim.nix
    ./cue-platform.nix
    ./proxy.nix
    ../../modules/machine-role.nix
  ];

  palekiwi.machineRole = "vm";

  networking.hostName = "agent-vm";

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 8;
    mem = 12288;
    vsock.cid = 3;
    vsock.ssh.enable = true;
    interfaces = [
      {
        type = "tap";
        id = "vm-agent";
        mac = "02:00:00:00:77:02";
      }
    ];
    volumes = [
      {
        image = "ssh-host-keys.img";
        mountPoint = "/persist/ssh";
        size = 16;
      }
      {
        image = "nix-store-rw.img";
        mountPoint = "/nix/.rw-store";
        size = 40960;
      }
      {
        image = "nix-var.img";
        mountPoint = "/nix/var";
        size = 1024;
      }
      {
        image = "var.img";
        mountPoint = "/var";
        size = 40960;
      }
      {
        image = "home.img";
        mountPoint = "/home";
        size = 40960;
      }
    ];
    writableStoreOverlay = "/nix/.rw-store";
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        readOnly = true;
      }
    ];
  };

  fileSystems."/nix/var".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  networking.useNetworkd = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.MACAddress = "02:00:00:00:77:02";
    address = [ "10.77.0.2/32" ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "10.77.0.1";
        GatewayOnLink = true;
      }
    ];
    dns = [ "1.1.1.1" "9.9.9.9" ];
  };

  systemd.network.networks."05-docker" = {
    matchConfig.Name = "docker* br-* veth*";
    linkConfig.Unmanaged = true;
  };

  virtualisation.docker.enable = true;

  boot.kernel.sysctl."vm.max_map_count" = 262144;

  users.users.pl = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "docker" ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.openssh.hostKeys = [
    {
      path = "/persist/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  systemd.services.sshd-keygen.unitConfig.RequiresMountsFor = [ "/persist/ssh" ];

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.settings.build-dir = "/var/lib/nix-builds";
  systemd.tmpfiles.rules = [ "d /var/lib/nix-builds 0700 root root 7d" ];

  environment.systemPackages = with pkgs; [ git nushell ];

  system.stateVersion = "26.05";
}

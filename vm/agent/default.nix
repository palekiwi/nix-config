{ pkgs, ... }:
{
  imports = [ ../../users/pl/default.nix ];

  networking.hostName = "agent-vm";

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 4;
    mem = 4096;
    vsock.cid = 3;
    vsock.ssh.enable = true;
    interfaces = [
      {
        type = "tap";
        id = "vm-agent";
        mac = "02:00:00:00:77:02";
      }
    ];
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

  users.users.pl = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  environment.systemPackages = with pkgs; [ git tmux neovim ];

  system.stateVersion = "26.05";
}

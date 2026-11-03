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
    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];
  };

  users.users.pl = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  environment.systemPackages = with pkgs; [ git tmux neovim ];

  system.stateVersion = "26.05";
}

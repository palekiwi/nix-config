{ pkgs, claude-desktop-pkg, ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      graphics = true;
      diskSize = 8192;

      forwardPorts = [
        { from = "host"; host.port = 2222; guest.port = 22; }
      ];

      sharedDirectories = {
        my-share = {
          source = "$HOME/claude";
          target = "/mnt/shared";
        };
        labs = {
          source = "$HOME/code/palekiwi-labs";
          target = "/mnt/labs";
        };
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xfce.enable = true;
  };

  environment.variables = {
    GTK_THEME = "Adwaita:dark";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  users.users.claude = {
    isNormalUser = true;
    password = "user";
    extraGroups = [ "wheel" ];
  };

  networking.firewall.allowedTCPPorts = [ 22 ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.claude.openssh.authorizedKeys.keys = [
    (builtins.readFile ../../users/pl/ssh.pub)
  ];

  environment.systemPackages = with pkgs; [
    claude-desktop-pkg.claude-desktop-with-fhs
    vim
    nodejs_24
  ];

  system.stateVersion = "25.05";
}

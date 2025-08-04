{ pkgs, claude-desktop-pkg, ... }:

# TODO: install config (setup MCPs, etc)

{
  imports = [
    ./sops.nix
  ];

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
          securityModel = "passthrough";
        };
      };

      fileSystems."/mnt/shared" = {
        options = [ "ro" ];
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xfce.enable = true;

    displayManager.sessionCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --newmode "1336x1418_60.00"  159.84  1336 1432 1576 1816  1418 1419 1422 1467  -HSync +Vsync || true
      ${pkgs.xorg.xrandr}/bin/xrandr --addmode Virtual-1 1336x1418_60.00 || true
      ${pkgs.xorg.xrandr}/bin/xrandr --output Virtual-1 --mode 1336x1418_60.00 || true
    '';
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
    git
    vim
    nodejs_24
  ];

  system.stateVersion = "25.05";
}

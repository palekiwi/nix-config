{ pkgs, claude-desktop-pkg, ... }:

{
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      graphics = true;
      diskSize = 8192;

      sharedDirectories = {
        my-share = {
          source = "$HOME/claude";
          target = "/mnt/shared";
        };
      };
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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

  environment.systemPackages = with pkgs; [
    claude-desktop-pkg.claude-desktop-with-fhs
    vim
    nodejs_24
  ];

  system.stateVersion = "25.05";
}

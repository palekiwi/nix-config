{ pkgs, ... }:
{
  services.displayManager.defaultSession = "none+awesome";

  services.xserver = {
    enable = true;

    xkb = { layout = "us"; variant = ""; };

    displayManager = {
      lightdm.enable = false;
      gdm.enable = true;
    };

    desktopManager.gnome.enable = true;

    windowManager.awesome = {
      enable = true;
      luaModules = with pkgs; [
        luaPackages.luarocks # is the package manager for Lua modules
        luaPackages.luadbi-mysql # Database abstraction layer
      ];
    };
  };

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  environment.systemPackages = with pkgs; [
    picom
    xorg.xrandr
    xscreensaver
  ];
}

{ ... }:

{
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = "jennifer";
  };

  # Workaround for autologin issues if any
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}

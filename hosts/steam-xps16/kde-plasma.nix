{ ... }:
{
  # Enable KDE Plasma 6 Desktop Environment
  services.desktopManager.plasma6.enable = true;

  # Enable SDDM display manager (KDE's default)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Enable automatic login for gaming convenience
  services.displayManager.autoLogin = {
    enable = true;
    user = "pl";
  };

  # Enable graphical server infrastructure
  # Despite the name "xserver", this is required for both X11 and Wayland sessions
  # KDE Plasma 6 will offer both session types at login:
  # - "Plasma (Wayland)" - Modern, better performance for newer games
  # - "Plasma (X11)" - Legacy compatibility for older games/anti-cheat
  services.xserver = {
    enable = true;

    # Enable touchpad support (XPS16 is a laptop)
    libinput.enable = true;

    xkb = {
      layout = "us";
      variant = "";
    };
  };
}

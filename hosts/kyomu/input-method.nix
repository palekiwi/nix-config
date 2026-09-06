{ pkgs, ... }:

{
  # fcitx5 over ibus: first-class KDE Plasma 6 Wayland integration.
  # KWin launches fcitx5 as its input method, which anchors candidate
  # popups correctly; chewing provides Traditional Chinese
  # zhuyin/bopomofo for jennifer. pale stays on modules/ibus.nix.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-chewing ];
      # Use Wayland text-input instead of forcing im module env vars.
      waylandFrontend = true;
      # Preconfigure the default group so chewing works out of the box.
      settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "chewing";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "chewing";
      };
    };
  };

  # KCM-integrated config tool (System Settings > Input Method).
  environment.systemPackages = [ pkgs.kdePackages.fcitx5-configtool ];

  # Let KWin own the fcitx5 process on Wayland, equivalent to picking
  # "Fcitx 5" under System Settings > Keyboard > Virtual Keyboard.
  environment.etc."xdg/kwinrc".text = ''
    [Wayland]
    InputMethod=/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop
  '';

  # Suppress the xdg autostart entry so fcitx5 is only started by KWin
  # (avoids the "Fcitx should be launched by KWin" warning).
  environment.etc."xdg/autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Exec=fcitx5
    Hidden=true
  '';
}

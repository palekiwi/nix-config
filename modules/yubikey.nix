{ pkgs, ... }:

{
  services.dbus.packages = [ pkgs.gcr ]; # for gnome pinentry

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true;

  environment.systemPackages = [ pkgs.age-plugin-yubikey ];
}

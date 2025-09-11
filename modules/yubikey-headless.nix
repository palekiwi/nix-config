{ pkgs, ... }:

{
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true;

  environment.systemPackages = [ pkgs.age-plugin-yubikey ];
}

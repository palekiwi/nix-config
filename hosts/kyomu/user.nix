{ pkgs, ... }:
{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" "dialout" ];
    shell = pkgs.zsh;
  };

  services.udev.extraRules = ''
    # YubiKey and other smart card readers
    ENV{ID_SMARTCARD_READER}=="1", GROUP="dialout", MODE="0664"
  '';

  programs.zsh.enable = true;
}

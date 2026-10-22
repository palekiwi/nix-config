{ pkgs, ... }:
{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" "dialout" "video" "audio" ];
    shell = pkgs.nushell;
  };

  users.users.jennifer = {
    isNormalUser = true;
    description = "Jennifer";
    extraGroups = [ "networkmanager" "video" "audio" ];
    shell = pkgs.bash;
  };

  services.udev.extraRules = ''
    # YubiKey and other smart card readers
    ENV{ID_SMARTCARD_READER}=="1", GROUP="dialout", MODE="0664"
  '';
}

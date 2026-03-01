{ pkgs, ... }:

{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
    shell = pkgs.bash;
  };

  users.users.jennifer = {
    isNormalUser = true;
    description = "Jennifer";
    extraGroups = [ "networkmanager" "video" "audio" ];
    shell = pkgs.bash;
  };
}

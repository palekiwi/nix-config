{ pkgs, ... }:
{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.nushell;
  };
}

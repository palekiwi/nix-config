{ pkgs, ... }:
{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" "scard" "plugdev" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
}

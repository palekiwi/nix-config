{ pkgs, ... }:
{
  users.users.pl = {
    isNormalUser = true;
    description = "pl";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keyFiles = [
      ../../users/pl/ssh-xiaomi-tab.pub
    ];
  };

  programs.zsh.enable = true;
}

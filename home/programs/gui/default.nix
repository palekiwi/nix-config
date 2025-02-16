{ lib, ... }: {

  imports = [
    ./chrome.nix
    ./dmenu.nix
    ./firefox.nix
    ./gtk.nix
    ./kitty.nix
    # ./picom.nix
    ./rofi.nix
    ./sxhkd.nix
    ./utils.nix
    ./xorg.nix
  ];

  modules.firefox.enable = lib.mkDefault true;
}

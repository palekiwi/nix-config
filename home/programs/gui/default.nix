{ lib, ... }: {

  imports = [
    ./awesome.nix
    ./chrome.nix
    ./dmenu.nix
    ./firefox.nix
    ./gtk.nix
    ./handy.nix
    ./kitty.nix
    ./rofi.nix
    ./sxhkd.nix
    ./unclutter.nix
    ./utils.nix
    ./xorg.nix
  ];

  modules.firefox.enable = lib.mkDefault true;
}

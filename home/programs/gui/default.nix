{ pkgs, config, lib, ... }: {

  imports = [
  	./gtk.nix
  	./rofi.nix
  	./sxhkd.nix
    ./dmenu.nix
    ./kitty.nix
    ./picom.nix
    ./xorg.nix
  ];
}

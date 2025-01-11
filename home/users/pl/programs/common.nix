{ pkgs, ... }:
{
  imports = [
  	../../../programs/gh.nix
  	../../../programs/git.nix
  	../../../programs/gtk.nix
  	../../../programs/rofi.nix
  	../../../programs/sxhkd.nix
  	../../../programs/zsh.nix
    ../../../programs/tmux.nix
    ../../../programs/dmenu.nix
    ../../../programs/xorg.nix
    ../../../programs/picom.nix
    ../../../programs/cmus.nix
  ];
}

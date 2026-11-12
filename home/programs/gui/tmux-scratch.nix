{ pkgs }:

pkgs.writeShellApplication {
  name = "tmux-scratch";
  runtimeInputs = with pkgs; [
    tmux
    kitty
    wmctrl
  ];
  text = builtins.readFile ./tmux-scratch.sh;
}

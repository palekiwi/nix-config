{ pkgs }:

pkgs.writeShellApplication {
  name = "host-repo-picker";
  runtimeInputs = [
    pkgs.bash
    pkgs.python3
    pkgs.tmux
    pkgs.fzf
    pkgs.util-linux
    pkgs.rofi
    pkgs.wmctrl
    pkgs.kitty
    pkgs.libnotify
  ];
  text = ''
    exec python3 ${./picker.py} "$@"
  '';
}

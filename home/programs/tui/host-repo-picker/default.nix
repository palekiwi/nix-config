{ pkgs }:

pkgs.writeShellApplication {
  name = "host-repo-picker";
  runtimeInputs = [
    pkgs.python3
    pkgs.tmux
    pkgs.fzf
    pkgs.rofi
    pkgs.wmctrl
    pkgs.kitty
    pkgs.libnotify
  ];
  text = ''
    exec python3 ${./picker.py} "$@"
  '';
}

{ pkgs }:

pkgs.writeShellApplication {
  name = "host-repo-picker";
  runtimeInputs = [
    pkgs.python3
    pkgs.tmux
    pkgs.fzf
  ];
  text = ''
    exec python3 ${./picker.py} "$@"
  '';
}

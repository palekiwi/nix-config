{ pkgs }:

pkgs.writeShellScriptBin "dmenu_windows" ''
  rofi -show window -theme-str "window { width: 40%; height: 50%; location: center; }"
''

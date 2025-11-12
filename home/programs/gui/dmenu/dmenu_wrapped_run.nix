{ pkgs }:

pkgs.writeShellScriptBin "dmenu_wrapped_run" ''
  SHELL=${pkgs.bash}/bin/bash dmenu_run -i -nb \#1d1f21 -nf \#D3D7CF -sb \#5294e2 -sf \#2f343f -fn 11
''

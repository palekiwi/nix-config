{ pkgs, ... }:

pkgs.writeShellScriptBin "opencode-container-name" ''
  pwd | ${pkgs.gawk}/bin/awk -F/ '{print "opencode-" $(NF-1) "-" $NF}'
''

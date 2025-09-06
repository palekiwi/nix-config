{ pkgs, ... }:

pkgs.writeShellScriptBin "docker_ps_short" ''
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.ID}}\t{{.Ports}}"
''

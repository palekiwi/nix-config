{ lib, ... }:
let
  user = "pl";
  port = "438";
  hosts = [ "haze" "pale" ];
in
{
  programs.ssh = {
    enable = true;

    extraConfig = lib.concatMapStrings (host: ''
      Host ${host}
        user ${user}
        port ${port}
    '') hosts;
  };
}

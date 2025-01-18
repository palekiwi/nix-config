{ lib, ... }:
let
  user = "pl";
  port = "438";
  hosts = [
    "akemi"
    "haze"
    "pale"
    "sayuri"
  ];
in
{
  programs.ssh = {
    enable = true;

    extraConfig = lib.concatMapStrings
      (host: ''
        Host ${host}
          user ${user}
          port ${port}
      '')
      hosts;
  };
}

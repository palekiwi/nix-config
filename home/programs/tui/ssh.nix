{ lib, ... }:
let
  user = "pl";
  port = 438;
  hosts = [
    "akemi"
    "deck"
    "haze"
    "kyomu"
    "pale"
    "sayuri"
  ];
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = lib.genAttrs hosts (host: {
      HostName = "${host}.paradise-liberty.ts.net";
      User = user;
      Port = port;
    });
  };
}

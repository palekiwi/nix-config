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
    
    matchBlocks = {
      "*" = {
        # Add any default options you want to keep here
        # For example: 
        # SendEnv = [ "LANG" "LC_*" ];
        # HashKnownHosts = true;
      };
    } // (lib.genAttrs hosts (host: {
      host = host;
      hostname = "${host}.paradise-liberty.ts.net";
      user = user;
      port = port;
    }));
  };
}

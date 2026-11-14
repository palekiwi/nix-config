{ lib, ... }:
let
  pubFile = ./leaf.pub;
in
{
  imports = [ ./hub.nix ];

  services.agent-nats.leafPublicKey = lib.mkIf (builtins.pathExists pubFile) (
    lib.trim (builtins.readFile pubFile)
  );
}

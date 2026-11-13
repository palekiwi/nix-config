{ config, lib, ... }:
let
  inherit (import ./endpoint.nix) credentials;
  users = credentials.guestUsers ++ credentials.hostUsers;
  hashSecret = user: config.sops.secrets.${credentials.hashSecret user};
in
{
  imports = [ ./broker.nix ];

  sops.secrets =
    lib.genAttrs (map credentials.hashSecret users) (_: { })
    // lib.genAttrs (map credentials.passwordSecret credentials.hostUsers) (_: {
      owner = "pl";
    });

  services.agent-mqtt.hashedPasswordFiles = lib.genAttrs users (user: (hashSecret user).path);
}

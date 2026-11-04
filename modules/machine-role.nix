{ lib, config, ... }:
let
  role = config.palekiwi.machineRole;
in
{
  options.palekiwi.machineRole = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "host" "vm" ]);
    default = null;
    description = ''
      Credential model of this machine, written to /etc/palekiwi/machine-role.
      host: real secrets under /run/secrets. vm: no secrets; placeholders
      swapped by the egress proxy.
    '';
  };

  config = lib.mkIf (role != null) {
    environment.etc."palekiwi/machine-role".text = "${role}\n";
  };
}

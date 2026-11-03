{ ... }:
{
  microvm.vms.agent = {
    config.imports = [ ../vm/agent ];
  };

  microvm.autostart = [ ];

  users.users.pl.extraGroups = [ "kvm" ];

  systemd.services."microvm@agent" = {
    overrideStrategy = "asDropin";
    restartIfChanged = false;
    serviceConfig.UMask = "0007";
  };
}

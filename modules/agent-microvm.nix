{ pkgs, ... }:
{
  microvm.vms.agent = {
    config.imports = [ ../vm/agent ];
  };

  microvm.autostart = [ ];

  users.users.pl.extraGroups = [ "kvm" ];

  systemd.services."microvm@agent" = {
    overrideStrategy = "asDropin";
    restartIfChanged = false;
    serviceConfig.ExecStartPost = [
      (pkgs.writeShellScript "agent-vsock-group-access" ''
        for _ in $(${pkgs.coreutils}/bin/seq 50); do
          if [ -S notify.vsock ]; then
            exec ${pkgs.coreutils}/bin/chmod 0770 notify.vsock
          fi
          ${pkgs.coreutils}/bin/sleep 0.1
        done
        exit 1
      '')
    ];
  };
}

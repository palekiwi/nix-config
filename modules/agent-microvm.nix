{ ... }:
{
  microvm.vms.agent = {
    config.imports = [ ../vm/agent ];
  };

  microvm.autostart = [ ];
}

{ lib, ...}:

with lib;
{
  options.fedora = mkOption {
    type = types.bool;
    default = false;
  };

  options.gui = mkOption {
    type = types.bool;
    default = true;
    description = "Whether to enable GUI applications and dependencies";
  };
}

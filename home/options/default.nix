{ lib, ...}:

with lib;
{
  options.gui = mkOption {
    type = types.bool;
    default = true;
    description = "Whether to enable GUI applications and dependencies";
  };
}

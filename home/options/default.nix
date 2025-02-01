{ lib, ...}:

with lib;
{
  options.fedora = mkOption {
    type = types.bool;
    default = false;
  };
}

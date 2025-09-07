{ config, lib, ... }:

with lib;

let
  cfg = config.modules.oss;

  commonOssFiles = {
    "code/oss/.gitconfig".source = ../../config/oss/.gitconfig;
    "code/oss/.gitignore".text = import ../../config/oss/.gitignore.nix;
    "code/oss/flakes".source = ../../config/oss/flakes;
  };
in
{
  options.modules.oss = {
    enable = mkEnableOption "enable oss";
  };

  config = mkIf cfg.enable {
    home.file = commonOssFiles;
  };
}

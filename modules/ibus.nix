{ config, pkgs, lib, ... }:

{
  options.modules.ibus = {
    enable = lib.mkEnableOption "enable ibus";
  };

  config = lib.mkIf config.modules.ibus.enable {
    i18n.inputMethod = {
      enable = true;
      type = "ibus";
      ibus.engines = with pkgs.ibus-engines; [ libpinyin ];
    };
  };
}

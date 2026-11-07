{
  pkgs,
  config,
  lib,
  ...
}:

{
  home.packages = with pkgs; [ sesh ];

  home.file."${config.xdg.configHome}/sesh/sesh.toml" = {
    text = lib.replaceStrings [ ''name = "palekiwi"'' ] [ ''name = "palekiwi-legacy"'' ] (
      builtins.readFile ../../config/sesh/sesh.toml
    );
  };
}

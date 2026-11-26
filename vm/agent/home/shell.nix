{ pkgs, lib, ... }:
let
  nushellConfig = ../../../home/config/nushell;
  atuinConfig = (pkgs.formats.toml { }).generate "atuin-config.toml" (
    import ../../../home/programs/tui/atuin-settings.nix
  );
in
{
  home.packages = with pkgs; [
    nushell
    atuin
    bat
    carapace
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      if [ -z "$__AGENT_VM_NU" ] && [ -z "$NO_NU" ]; then
        export __AGENT_VM_NU=1
        exec ${pkgs.nushell}/bin/nu
      fi
    '';
  };

  xdg.configFile = {
    "nushell/config.nu".source = ./nushell/config.nu;
    "atuin/config.toml".source = atuinConfig;
  }
  // lib.genAttrs' (builtins.filter (name: name != "config.nu") (
    builtins.attrNames (builtins.readDir nushellConfig)
  )) (name: lib.nameValuePair "nushell/${name}" { source = "${nushellConfig}/${name}"; });
}

{ pkgs, ... }:
let
  nushellConfig = ../../home/config/nushell;
  atuinConfig = (pkgs.formats.toml { }).generate "atuin-config.toml"
    (import ../../home/programs/tui/atuin-settings.nix);
in
{
  environment.systemPackages = with pkgs; [ atuin bat carapace ];

  programs.bash.interactiveShellInit = ''
    if [ -z "$__AGENT_VM_NU" ] && [ -z "$NO_NU" ]; then
      export __AGENT_VM_NU=1
      exec ${pkgs.nushell}/bin/nu
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /home/pl/.config/nushell 0755 pl users -"
    "d /home/pl/.config/atuin 0755 pl users -"
    "L+ /home/pl/.config/nushell/config.nu - - - - ${./nushell/config.nu}"
    "L+ /home/pl/.config/atuin/config.toml - - - - ${atuinConfig}"
  ] ++ map (name: "L+ /home/pl/.config/nushell/${name} - - - - ${nushellConfig}/${name}")
    (builtins.filter (name: name != "config.nu")
      (builtins.attrNames (builtins.readDir nushellConfig)));
}

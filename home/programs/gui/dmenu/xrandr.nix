{ pkgs }:

pkgs.writeShellApplication {
  name = "dmenu_xrandr";
  runtimeInputs = with pkgs; [
    xorg.xrandr
    coreutils
  ];
  text = ''
    exec ${pkgs.nushell}/bin/nu ${./xrandr.nu} "$@"
  '';
}

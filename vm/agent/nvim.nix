{ pkgs, lib, ... }:
let
  nvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    withPython3 = false;
    withRuby = false;
    wrapperArgs = [
      "--prefix" "PATH" ":" (lib.makeBinPath (import ../../home/programs/tui/nvim-tools.nix pkgs))
      "--set" "NVIM_NO_PERSONAL" "1"
    ];
  };
in
{
  environment.systemPackages = [ nvim ];
  environment.variables.EDITOR = "nvim";

  systemd.tmpfiles.rules = [
    "d /home/pl/.config 0755 pl users -"
    "L+ /home/pl/.config/nvim - - - - ${../../home/config/nvim}"
  ];
}

{ pkgs, lib, ... }:
let
  nvimConfig = ../../home/config/nvim;
  nvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    withPython3 = false;
    withRuby = false;
    wrapRc = false;
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
    "d /home/pl/.config/nvim 0755 pl users -"
  ] ++ map (name: "L+ /home/pl/.config/nvim/${name} - - - - ${nvimConfig}/${name}")
    (builtins.attrNames (builtins.readDir nvimConfig));
}

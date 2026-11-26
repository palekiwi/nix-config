{ pkgs, lib, ... }:
let
  nvimConfig = ../../../home/config/nvim;
  nvim = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
    withPython3 = false;
    withRuby = false;
    wrapRc = false;
    wrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath (import ../../../home/programs/tui/nvim-tools.nix pkgs))
      "--set"
      "NVIM_NO_PERSONAL"
      "1"
      "--set"
      "NVIM_CLIPBOARD_OSC52"
      "1"
    ];
  };
in
{
  home.packages = [ nvim ];
  home.sessionVariables.EDITOR = "nvim";

  xdg.configFile = lib.genAttrs' (builtins.attrNames (builtins.readDir nvimConfig)) (
    name: lib.nameValuePair "nvim/${name}" { source = "${nvimConfig}/${name}"; }
  );

  home.activation.clearNvimLuacCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -rf "$HOME/.cache/nvim/luac"
  '';
}

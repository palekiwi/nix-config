{ config, lib, pkgs, ... }:

{
  # nvim's bytecode cache (vim.loader, via lazy.nvim) keys on mtime + size;
  # nix store files share an epoch mtime, so length-neutral config edits are
  # silently served stale. The cache is regenerable, so clear it on switch.
  home.activation.clearNvimLuacCache =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD rm -rf "$HOME/.cache/nvim/luac"
    '';

  # home.packages = with pkgs; [ neovim ];
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraPackages = [ pkgs.notmuch ] ++ import ./nvim-tools.nix pkgs;

    extraWrapperArgs = [ "--suffix" "LD_LIBRARY_PATH" ":" "${pkgs.notmuch}/lib" ];
  };

  home.file."${config.xdg.configHome}/nvim" = {
    source = ../../config/nvim;
    recursive = true;
  };
}

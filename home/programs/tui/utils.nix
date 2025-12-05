{ pkgs, lib, ... }:

let
  # Wrap taskwarrior-tui to ensure it always finds taskwarrior3's task binary,
  # even when devshells bring in their own go-task that overrides PATH
  taskwarrior-tui-wrapped = pkgs.symlinkJoin {
    name = "taskwarrior-tui-wrapped";
    paths = [ pkgs.taskwarrior-tui ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/taskwarrior-tui \
        --prefix PATH : ${pkgs.taskwarrior3}/bin
    '';
  };
in
{
  home.packages = with pkgs; [
    acpi
    bat
    cachix
    cmus
    eza
    fasd
    fd
    fzf
    (lib.lowPrio go-task)
    home-assistant-cli
    jrnl
    jq
    neovim
    pandoc
    pass
    ranger
    ripgrep
    starship
    taskwarrior-tui-wrapped
    taskwarrior3
    tldr
    tree
    typescript
    universal-ctags
    unzip
    which
    yubikey-manager
    zoxide
  ];
}

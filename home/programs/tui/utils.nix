{ pkgs, ... }:

let
  # Rename taskwarrior's 'task' binary to 'tw' to avoid conflict with go-task
  wrapped-taskwarrior = pkgs.symlinkJoin {
    name = "taskwarrior3";
    paths = [ pkgs.taskwarrior3 ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Remove the conflicting 'task' binary
      rm $out/bin/task
      # Create a renamed symlink 'tw' instead
      ln -s ${pkgs.taskwarrior3}/bin/task $out/bin/taskwarrior3
      # Remove conflicting share
      rm -rf $out/share
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
    go-task
    home-assistant-cli
    jrnl
    jq
    neovim
    pandoc
    pass
    ranger
    ripgrep
    starship
    tldr
    tree
    typescript
    universal-ctags
    unzip
    which
    yubikey-manager
    zoxide
    wrapped-taskwarrior
  ];
}

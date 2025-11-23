{ ... }:

{
  imports = [
    # Essential TUI tools for system management
    ../../programs/tui/git.nix
    ../../programs/tui/nvim.nix
    ../../programs/tui/nushell.nix
    ../../programs/tui/tmux.nix
    ../../programs/tui/ssh.nix
    ../../programs/tui/direnv.nix
    ../../programs/tui/starship.nix
    ../../programs/tui/gh.nix
    ../../programs/tui/atuin.nix
    ../../programs/tui/sesh.nix
    ../../programs/tui/utils.nix

    # Minimal GUI applications
    ../../programs/gui/kitty.nix
    ../../programs/gui/firefox.nix
    # Note: gtk.nix provides Breeze-Dark theme for GTK apps like Firefox and Discord
    # This ensures consistent dark theme across KDE and GTK applications
    ../../programs/gui/gtk.nix
  ];

  config = {
    home = {
      username = "pl";
      homeDirectory = "/home/pl";
      stateVersion = "25.05";
    };

    nixpkgs.config.allowUnfree = true;
    programs.home-manager.enable = true;

    # Enable only needed modules
    modules = {
      kitty.enable = true;
      firefox.enable = true;
    };
  };
}

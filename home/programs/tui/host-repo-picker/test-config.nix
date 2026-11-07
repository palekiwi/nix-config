{ pkgs, home-manager }:

let
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../tmux.nix
      ../sesh.nix
      ../../gui/sxhkd.nix
      {
        home.username = "picker-test";
        home.homeDirectory = "/home/picker-test";
        home.stateVersion = "24.11";
        programs.tmux.extraConfig = ''
          bind-key -n C-f display-message old-picker
          bind-key w display-message old-picker
        '';
      }
    ];
  };
  picker = import ./. { inherit pkgs; };
in
pkgs.linkFarm "host-repo-picker-test-config" [
  {
    name = "tmux.conf";
    path = home.config.xdg.configFile."tmux/tmux.conf".source;
  }
  {
    name = "repos.toml";
    path = home.config.xdg.configFile."tmux/repos.toml".source;
  }
  {
    name = "sxhkdrc";
    path = home.config.xdg.configFile."sxhkd/sxhkdrc".source;
  }
  {
    name = "sesh.toml";
    path = home.config.home.file."/home/picker-test/.config/sesh/sesh.toml".source;
  }
  {
    name = "picker";
    path = picker;
  }
]

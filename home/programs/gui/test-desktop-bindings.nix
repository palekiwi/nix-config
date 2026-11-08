{ pkgs, home-manager }:

let
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ./sxhkd.nix
      {
        home.username = "desktop-test";
        home.homeDirectory = "/home/desktop-test";
        home.stateVersion = "24.11";
      }
    ];
  };
in
pkgs.linkFarm "desktop-bindings-test-config" [
  {
    name = "sxhkdrc";
    path = home.config.xdg.configFile."sxhkd/sxhkdrc".source;
  }
  {
    name = "scratch";
    path = import ./tmux-scratch.nix { inherit pkgs; };
  }
  {
    name = "remote";
    path = import ./dmenu/remote-tmux.nix { inherit pkgs; };
  }
]

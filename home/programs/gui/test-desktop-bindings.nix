{ pkgs, home-manager }:

let
  evaluate =
    enabled:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./sxhkd.nix
        {
          home.username = "desktop-test";
          home.homeDirectory = "/home/desktop-test";
          home.stateVersion = "24.11";
        }
      ]
      ++ pkgs.lib.optionals (enabled != null) [
        ../local-tts
        { programs.local-tts.enable = enabled; }
      ];
    };
  home = evaluate true;
  disabled = evaluate false;
  absent = evaluate null;
in
assert !(absent.config.services.sxhkd.keybindings ? "shift + Pause");
assert !(disabled.config.services.sxhkd.keybindings ? "shift + Pause");
pkgs.linkFarm "desktop-bindings-test-config" [
  {
    name = "sxhkdrc";
    path = home.config.xdg.configFile."sxhkd/sxhkdrc".source;
  }
  {
    name = "sxhkdrc-disabled";
    path = disabled.config.xdg.configFile."sxhkd/sxhkdrc".source;
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

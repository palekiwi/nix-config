{ pkgs, home-manager }:

let
  evaluate =
    enabled: target:
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
        {
          programs.local-tts.enable = enabled;
          programs.local-tts.target = target;
        }
      ];
    };
  home = evaluate true null;
  disabled = evaluate false null;
  absent = evaluate null null;
  targeted = evaluate true "bluez_output.test";
  speechVolume = "alt + {XF86AudioLowerVolume,XF86AudioRaiseVolume}";
in
assert !(home.config.services.sxhkd.keybindings ? ${speechVolume});
assert
  targeted.config.services.sxhkd.keybindings."alt + {button7,button6}"
  == targeted.config.services.sxhkd.keybindings.${speechVolume};
assert !(absent.config.services.sxhkd.keybindings ? ${speechVolume});
assert
  builtins.match ".*speech-volume \\{-,\\+}5%"
    targeted.config.services.sxhkd.keybindings.${speechVolume} != null;
assert !(absent.config.services.sxhkd.keybindings ? "control + Pause");
assert !(disabled.config.services.sxhkd.keybindings ? "control + Pause");
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

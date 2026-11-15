{ pkgs, home-manager }:

let
  evaluate' =
    enabled: target: extraModules:
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
          programs.local-tts.bridge.enable = enabled;
          programs.local-tts.target = target;
        }
      ]
      ++ extraModules;
    };
  evaluate = enabled: target: evaluate' enabled target [ ];
  home = evaluate true null;
  disabled = evaluate false null;
  absent = evaluate null null;
  targeted = evaluate true "bluez_output.test";
  handy = evaluate' true null [
    ./handy.nix
    { services.handy.enable = true; }
  ];
  voice = evaluate' true null [
    ./handy.nix
    {
      services.handy.enable = true;
      programs.local-tts.bridge.natsUrl = "nats://127.0.0.1:4222";
      programs.local-tts.voiceControl.enable = true;
      services.handy.package = pkgs.hello;
    }
  ];
  speechVolume = "alt + {XF86AudioLowerVolume,XF86AudioRaiseVolume}";
in
assert !(home.config.systemd.user.services ? voice-controller);
assert voice.config.systemd.user.services.voice-controller.Service.Restart == "on-failure";
assert
  builtins.match ".*adapter.*--handy.*" (
    builtins.head voice.config.systemd.user.services.handy-adapter.Service.ExecStart
  ) != null;
assert !(home.config.services.sxhkd.keybindings ? ${speechVolume});
assert
  targeted.config.services.sxhkd.keybindings."alt + {button7,button6}"
  == targeted.config.services.sxhkd.keybindings.${speechVolume};
assert !(absent.config.services.sxhkd.keybindings ? ${speechVolume});
assert !(absent.config.services.sxhkd.keybindings ? "XF86AudioNext");
assert !(home.config.services.sxhkd.keybindings ? "XF86AudioPrev");
assert home.config.services.sxhkd.keybindings.XF86AudioNext == "speech-emergency-stop";
assert
  builtins.match ".*/bin/xdotool key Pause" handy.config.services.sxhkd.keybindings.XF86AudioPrev
  != null;
assert
  builtins.match ".*speech-volume \\{-,\\+}5%"
    targeted.config.services.sxhkd.keybindings.${speechVolume} != null;
assert !(absent.config.services.sxhkd.keybindings ? "control + shift + Pause");
assert !(disabled.config.services.sxhkd.keybindings ? "control + shift + Pause");
assert home.config.services.sxhkd.keybindings."control + shift + Pause" == "speech-emergency-stop";
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

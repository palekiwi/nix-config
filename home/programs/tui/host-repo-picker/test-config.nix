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
  vm =
    (pkgs.lib.evalModules {
      specialArgs = {
        inherit pkgs;
        inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system}.tmux-window-picker =
          pkgs.emptyDirectory;
      };
      modules = [
        ../../../../vm/agent/tmux.nix
        {
          options = {
            programs.tmux = pkgs.lib.mkOption { type = pkgs.lib.types.attrs; };
            environment.systemPackages = pkgs.lib.mkOption {
              type = pkgs.lib.types.listOf pkgs.lib.types.package;
            };
            systemd.tmpfiles.rules = pkgs.lib.mkOption { type = pkgs.lib.types.listOf pkgs.lib.types.str; };
          };
        }
      ];
    }).config;
  picker = import ./. { inherit pkgs; };
in
pkgs.linkFarm "host-repo-picker-test-config" [
  {
    name = "tmux.conf";
    path = home.config.xdg.configFile."tmux/tmux.conf".source;
  }
  {
    name = "vm-tmux.conf";
    path = pkgs.writeText "vm-tmux-test.conf" vm.programs.tmux.extraConfig;
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
    name = "status";
    path = import ../tmux/status-repo.nix { inherit pkgs; };
  }
  {
    name = "picker";
    path = picker;
  }
]

{ pkgs, ... }:

let
  shared = import ./tmux-config.nix {
    inherit pkgs;
    copyCommand = "echo -n {} | xclip -selection clipboard";
  };
in
{
  home.packages = [ pkgs.tmux ] ++ shared.packages;

  programs.tmux = {
    baseIndex = 1;
    enable = true;
    keyMode = "vi";
    mouse = true;
    prefix = "M-g";
    plugins = shared.plugins;
    extraConfig = shared.extraConfig;
  };
}

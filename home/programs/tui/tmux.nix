{ pkgs, lib, ... }:

let
  picker = import ./host-repo-picker { inherit pkgs; };
  shared = import ./tmux-config.nix {
    inherit pkgs;
    copyCommand = "echo -n {} | xclip -selection clipboard";
    hostColour = "colour208";
  };
in
{
  home.packages = [
    pkgs.tmux
    picker
  ]
  ++ shared.packages;
  xdg.configFile."tmux/repos.toml".source = ../../config/tmux/repos.toml;

  programs.tmux = {
    baseIndex = 1;
    enable = true;
    keyMode = "vi";
    mouse = true;
    prefix = "M-g";
    plugins = shared.plugins;
    extraConfig = lib.mkAfter (
      shared.extraConfig
      + ''
        bind-key -n C-f run-shell -b '${pkgs.tmux}/bin/tmux display-popup -c #{q:client_name} -E -w 90% -h 55% ${picker}/bin/host-repo-picker --client #{q:client_name} --session #{q:session_id}'
        bind-key w choose-tree -w
        set -g status 2
        set -g status-left ' #[fg=colour208,bold]#{host_short}#[fg=colour7,nobold]:#{session_name} '
        set -g status-left-length 40
        set -g status-format[1] '#[align=left]#(_tmux_status-repo #{q:pane_current_path} --full-branch)'
        setw -g window-status-format ' #I:#{?@host-repo-name,#{@host-repo-name},#W} '
        setw -g window-status-current-format ' #I:#{?@host-repo-name,#{@host-repo-name},#W} '
      ''
    );
  };
}

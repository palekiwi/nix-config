{ pkgs, inputs, ... }:
let
  cp = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system};
  shared = import ../../../home/programs/tui/tmux-config.nix {
    inherit pkgs;
    copyCommand = "tmux set-buffer -w -- {}";
  };
  picker = "${cp.tmux-window-picker}/bin/tmux-window-picker";
in
{
  home.packages = [ pkgs.sesh ] ++ shared.packages;

  xdg.configFile."sesh/sesh.toml".source = ../../../home/config/sesh/sesh.toml;

  programs.tmux = {
    enable = true;
    plugins = map (
      p:
      if p == pkgs.tmuxPlugins.yank then
        {
          plugin = p;
          extraConfig = "set -g @override_copy_command 'tmux load-buffer -w -'";
        }
      else
        p
    ) shared.plugins;
    extraConfig = shared.extraConfig + ''
      set -g extended-keys on
      set -g extended-keys-format csi-u
      bind-key w display-popup -E -w 90% -h 55% ${picker}
      bind-key -n C-f display-popup -E -w 90% -h 55% ${picker}
      bind-key C new-window -c "#{pane_current_path}" \; send-keys pi Enter

      # Windows running pi show only a pi state mark from @pi_state
      # (tmux-state), matching the window picker colours: ● working
      # (orange), ✖ blocked (red), ○ green while @pi_unseen (idle,
      # unseen result), else plain ○. Other windows show their index.
      setw -g window-status-format ' #{?@pi_state,#{?#{==:#{@pi_state},working},#[fg=colour3]●#[fg=default] ,#{?#{==:#{@pi_state},blocked},#[fg=colour1]✖#[fg=default] ,#{?@pi_unseen,#[fg=colour2]●#[fg=default] ,○ }}}, #I }'
      setw -g window-status-current-format ' #{?@pi_state,#{?#{==:#{@pi_state},working},#[fg=colour3]●#[fg=default] ,#{?#{==:#{@pi_state},blocked},#[fg=colour1]✖#[fg=default] ,#{?@pi_unseen,#[fg=colour2]●#[fg=default] ,○ }}}, #I }'
    '';
  };
}

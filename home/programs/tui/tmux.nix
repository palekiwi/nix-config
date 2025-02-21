{ pkgs, ... }:

let
  fg = "colour10";

  tmux_view_output = pkgs.writeShellScript "tmux_view_output" ''
    file=`mktemp`.sh
    tmux capture-pane -J -pS -32768 > $file
    tmux new-window "nvim '+ normal G $' $file"
  '';

  tmux_list_sessions = pkgs.writeShellScript "tmux_list_sessions" ''
    tmux list-sessions -F '#S' | fzf --reverse | xargs tmux switch-client -t
  '';

  widgets = {
    sessionName = ''#[fg=color7,bold]#(echo "#{session_name}")'';
    gitIcon = ''#[default,fg=green]#([ -d .git ] && echo "")'';
    gitBranch = ''#(cd #{pane_current_path}; git rev-parse --abbrev-ref HEAD)'';
  };

  statusLeft = with widgets; '' ${sessionName} ${gitIcon} ${gitBranch} '';
in
{
  home.packages = with pkgs; [ tmux ];

  programs.tmux = {
    baseIndex = 1;
    enable = true;
    keyMode = "vi";
    mouse = true;
    prefix = "M-g";
    plugins = [
      pkgs.tmuxPlugins.sensible
      pkgs.tmuxPlugins.yank
    ];

    extraConfig = ''
      set -ga terminal-overrides ",xterm-256color:Tc"

      bind -n M-C-e split-window -v ${tmux_list_sessions}
      bind -n M-C-m run-shell ${tmux_view_output}

      bind -n M-n select-window -t1
      bind -n M-e select-window -t2
      bind -n M-i select-window -t3
      bind -n M-o select-window -t4

      bind -n M-q kill-session

      bind -n M-C-y send-keys -R\; clear-history

      bind-key -n M-y copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # don't do anything when a 'bell' rings
      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence off
      setw -g monitor-activity off
      set -g bell-action none

      # clock mode
      setw -g clock-mode-colour ${fg}

      # copy mode
      setw -g mode-style 'fg=colour1 bg=colour18 bold'

      # pane borders
      set -g pane-border-style 'fg=${fg}'
      set -g pane-active-border-style 'fg=colour3'

      # statusbar
      set-option -g status-style bg=default
      set -g status-position top
      set -g status-justify left
      set -g status-style 'fg=${fg}'
      set -g status-left '${statusLeft}'
      set -g status-right ""
      set -g status-right-length 80
      set -g status-left-length 80

      setw -g window-status-current-style 'fg=colour15'
      setw -g window-status-current-format '#W'

      setw -g window-status-style 'fg=colour7 dim'
      setw -g window-status-format '#W'

      setw -g window-status-bell-style 'fg=colour2 bg=colour1 bold'

      # messages
      set -g message-style 'fg=colour2 bg=colour0 bold'
    '';
  };
}

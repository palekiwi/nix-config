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
    sessionName = ''#[fg=blue,bold]#{host_short}#[fg=color7]:#{session_name}'';
    gitIcon = ''#[default,fg=green]#([ -d .git ] && echo "")'';
    # Branch name recolored (yellow, bold) when the branch is behind
    # the default branch (branch.<name>.behindDefault from git-pr-sync).
    # Self-contained styles on both paths; detached HEAD falls back to
    # the plain rev-parse output (branch.HEAD.* is never set).
    gitBranch = ''#(cd #{pane_current_path}; B=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null) && [ -n "$B" ] && D=$(git config "branch.$B.behindDefault" 2>/dev/null || true) && { [ -n "$D" ] && echo "#[fg=yellow,bold]$B" || echo "#[fg=green]$B"; })'';
    prInfo = ''#[fg=green,dim,bold]#(cd #{pane_current_path}; B=$(git symbolic-ref --short HEAD 2>/dev/null) && [ -n "$B" ] && PR=$(git config "branch.$B.pr" 2>/dev/null) && [ -n "$PR" ] && BASE=$(git config "branch.$B.base" 2>/dev/null) && [ -n "$BASE" ] && BB=$(git config "branch.$B.behindBase" 2>/dev/null || true) && echo "#$PR #[fg=white,nobold,dim]-> #[fg=$([ -n "$BB" ] && echo "yellow" || echo "white"),bold]$BASE" || echo "")'';
    # Active cue scope (".cue/HEAD"). Hides itself outside a cue-enabled dir;
    # falls back to "master" when HEAD is missing or empty.
    cueScope = ''#[fg=colour15,bold]#(cd #{pane_current_path} && [ -d .cue ] && { s=$(cat .cue/HEAD 2>/dev/null); [ -n "$s" ] && echo "$s" || echo master; })'';
  };

  statusLeft = with widgets; '' ${sessionName} ${cueScope} ${gitIcon} ${gitBranch} ${prInfo} '';
in
{
  home.packages = with pkgs; [
    tmux
  ] ++ (import ./tmux { inherit pkgs; });

  programs.tmux = {
    baseIndex = 1;
    enable = true;
    keyMode = "vi";
    mouse = true;
    prefix = "M-g";
    plugins = [
      pkgs.tmuxPlugins.sensible
      pkgs.tmuxPlugins.tmux-thumbs
      pkgs.tmuxPlugins.yank
    ];

    extraConfig = ''
      set -g default-terminal "tmux"

      set -ga terminal-overrides ",xterm-256color:Tc"

      # ============================================
      # OSC 52 Clipboard Support (NEW)
      # ============================================

      # Enable clipboard integration
      set -g set-clipboard on

      # Allow escape sequences to pass through tmux
      set -g allow-passthrough on

      # Add OSC 52 support to terminal capabilities
      # (Ms must reference %p1 before %p2; skipping %p1 makes the tiparm
      # expansion fail and tmux silently emits nothing)
      set -ga terminal-overrides ',xterm-256color:Tc:Ms=\E]52;%p1%s;%p2%s\007'
      # set -as terminal-overrides ',*:Ms=\E]52;%p1%s;%p2%s\007'

      # ============================================

      set -g @thumbs-command 'echo -n {} | xclip -selection clipboard'

      # copy active pane's git branch to buffer + system clipboard
      # (prefix b; prefix y is taken by tmux-yank's copy-line)
      bind-key b run-shell -b "_tmux_copy-branch '#{pane_current_path}'"

      # copy active pane's base PR branch to buffer + system clipboard
      bind-key B run-shell -b "_tmux_copy-pr-base '#{pane_current_path}'"

      # copy active pane's pwd to buffer + system clipboard
      bind-key p run-shell -b "_tmux_copy-pwd '#{pane_current_path}'"

      # copy active pane's active cue task slug to buffer + system clipboard
      bind-key t run-shell -b "_tmux_copy-cue-task '#{pane_current_path}'"

      bind -n M-C-e split-window -v ${tmux_list_sessions}
      bind -n M-C-m run-shell ${tmux_view_output}

      bind -n M-n select-window -t1
      bind -n M-e select-window -t2
      bind -n M-i select-window -t3
      bind -n M-o select-window -t4
      bind -n M-h select-window -t5

      bind -n M-C-y send-keys -R\; clear-history

      bind-key -n M-y copy-mode -e
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
      set -g status-left-length 140

      setw -g window-status-current-style "fg=color15"
      setw -g window-status-current-format ' #I '

      setw -g window-status-style 'fg=colour7 dim'
      setw -g window-status-format ' #I '

      setw -g window-status-bell-style 'fg=colour2 bg=colour1 bold'

      # messages
      set -g message-style 'fg=colour2 bg=colour0 bold'
    '';
  };
}

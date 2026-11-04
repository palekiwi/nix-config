{ pkgs, inputs, ... }:
let
  cp = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system};
  shared = import ../../home/programs/tui/tmux-config.nix {
    inherit pkgs;
    copyCommand = "tmux set-buffer -w -- {}";
  };
  picker = "${cp.tmux-window-picker}/bin/tmux-window-picker";
in
{
  programs.tmux = {
    enable = true;
    plugins = shared.plugins;
    extraConfigBeforePlugins = ''
      set -g @override_copy_command 'tmux load-buffer -w -'
    '';
    extraConfig = shared.extraConfig + ''
      set -g extended-keys on
      set -g extended-keys-format csi-u
      bind-key w display-popup -E -w 90% -h 55% ${picker}
      bind-key -n C-f display-popup -E -w 90% -h 55% ${picker}
      bind-key C new-window -c "#{pane_current_path}" \; send-keys pi Enter
    '';
  };

  environment.systemPackages = [ pkgs.sesh pkgs.kitty.terminfo ] ++ shared.packages;

  systemd.tmpfiles.rules = [
    "d /home/pl/.config/sesh 0755 pl users -"
    "L+ /home/pl/.config/sesh/sesh.toml - - - - ${../../home/config/sesh/sesh.toml}"
  ];
}

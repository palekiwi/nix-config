{ pkgs, inputs, ... }:
let
  cp = inputs.cue-platform.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    cp.pi
    cp.cue
    cp.cue-agent
    cp.cue-recall
    cp.cue-review
    cp.tmux
    cp.gh
    cp.jq
  ];

  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];
}

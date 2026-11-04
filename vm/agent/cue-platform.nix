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
    cp.gh
    cp.jq
  ];
}

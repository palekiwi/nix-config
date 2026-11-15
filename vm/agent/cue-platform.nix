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
    cp.station
    cp.cue-supervisor
    cp.gh
    cp.jq
  ];

  environment.variables = {
    CUE_DELEGATE_BACKEND = "supervisor";
    CUE_NATS_URL = "nats://127.0.0.1:4222";
    CUE_NATS_JS_DOMAIN = "pale";
  };
}

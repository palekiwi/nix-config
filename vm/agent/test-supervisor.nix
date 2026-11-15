{ flake }:
let
  config = flake.nixosConfigurations.pale.config.microvm.vms.agent.config.config;
  service = config.systemd.user.services.cue-supervisor;
  env = service.environment;
  lib = flake.inputs.nixpkgs.lib;
  cp = flake.inputs.cue-platform.packages.x86_64-linux;
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  clientEnv = config.environment.variables;
in
assert service.wantedBy == [ "default.target" ];
assert service.unitConfig.ConditionUser == "pl";
assert service.serviceConfig.Restart == "on-failure";
assert service.serviceConfig.UMask == "0077";
assert lib.hasSuffix "/bin/cue-supervisor daemon" service.serviceConfig.ExecStart;
assert !(lib.hasInfix "nix develop" service.serviceConfig.ExecStart);
assert env.CUE_SUPERVISOR_STATE == "/home/pl/.local/state/cue-supervisor";
assert clientEnv.CUE_DELEGATE_BACKEND == "supervisor";
assert clientEnv.CUE_NATS_URL == "nats://127.0.0.1:${toString endpoint.clientPort}";
assert clientEnv.CUE_NATS_JS_DOMAIN == endpoint.jsDomain;
assert env.CUE_DELEGATE_BACKEND == clientEnv.CUE_DELEGATE_BACKEND;
assert env.CUE_NATS_URL == clientEnv.CUE_NATS_URL;
assert env.CUE_NATS_JS_DOMAIN == clientEnv.CUE_NATS_JS_DOMAIN;
assert builtins.all (package: builtins.elem package config.environment.systemPackages) [
  cp.pi
  cp.cue-review
  cp.cue-supervisor
];
assert builtins.all (package: builtins.elem package service.path) [
  cp.pi
  cp.cue-review
  cp.cue-supervisor
];
assert env.CUE_STORE == "/home/pl/cue";
assert env.HTTPS_PROXY == config.environment.variables.HTTPS_PROXY;
assert env.NODE_EXTRA_CA_CERTS == config.environment.variables.NODE_EXTRA_CA_CERTS;
assert env.GEMINI_API_KEY == config.environment.variables.GEMINI_API_KEY;
assert env.TYPESAFE_API_KEY == config.environment.variables.TYPESAFE_API_KEY;
assert env.SSL_CERT_FILE == config.security.pki.caBundle;
assert env.NIX_SSL_CERT_FILE == config.security.pki.caBundle;
assert env.NIX_PROFILES != "";
assert env.NIX_USER_PROFILE_DIR == "/nix/var/nix/profiles/per-user/pl";
{
  execStart = service.serviceConfig.ExecStart;
  environmentNames = builtins.attrNames env;
}

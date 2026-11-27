{ flake }:
let
  vm = flake.nixosConfigurations.pale.config.microvm.vms.agent.config.config;
  home = flake.homeConfigurations."pl@casm".config;
  service = home.systemd.user.services.cue-supervisor;
  lib = flake.inputs.nixpkgs.lib;
  cp = flake.inputs.cue-platform.packages.x86_64-linux;
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  clientEnv = vm.environment.variables;
  envFile = vm.environment.etc."agent-vm/environment".text;
  hasLine = line: builtins.elem line (lib.splitString "\n" envFile);
in
assert service.Install.WantedBy == [ "default.target" ];
assert service.Service.Restart == "on-failure";
assert service.Service.UMask == "0077";
assert lib.elem "/etc/agent-vm/environment" (lib.toList service.Service.EnvironmentFile);
assert lib.any (lib.hasSuffix "cue-supervisor-environment") (lib.toList service.Service.EnvironmentFile);
assert lib.last (lib.toList service.Service.EnvironmentFile) != "/etc/agent-vm/environment";
assert lib.hasSuffix "/bin/cue-supervisor daemon" (builtins.head service.Service.ExecStart);
assert builtins.elem "CUE_STORE=/home/pl/cue" service.Service.Environment;
assert builtins.elem "CUE_SUPERVISOR_STATE=/home/pl/.local/state/cue-supervisor" service.Service.Environment;
assert clientEnv.CUE_DELEGATE_BACKEND == "supervisor";
assert clientEnv.CUE_NATS_URL == "nats://127.0.0.1:${toString endpoint.clientPort}";
assert clientEnv.CUE_NATS_JS_DOMAIN == endpoint.jsDomain;
assert hasLine "CUE_DELEGATE_BACKEND=${clientEnv.CUE_DELEGATE_BACKEND}";
assert hasLine "CUE_NATS_URL=${clientEnv.CUE_NATS_URL}";
assert hasLine "HTTPS_PROXY=${clientEnv.HTTPS_PROXY}";
assert hasLine "NODE_EXTRA_CA_CERTS=${clientEnv.NODE_EXTRA_CA_CERTS}";
assert hasLine "GEMINI_API_KEY=${clientEnv.GEMINI_API_KEY}";
assert hasLine "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt";
assert builtins.all (package: builtins.elem package home.home.packages) [
  cp.pi
  cp.cue-review
  cp.cue-supervisor
];
assert !(builtins.elem cp.pi vm.environment.systemPackages);
{
  execStart = builtins.head service.Service.ExecStart;
  environmentFile = service.Service.EnvironmentFile;
}

{ flake }:
let
  inherit (flake.inputs.nixpkgs) lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  evaluated = flake.nixosConfigurations.pale.extendModules {
    modules = [
      {
        microvm.vms.agent.config.services.github-service = {
          package = pkgs.hello;
          executable = "hello";
        };
      }
    ];
  };
  host = evaluated.config;
  vm = host.microvm.vms.agent.config.config;
  cfg = vm.services.github-service;
  service = vm.systemd.services.github-service;
  env = service.environment;
  unit = "${vm.systemd.units."github-service.service".unit}/github-service.service";
  configRule = lib.findFirst (lib.hasPrefix "L+ ${cfg.configFile} ") null vm.systemd.tmpfiles.rules;
  configSource = lib.last (lib.splitString " " configRule);
  disabled = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ../../modules/github-service.nix ];
    specialArgs.inputs = { };
  };
  accounts = host.services.nats.settings.accounts;
  routing = pkgs.writeText "github-routing.json" (
    builtins.toJSON {
      host = "127.0.0.1";
      port = 14222;
      no_auth_user = "host";
      accounts = {
        HOST = builtins.removeAttrs accounts.HOST [ "jetstream" ];
        AGENT = (builtins.removeAttrs accounts.AGENT [ "jetstream" ]) // {
          users = [
            {
              user = "github-test-agent";
              password = "github-test-only";
            }
          ];
        };
      };
    }
  );
  python = pkgs.python3.withPackages (ps: [ ps.nats-py ]);
in
assert !(disabled.config.systemd.services ? github-service);
assert !(host.systemd.services ? github-service);
assert vm.palekiwi.machineRole == "vm";
assert cfg.repositories == [ "spabreaks/spabreaks" ];
assert cfg.pollInterval == 120;
assert cfg.stateDirectory == "/home/pl/.local/state/cue/github";
assert cfg.configFile == "/home/pl/.config/cue/github.toml";
assert cfg.natsUrl == "nats://127.0.0.1:4222";
assert service.wantedBy == [ "multi-user.target" ];
assert builtins.elem "agent-nats-leaf.service" service.after;
assert service.serviceConfig.User == "pl";
assert service.serviceConfig.UMask == "0077";
assert service.serviceConfig.ProtectHome == "read-only";
assert service.serviceConfig.ProtectSystem == "strict";
assert service.serviceConfig.ReadWritePaths == [ cfg.stateDirectory ];
assert service.serviceConfig.Restart == "on-failure";
assert service.serviceConfig.ExecStart == "${pkgs.hello}/bin/hello --config ${cfg.configFile}";
assert map toString service.restartTriggers == [ configSource ];
assert builtins.elem "d ${cfg.stateDirectory} 0700 pl users -" vm.systemd.tmpfiles.rules;
assert builtins.elem pkgs.gh service.path;
assert env.HOME == "/home/pl";
assert env.XDG_STATE_HOME == "/home/pl/.local/state";
assert env.GH_TOKEN == "PLACEHOLDER-gh-spabreaks";
assert env.GH_PROMPT_DISABLED == "1";
assert !(env ? GEMINI_API_KEY);
assert env.HTTPS_PROXY == vm.environment.variables.HTTPS_PROXY;
assert env.HTTP_PROXY == vm.environment.variables.HTTP_PROXY;
assert env.https_proxy == vm.environment.variables.https_proxy;
assert env.http_proxy == vm.environment.variables.http_proxy;
assert env.NO_PROXY == vm.environment.variables.NO_PROXY;
assert env.no_proxy == vm.environment.variables.no_proxy;
assert env.NODE_EXTRA_CA_CERTS == vm.environment.variables.NODE_EXTRA_CA_CERTS;
assert env.SSL_CERT_FILE == vm.security.pki.caBundle;
assert env.NIX_SSL_CERT_FILE == vm.security.pki.caBundle;
pkgs.runCommand "github-service-config-and-routing"
  {
    nativeBuildInputs = [
      pkgs.nats-server
      python
    ];
  }
  ''
    test -f ${unit}
    grep -F 'ProtectHome=read-only' ${unit}
    grep -F 'User=pl' ${unit}
    python - ${configSource} <<'PY'
    import sys
    import tomllib

    with open(sys.argv[1], "rb") as source:
        assert tomllib.load(source) == {
            "repositories": ["spabreaks/spabreaks"],
            "poll_seconds": 120,
            "nats_url": "nats://127.0.0.1:4222",
        }
    PY
    nats-server -t -c ${routing}
    nats-server -c ${routing} > nats.log 2>&1 &
    server=$!
    trap 'kill "$server"; wait "$server" || true' EXIT
    python ${./test_github_routing.py}
    touch $out
  ''

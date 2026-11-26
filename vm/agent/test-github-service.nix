{ flake }:
let
  inherit (flake.inputs.nixpkgs) lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  host = flake.nixosConfigurations.pale.config;
  vm = host.microvm.vms.agent.config.config;
  home = flake.homeConfigurations."pl@casm".config;
  service = home.systemd.user.services.github-service;
  env = builtins.listToAttrs (
    map (
      entry:
      let
        unquoted = lib.removeSuffix "'" (lib.removePrefix "'" entry);
        parts = lib.splitString "=" unquoted;
      in
      lib.nameValuePair (builtins.unsafeDiscardStringContext (builtins.head parts)) (lib.concatStringsSep "=" (builtins.tail parts))
    ) service.Service.Environment
  );
  configSource = home.xdg.configFile."cue/github.toml".source;
  unit = "${home.xdg.configFile."systemd/user/github-service.service".source}";
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
assert !(vm.systemd.services ? github-service);
assert !(host.systemd.services ? github-service);
assert service.Install.WantedBy == [ "default.target" ];
assert service.Service.UMask == "0077";
assert service.Service.ProtectHome == "read-only";
assert service.Service.ProtectSystem == "strict";
assert service.Service.ReadWritePaths == [ "/home/pl/.local/state/cue/github" ];
assert service.Service.Restart == "on-failure";
assert lib.hasSuffix "/bin/cue-github --config /home/pl/.config/cue/github.toml" (builtins.head service.Service.ExecStart);
assert map toString service.Unit.X-Restart-Triggers == [ "${configSource}" ];
assert lib.hasPrefix "${pkgs.gh}/bin:" env.PATH;
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
assert env.SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt";
assert env.NIX_SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt";
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

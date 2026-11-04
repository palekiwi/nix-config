{ lib, pkgs, ... }:
let
  tap = "vm-agent";
  listenAddr = "10.77.0.1";
  guestAddr = "10.77.0.2";
  port = 3128;
  user = "agent-proxy";
  tapUnit = "microvm-tap-interfaces@agent.service";
  secretsDir = "/run/secrets/agent-proxy";
  # Every secret the egress proxy can read is declared here and nowhere else.
  # Only read-only scoped tokens may be added; typesafe/api_key has no scopes
  # and is an accepted exception.
  injections = {
    github = {
      secret = "github/palekiwi/gh_cli_readonly";
      placeholder = "PLACEHOLDER-github";
      hosts = [ "github.com" "api.github.com" ];
    };
    typesafe = {
      secret = "typesafe/api_key";
      placeholder = "PLACEHOLDER-typesafe";
      hosts = [ "api.typesafe.ai" ];
    };
  };
  rulesFile = pkgs.writeText "agent-egress-proxy-rules.json" (builtins.toJSON
    (lib.mapAttrsToList (name: r: { inherit name; inherit (r) placeholder hosts; }) injections));
  interceptHosts = lib.unique (lib.concatMap (r: r.hosts) (lib.attrValues injections));
  allowHosts = "^(${lib.concatMapStringsSep "|" lib.escapeRegex interceptHosts}):443$";
  deniedUpstream = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "224.0.0.0/4"
    "240.0.0.0/4"
    "::/128"
    "::1/128"
    "::ffff:0:0/96"
    "64:ff9b::/96"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];
in
{
  sops.secrets = {
    "agent-proxy/ca" = {
      owner = user;
      restartUnits = [ "agent-egress-proxy.service" ];
    };
  } // lib.mapAttrs' (name: r: lib.nameValuePair "agent-proxy/${name}" {
    key = r.secret;
    owner = user;
    restartUnits = [ "agent-egress-proxy.service" ];
  }) injections;

  users.users.${user} = {
    isSystemUser = true;
    group = user;
  };
  users.groups.${user} = { };

  systemd.services.agent-egress-proxy = {
    description = "Egress proxy for the agent microVM";
    bindsTo = [ tapUnit ];
    after = [ tapUnit ];
    wantedBy = [ tapUnit ];
    environment = {
      AGENT_PROXY_SECRETS_DIR = secretsDir;
      AGENT_PROXY_RULES = rulesFile;
    };
    serviceConfig = {
      User = user;
      Group = user;
      RuntimeDirectory = "agent-egress-proxy";
      RuntimeDirectoryMode = "0700";
      ExecStartPre = pkgs.writeShellScript "agent-egress-proxy-confdir" ''
        install -m 0600 ${secretsDir}/ca "$RUNTIME_DIRECTORY/mitmproxy-ca.pem"
      '';
      ExecStart = lib.escapeShellArgs [
        (lib.getExe' pkgs.mitmproxy "mitmdump")
        "--mode" "regular@${toString port}"
        "--listen-host" listenAddr
        "--set" "confdir=/run/agent-egress-proxy"
        "--set" "allow_hosts=${allowHosts}"
        "--set" "flow_detail=0"
        "--set" "termlog_verbosity=warn"
        "--set" "stream_large_bodies=1m"
        "-s" "${./egress.py}"
      ];
      Restart = "on-failure";
      RestartSec = 2;

      IPAddressAllow = [ "${guestAddr}/32" ];
      IPAddressDeny = deniedUpstream;

      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@privileged" ];
      UMask = "0077";
    };
  };

  networking.firewall.extraCommands = lib.mkAfter ''
    iptables -w -D INPUT -p tcp --dport ${toString port} -j agent-proxy-guard 2>/dev/null || true
    iptables -w -N agent-proxy-guard 2>/dev/null || true
    iptables -w -F agent-proxy-guard
    iptables -w -A agent-proxy-guard -i ${tap} -s ${guestAddr} -d ${listenAddr} -j ACCEPT
    iptables -w -A agent-proxy-guard -j DROP
    iptables -w -I INPUT -p tcp --dport ${toString port} -j agent-proxy-guard
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D INPUT -p tcp --dport ${toString port} -j agent-proxy-guard 2>/dev/null || true
    iptables -w -F agent-proxy-guard 2>/dev/null || true
    iptables -w -X agent-proxy-guard 2>/dev/null || true
  '';
}

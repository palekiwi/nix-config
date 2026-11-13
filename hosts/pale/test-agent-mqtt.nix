{ flake }:
let
  config = flake.nixosConfigurations.pale.config;
  lib = flake.inputs.nixpkgs.lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  endpoint = import ../../modules/agent-mqtt/endpoint.nix;
  guest = config.microvm.vms.agent.config.config;
  home = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../home/services/agent-mqtt.nix
      {
        home.username = "pl";
        home.homeDirectory = "/home/pl";
        home.stateVersion = "24.11";
        services.agent-mqtt.enable = true;
      }
    ];
  };
  consumer = home.config.systemd.user.services.agent-mqtt-speech;
  listener = guest.systemd.user.services.agent-mqtt-inbox;
  secrets = config.sops.secrets;
  mqttSources = map (name: builtins.readFile (../../modules/agent-mqtt + "/${name}")) [
    "default.nix"
    "broker.nix"
    "endpoint.nix"
  ];
  mqtt = config.services.mosquitto;
  unit = config.systemd.services.mosquitto;
  tapUnit = "microvm-tap-interfaces@agent.service";
  vmUnit = "microvm@agent.service";
  lines = text: lib.filter (line: line != "") (map lib.trim (lib.splitString "\n" text));
  start = lines config.networking.firewall.extraCommands;
  stop = lines config.networking.firewall.extraStopCommands;
  guard = [
    "iptables -w -D INPUT -p tcp --dport 18830 -j agent-mqtt-guard 2>/dev/null || true"
    "iptables -w -N agent-mqtt-guard 2>/dev/null || true"
    "iptables -w -F agent-mqtt-guard"
    "iptables -w -A agent-mqtt-guard -i vm-agent -s 10.77.0.2 -d 10.77.0.1 -j ACCEPT"
    "iptables -w -A agent-mqtt-guard -j DROP"
    "iptables -w -I INPUT -p tcp --dport 18830 -j agent-mqtt-guard"
  ];
  cleanup = [
    "iptables -w -D INPUT -p tcp --dport 18830 -j agent-mqtt-guard 2>/dev/null || true"
    "iptables -w -F agent-mqtt-guard 2>/dev/null || true"
    "iptables -w -X agent-mqtt-guard 2>/dev/null || true"
  ];
  indexOf =
    line:
    let
      found = lib.lists.findFirstIndex (candidate: candidate == line) null start;
    in
    assert found != null;
    found;
  sublist =
    needle: haystack:
    lib.any (i: lib.sublist i (lib.length needle) haystack == needle) (
      lib.range 0 (lib.length haystack)
    );
  listenerAt =
    address: port:
    let
      matches = lib.filter (l: l.address == address && l.port == port) mqtt.listeners;
    in
    assert lib.length matches == 1;
    builtins.head matches;
  guestListener = listenerAt "10.77.0.1" 18830;
  hostListener = listenerAt "127.0.0.1" 18831;
  namedUsers = lib.foldl' (acc: l: acc // l.users) { } mqtt.listeners;
  users = lib.attrValues namedUsers;
  aclLines = lib.concatMap (u: u.acl) users;
  explicit = line: builtins.match "(read|write|readwrite|deny) [^ ]+" line != null;
  aclOf = listener: lib.mapAttrs (_: u: u.acl) listener.users;
  allowed = unit.serviceConfig.IPAddressAllow;
in
assert endpoint.host == "10.77.0.1";
assert endpoint.guestPort == 18830;
assert endpoint.hostPort == 18831;
assert endpoint.topics.speechRequest == "vm/speech/request";
assert endpoint.topics.inbox == "host/agent/+/inbox";
assert endpoint.topics.agentInbox "a" == "host/agent/a/inbox";
assert config.networking.firewall.enable;
assert !config.networking.nftables.enable;
assert sublist guard start;
assert sublist cleanup stop;
assert
  indexOf "iptables -w -I INPUT -p tcp --dport 18830 -j agent-mqtt-guard"
  > indexOf "ip46tables -w -I INPUT -i vm-agent -j agent-vm-in";
assert !(lib.elem 18830 config.networking.firewall.allowedTCPPorts);
assert !(lib.elem 18831 config.networking.firewall.allowedTCPPorts);
assert mqtt.enable;
assert !mqtt.persistence;
assert mqtt.settings.retain_available == false;
assert mqtt.settings.sys_interval == 0;
assert mqtt.settings.global_max_connections > guestListener.settings.max_connections;
assert lib.length mqtt.listeners == 2;
assert guestListener.settings.listener_allow_anonymous == false;
assert guestListener.settings.max_connections == 4;
assert guestListener.settings.max_qos == 0;
assert guestListener.settings.use_username_as_clientid;
assert hostListener.settings.listener_allow_anonymous == false;
assert hostListener.settings.use_username_as_clientid;
assert
  aclOf guestListener == {
    vm-speech = [ "write vm/speech/request" ];
    vm-inbox = [ "read host/agent/+/inbox" ];
  };
assert
  aclOf hostListener == {
    host-speech = [ "read vm/speech/request" ];
    host-inbox = [ "write host/agent/+/inbox" ];
  };
assert lib.all (l: l.acl == [ ] && !l.omitPasswordAuth) mqtt.listeners;
assert aclLines != [ ] && lib.all explicit aclLines;
assert
  lib.attrNames namedUsers == [
    "host-inbox"
    "host-speech"
    "vm-inbox"
    "vm-speech"
  ];
assert lib.all (u: u.password == null && u.passwordFile == null && u.hashedPassword == null) users;
assert lib.all (
  name:
  namedUsers.${name}.hashedPasswordFile == secrets."agent-mqtt/${name}/hash".path
  && secrets."agent-mqtt/${name}/hash".path == "/run/secrets/agent-mqtt/${name}/hash"
  && lib.elem secrets."agent-mqtt/${name}/hash".owner [
    null
    "root"
  ]
) (lib.attrNames namedUsers);
assert lib.all (
  name:
  secrets."agent-mqtt/${name}/password".owner == "pl"
  && secrets."agent-mqtt/${name}/password".mode == "0400"
  && secrets."agent-mqtt/${name}/password".path == endpoint.credentials.hostPasswordFile name
) endpoint.credentials.hostUsers;
assert lib.all (name: !(secrets ? "agent-mqtt/${name}/password")) endpoint.credentials.guestUsers;
assert !builtins.pathExists ../../modules/agent-mqtt/guest-credentials.nix;
assert !builtins.pathExists ../../modules/agent-mqtt/hashes.nix;
assert lib.all (src: !lib.hasInfix "$7$" src && !lib.hasInfix "hashedPassword =" src) mqttSources;
assert consumer.Install.WantedBy == [ "default.target" ];
assert
  consumer.Service.Environment == [
    "AGENT_MQTT_PASSWORD_FILE=${secrets."agent-mqtt/host-speech/password".path}"
  ];
assert consumer.Service.RestartPreventExitStatus == 78;
assert consumer.Service.Restart == "always";
assert listener.wantedBy == [ "default.target" ];
assert listener.unitConfig.ConditionUser == "pl";
assert listener.serviceConfig.RestartPreventExitStatus == 78;
assert listener.environment.AGENT_MQTT_AGENTS == "pi";
assert lib.elem "d /var/lib/agent-mqtt 0700 pl users -" guest.systemd.tmpfiles.rules;
assert lib.any (v: v.mountPoint == "/var") guest.microvm.volumes;
assert lib.hasPrefix "/var/" (endpoint.credentials.guestPasswordFile "vm-inbox");
assert unit.bindsTo == [ tapUnit ];
assert lib.elem tapUnit unit.after;
assert unit.before == [ vmUnit ];
assert unit.wantedBy == [ vmUnit ];
assert unit.serviceConfig.IPAddressDeny == "any";
assert
  lib.sort lib.lessThan allowed == [
    "10.77.0.2/32"
    "127.0.0.0/8"
  ];
assert unit.serviceConfig ? MemoryMax;
{
  system = config.system.build.toplevel.drvPath;
  extraCommands = config.networking.firewall.extraCommands;
  mosquitto = unit.serviceConfig.ExecStart;
}

{ lib, ... }:
let
  tap = "vm-agent";
  guestAddr = "10.77.0.2";
  tapUnit = "microvm-tap-interfaces@agent.service";
  vmUnit = "microvm@agent.service";
  endpoint = import ./endpoint.nix;
  hashes = import ./hashes.nix;
  listenAddr = endpoint.host;
  port = toString endpoint.guestPort;
  inherit (endpoint.topics) speechRequest inbox;
in
{
  services.mosquitto = {
    enable = true;
    persistence = false;
    settings = {
      retain_available = false;
      sys_interval = 0;
      message_size_limit = 16384;
      max_packet_size = 20480;
      max_queued_messages = 16;
      max_queued_bytes = 65536;
      global_max_clients = 16;
      global_max_connections = 12;
    };
    listeners = [
      {
        address = listenAddr;
        port = endpoint.guestPort;
        settings = {
          listener_allow_anonymous = false;
          max_connections = 4;
          max_qos = 0;
          use_username_as_clientid = true;
        };
        users = {
          vm-speech = {
            hashedPassword = hashes.vm-speech;
            acl = [ "write ${speechRequest}" ];
          };
          vm-inbox = {
            hashedPassword = hashes.vm-inbox;
            acl = [ "read ${inbox}" ];
          };
        };
      }
      {
        address = "127.0.0.1";
        port = endpoint.hostPort;
        settings = {
          listener_allow_anonymous = false;
          use_username_as_clientid = true;
        };
        users = {
          host-speech = {
            hashedPassword = hashes.host-speech;
            acl = [ "read ${speechRequest}" ];
          };
          host-inbox = {
            hashedPassword = hashes.host-inbox;
            acl = [ "write ${inbox}" ];
          };
        };
      }
    ];
  };

  systemd.services.mosquitto = {
    bindsTo = [ tapUnit ];
    after = [ tapUnit ];
    before = [ vmUnit ];
    wantedBy = lib.mkForce [ vmUnit ];
    serviceConfig = {
      IPAddressAllow = [
        "${guestAddr}/32"
        "127.0.0.0/8"
      ];
      IPAddressDeny = "any";
      MemoryMax = "128M";
    };
  };

  networking.firewall.extraCommands = lib.mkAfter ''
    iptables -w -D INPUT -p tcp --dport ${port} -j agent-mqtt-guard 2>/dev/null || true
    iptables -w -N agent-mqtt-guard 2>/dev/null || true
    iptables -w -F agent-mqtt-guard
    iptables -w -A agent-mqtt-guard -i ${tap} -s ${guestAddr} -d ${listenAddr} -j ACCEPT
    iptables -w -A agent-mqtt-guard -j DROP
    iptables -w -I INPUT -p tcp --dport ${port} -j agent-mqtt-guard
  '';
  networking.firewall.extraStopCommands = ''
    iptables -w -D INPUT -p tcp --dport ${port} -j agent-mqtt-guard 2>/dev/null || true
    iptables -w -F agent-mqtt-guard 2>/dev/null || true
    iptables -w -X agent-mqtt-guard 2>/dev/null || true
  '';
}

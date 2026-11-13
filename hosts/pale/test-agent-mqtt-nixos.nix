let
  endpoint = import ../../modules/agent-mqtt/endpoint.nix;
  users = endpoint.credentials.guestUsers ++ endpoint.credentials.hostUsers;
  creds = "/var/lib/agent-mqtt-test";
  tapUnit = "microvm-tap-interfaces@agent";
  vmUnit = "microvm@agent";
in
{
  name = "agent-mqtt";

  nodes.pale =
    {
      lib,
      pkgs,
      ...
    }:
    let
      clients = pkgs.callPackage ../../modules/agent-mqtt/clients { };
      ip = lib.getExe' pkgs.iproute2 "ip";
      clientService = {
        unitConfig = clients.unit.unitConfig;
        serviceConfig = clients.unit.serviceConfig // {
          User = "pl";
        };
      };
    in
    {
      imports = [
        ../../modules/agent-vm-network.nix
        ../../modules/agent-mqtt/broker.nix
      ];

      services.agent-mqtt.hashedPasswordFiles = lib.genAttrs users (user: "${creds}/${user}.hash");

      users.users.pl.isNormalUser = true;

      environment.systemPackages = [
        pkgs.mosquitto
        pkgs.python3
        clients
      ];

      systemd.services.${tapUnit} = {
        path = [ pkgs.iproute2 ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "tap-up" ''
            set -eu
            ${ip} netns add guest
            ${ip} link add vm-agent type veth peer name eth0 netns guest
            ${ip} addr add 10.77.0.1/32 dev vm-agent
            ${ip} link set vm-agent up
            ${ip} route add 10.77.0.2/32 dev vm-agent
            ${ip} -n guest link set lo up
            ${ip} -n guest addr add 10.77.0.2/32 dev eth0
            ${ip} -n guest link set eth0 up
            ${ip} -n guest route add default via 10.77.0.1 dev eth0 onlink
          '';
          ExecStop = pkgs.writeShellScript "tap-down" ''
            ${ip} link del vm-agent || true
            ${ip} netns del guest || true
          '';
        };
      };

      systemd.services.${vmUnit} = {
        requires = [ "${tapUnit}.service" ];
        after = [ "${tapUnit}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/true";
        };
      };

      systemd.services.agent-mqtt-speech = lib.recursiveUpdate clientService {
        environment = {
          AGENT_MQTT_PASSWORD_FILE = "${creds}/host-speech.password";
          AGENT_MQTT_REJECT_LOG_INTERVAL = "0";
        };
        serviceConfig.ExecStart = lib.getExe clients.speechConsumer;
      };

      systemd.services.agent-mqtt-inbox-guest = lib.recursiveUpdate clientService {
        bindsTo = [ "${tapUnit}.service" ];
        after = [
          "${tapUnit}.service"
          "mosquitto.service"
        ];
        wantedBy = [ "${vmUnit}.service" ];
        environment = {
          AGENT_MQTT_AGENTS = "pi other";
          AGENT_MQTT_PASSWORD_FILE = "${creds}/vm-inbox.password";
          AGENT_MQTT_REJECT_LOG_INTERVAL = "0";
        };
        serviceConfig = {
          ExecStart = lib.getExe clients.inboxListener;
          NetworkNamespacePath = "/run/netns/guest";
        };
      };
    };

  testScript = ''
    import base64
    import json
    import shlex
    import time
    import uuid

    users = ${builtins.toJSON users}
    creds = "${creds}"
    G = "ip netns exec guest "
    passwords = {u: "test-" + u + "-" + uuid.uuid4().hex for u in users}


    def pw(user):
        return passwords[user]


    def mark(tag):
        return f"{tag}-{uuid.uuid4().hex[:12]}"


    def journal(unit):
        return pale.succeed(f"journalctl -u {unit} -o cat --no-pager")


    def records(unit):
        out = []
        for line in journal(unit).splitlines():
            if line.startswith("{"):
                out.append(json.loads(line))
        return out


    def accepted_texts(unit):
        return [r["text"] for r in records(unit) if r.get("event") == "accepted"]


    def has_text(unit, text):
        return f"journalctl -u {unit} -o cat --no-pager | grep -F {shlex.quote(json.dumps(text))}"


    def speak(text, agent="pi"):
        return (
            f"{G}env AGENT_MQTT_PASSWORD_FILE={creds}/vm-speech.password "
            f"agent-mqtt-speak {agent} {shlex.quote(text)}"
        )


    def inbox_send(text, agent="pi"):
        return (
            f"env AGENT_MQTT_PASSWORD_FILE={creds}/host-inbox.password "
            f"agent-mqtt-inbox-send {agent} {shlex.quote(text)}"
        )


    def guest_pub(user, topic, payload, extra=""):
        return (
            f"{G}mosquitto_pub -h 10.77.0.1 -p 18830 -u {user} -P {pw(user)} -q 0 "
            f"-t {shlex.quote(topic)} {extra} -m {shlex.quote(payload)}"
        )


    def put(path, data):
        if isinstance(data, str):
            data = data.encode("utf-8")
        pale.succeed(f"echo {base64.b64encode(data).decode()} | base64 -d > {path}")


    def guest_pub_file(user, topic, path, mode="-f"):
        return (
            f"{G}mosquitto_pub -h 10.77.0.1 -p 18830 -u {user} -P {pw(user)} -q 0 "
            f"-t {shlex.quote(topic)} {mode} {path}"
        )


    def speech_payload(text, v=1, agent="pi"):
        return json.dumps({"v": v, "agent": agent, "text": text}, ensure_ascii=False)


    def p1(tag):
        text = mark(tag)
        pale.wait_until_succeeds(f"{speak(text)}; {has_text('agent-mqtt-speech', text)}", timeout=120)
        return text


    def p2(tag):
        text = mark(tag)
        pale.wait_until_succeeds(
            f"{inbox_send(text)}; {has_text('agent-mqtt-inbox-guest', text)}", timeout=120
        )
        return text


    def speech_sentinel():
        time.sleep(3.5)
        text = mark("sentinel")
        pale.succeed(speak(text))
        pale.wait_until_succeeds(has_text("agent-mqtt-speech", text), timeout=30)


    def inbox_sentinel():
        text = mark("sentinel")
        pale.succeed(inbox_send(text))
        pale.wait_until_succeeds(has_text("agent-mqtt-inbox-guest", text), timeout=30)


    def refused(cmd):
        out = pale.execute(f"{cmd} -t '#' -C 1 -W 5 2>&1")[1]
        assert "not authori" in out.lower(), out


    def guard_drops():
        out = pale.succeed("iptables -w -L agent-mqtt-guard -v -n -x")
        for line in out.splitlines():
            fields = line.split()
            if len(fields) > 2 and fields[2] == "DROP":
                return int(fields[0])
        raise Exception(out)


    start_all()
    pale.wait_for_unit("multi-user.target")
    pale.wait_for_unit("firewall.service")

    with subtest("test credentials"):
        pale.succeed(f"install -d -m 0755 {creds}")
        for user in users:
            p = pw(user)
            pale.succeed(f"printf '%s\\n%s\\n' {p} {p} | mosquitto_passwd -c /tmp/{user}.pw {user}")
            pale.succeed(f"cut -d: -f2- /tmp/{user}.pw > {creds}/{user}.hash")
            pale.succeed(f"printf '%s\\n' {p} > {creds}/{user}.password")
            pale.succeed(f"chown pl {creds}/{user}.password && chmod 0400 {creds}/{user}.password")

    with subtest("missing password file fails clearly"):
        out = pale.fail("env AGENT_MQTT_PASSWORD_FILE=/nonexistent agent-mqtt-speak pi x 2>&1")
        assert "missing" in out, out

    with subtest("P5 client started before broker connects later"):
        pale.succeed("systemctl start agent-mqtt-speech.service")
        pale.wait_until_succeeds(
            "test $(systemctl show -p NRestarts --value agent-mqtt-speech.service) -ge 1", timeout=60
        )
        pale.fail("systemctl is-active mosquitto.service")
        pale.succeed("systemctl start ${vmUnit}.service")
        pale.wait_for_unit("mosquitto.service")
        pale.wait_for_unit("agent-mqtt-inbox-guest.service")
        pale.wait_for_open_port(18831, "127.0.0.1")
        p1("p5")

    with subtest("P1 guest speech request reaches host consumer"):
        speech_sentinel()

    with subtest("P2 host inbox message reaches guest listener"):
        p2("p2")

    with subtest("N2 anonymous refused on both listeners"):
        refused("mosquitto_sub -h 127.0.0.1 -p 18831")
        refused(f"{G}mosquitto_sub -h 10.77.0.1 -p 18830")

    with subtest("N3 guest publish to an inbox is not delivered"):
        n3 = [mark("n3"), mark("n3")]
        pale.succeed(guest_pub("vm-speech", "host/agent/pi/inbox", json.dumps({"v": 1, "text": n3[0]})))
        pale.succeed(guest_pub("vm-inbox", "host/agent/pi/inbox", json.dumps({"v": 1, "text": n3[1]})))
        pale.wait_for_unit("agent-mqtt-inbox-guest.service")
        p2("n3-after")
        log = journal("agent-mqtt-inbox-guest")
        assert all(m not in log for m in n3), log

    with subtest("N4 guest wildcard subscriptions receive nothing outside ACL"):
        pale.succeed("systemctl stop agent-mqtt-inbox-guest.service")
        for user in ["vm-inbox", "vm-speech"]:
            pale.succeed(
                f"{G}sh -c 'stdbuf -oL -eL mosquitto_sub -d -v -h 10.77.0.1 -p 18830 -u {user} -P {pw(user)} "
                f"-t \"#\" -t \"\\$SYS/#\" > /tmp/n4-{user}.out 2>&1 &'"
            )
            pale.wait_until_succeeds(f"grep -q SUBACK /tmp/n4-{user}.out", timeout=30)
        allowed = mark("n4-allowed")
        pale.succeed(inbox_send(allowed))
        pale.wait_until_succeeds(f"grep -F {allowed} /tmp/n4-vm-inbox.out", timeout=30)
        time.sleep(1)
        speech_only = pale.succeed("cat /tmp/n4-vm-speech.out")
        assert allowed not in speech_only and "received PUBLISH" not in speech_only, speech_only
        pale.succeed("pkill -f '[m]osquitto_sub -d -v' || true")
        pale.succeed(f"{G}sh -c 'stdbuf -oL -eL mosquitto_sub -d -v -h 10.77.0.1 -p 18830 -u vm-inbox -P {pw('vm-inbox')} -t \"#\" -t \"\\$SYS/#\" > /tmp/n4-b.out 2>&1 &'")
        pale.wait_until_succeeds("grep -q SUBACK /tmp/n4-b.out", timeout=30)
        speech_sentinel()
        allowed = mark("n4-allowed")
        pale.succeed(inbox_send(allowed))
        pale.wait_until_succeeds(f"grep -F {allowed} /tmp/n4-b.out", timeout=30)
        out = pale.succeed("cat /tmp/n4-b.out")
        assert "vm/speech/request" not in out, out
        topics = [l.split()[0] for l in out.splitlines() if l.startswith("host/") or l.startswith("vm/") or l.startswith("$")]
        assert topics and all(t.startswith("host/agent/") for t in topics), out
        pale.succeed("pkill -f '[m]osquitto_sub -d -v' || true")
        pale.succeed("systemctl start agent-mqtt-inbox-guest.service")
        p2("n4-after")

    with subtest("N5 host listener unreachable from guest, guest creds refused on it"):
        pale.fail(f"{G}timeout 5 bash -c '</dev/tcp/10.77.0.1/18831'")
        pale.fail(f"{G}timeout 5 bash -c '</dev/tcp/127.0.0.1/18831'")
        refused(f"mosquitto_sub -h 127.0.0.1 -p 18831 -u vm-inbox -P {pw('vm-inbox')}")
        refused(f"mosquitto_sub -h 127.0.0.1 -p 18831 -u vm-speech -P {pw('vm-speech')}")
        refused(f"{G}mosquitto_sub -h 10.77.0.1 -p 18830 -u host-speech -P {pw('host-speech')}")

    with subtest("loopback guard drops host clients to the guest listener"):
        before = guard_drops()
        pale.fail("timeout 5 bash -c '</dev/tcp/10.77.0.1/18830'")
        assert guard_drops() > before

    with subtest("N6 oversize payload is not delivered"):
        put("/tmp/n6.json", speech_payload("x" * 17000))
        pale.execute(guest_pub_file("vm-speech", "vm/speech/request", "/tmp/n6.json"))
        speech_sentinel()
        sizes = [r.get("line_bytes", 0) for r in records("agent-mqtt-speech")]
        assert max(sizes) < 2 * 16384, sizes

    with subtest("N7 retained publish is not delivered"):
        n7 = mark("n7")
        pale.execute(guest_pub("vm-speech", "vm/speech/request", speech_payload(n7), "-r"))
        speech_sentinel()
        assert n7 not in journal("agent-mqtt-speech")

    with subtest("N8 connections beyond max_connections are refused"):
        pale.succeed("systemctl stop agent-mqtt-inbox-guest.service")
        probe = (
            f"mosquitto_sub -d -h 10.77.0.1 -p 18830 -u vm-speech -P {pw('vm-speech')} "
            "-t vm/speech/request -W 3"
        )
        base = pale.execute(f"{G}{probe} 2>&1")[1]
        assert "CONNACK (0)" in base, base
        script = (
            "import socket, subprocess, sys\n"
            "socks = []\n"
            "for _ in range(4):\n"
            "    s = socket.create_connection(('10.77.0.1', 18830), timeout=5)\n"
            "    socks.append(s)\n"
            f"r = subprocess.run({probe!r}, shell=True, capture_output=True, text=True)\n"
            "print(r.stdout + r.stderr)\n"
        )
        pale.succeed(f"cat > /tmp/n8.py <<'EOF'\n{script}EOF")
        out = pale.succeed(f"{G}python3 /tmp/n8.py")
        assert "CONNACK (0)" not in out, out
        after = pale.execute(f"{G}{probe} 2>&1")[1]
        assert "CONNACK (0)" in after, after
        pale.succeed("systemctl start agent-mqtt-inbox-guest.service")

    with subtest("N9 bad speech requests are dropped and logged without payload"):
        raw = [mark("RAWn9") for _ in range(6)]
        bad = [
            "not json " + raw[0],
            speech_payload(raw[1] + "x" * 300),
            speech_payload(raw[2], v=2),
            speech_payload(raw[3] + "\u202e"),
            speech_payload(raw[4] + "\x07"),
            speech_payload(raw[5], agent="Bad Agent"),
        ]
        for i, payload in enumerate(bad):
            put(f"/tmp/n9-{i}.json", payload)
            pale.succeed(guest_pub_file("vm-speech", "vm/speech/request", f"/tmp/n9-{i}.json"))
        time.sleep(3.5)
        burst = [mark("burst") for _ in range(5)]
        lines = "\n".join(speech_payload(b) for b in burst) + "\n"
        put("/tmp/n9-burst", lines)
        pale.succeed(guest_pub_file("vm-speech", "vm/speech/request", "/tmp/n9-burst", "-l <"))
        speech_sentinel()
        log = journal("agent-mqtt-speech")
        for m in raw:
            assert m not in log and m.encode().hex() not in log, m
        reasons = [r["reason"] for r in records("agent-mqtt-speech") if r.get("event") == "rejected"]
        for reason in ["json", "text_length", "version", "text_chars", "agent"]:
            assert reason in reasons, (reason, reasons)
        assert reasons.count("text_chars") >= 2, reasons
        accepted = accepted_texts("agent-mqtt-speech")
        assert sum(b in accepted for b in burst) == 1, accepted
        assert reasons.count("rate_limited") >= 4, reasons

    with subtest("P3 broker restart, clients reconnect"):
        pale.succeed("systemctl restart mosquitto.service")
        pale.wait_for_unit("mosquitto.service")
        p1("p3")
        p2("p3")

    with subtest("P4 tap down and up, broker follows"):
        pale.succeed("systemctl stop ${vmUnit}.service")
        pale.succeed("systemctl is-active mosquitto.service")
        pale.succeed("systemctl stop ${tapUnit}.service")
        pale.wait_until_fails("systemctl is-active mosquitto.service", timeout=30)
        pale.fail("systemctl is-active agent-mqtt-inbox-guest.service")
        pale.succeed("systemctl start ${vmUnit}.service")
        pale.wait_for_unit("${tapUnit}.service")
        pale.wait_for_unit("mosquitto.service")
        pale.wait_for_unit("agent-mqtt-inbox-guest.service")
        p1("p4")
        p2("p4")

    print(pale.succeed("journalctl -u agent-mqtt-speech -o cat --no-pager | tail -40"))
    print(pale.succeed("journalctl -u agent-mqtt-inbox-guest -o cat --no-pager | tail -20"))
  '';
}

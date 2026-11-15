let
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  seed = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./test-agent-nats-throwaway.seed);
  pub = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./test-agent-nats-throwaway.pub);
  tapUnit = "microvm-tap-interfaces@agent";
  vmUnit = "microvm@agent";
in
{
  name = "agent-nats";

  nodes.pale =
    {
      lib,
      pkgs,
      ...
    }:
    let
      ip = lib.getExe' pkgs.iproute2 "ip";
    in
    {
      imports = [
        ../../modules/agent-vm-network.nix
        ../../modules/agent-nats/hub.nix
        ../../modules/agent-speech-guard.nix
        ../../vm/agent/agent-nats.nix
      ];

      services.agent-nats.leafPublicKey = pub;

      environment.systemPackages = [
        pkgs.nats-server
        pkgs.nkeys
        (pkgs.python3.withPackages (ps: [ ps.nats-py ]))
      ];

      environment.etc."speech-request-check.py".text = ''
        import asyncio
        import json
        import sys

        import nats

        sys.path.insert(0, "${../../home/programs/local-tts}")
        from speech_bridge import Bridge
        from speech_nats import Transport


        class DelayedTransport(Transport):
            async def message(self, msg):
                await asyncio.sleep(0.1)
                await super().message(msg)


        async def main():
            url = "nats://127.0.0.1:${toString endpoint.clientPort}"
            bridge = Bridge(lambda *args: None, [], 10)
            transport = DelayedTransport(bridge, url, 1000)
            transport.start()
            client = await nats.connect(url)
            try:
                for _ in range(100):
                    if transport.nc and transport.nc.is_connected:
                        break
                    await asyncio.sleep(0.05)
                else:
                    raise AssertionError("bridge did not connect")
                await asyncio.sleep(0.2)

                async def request(subject, body):
                    reply = await client.request(
                        subject, json.dumps(body).encode(), timeout=2
                    )
                    return json.loads(reply.data)

                assert (await request("speech.query.state", {}))["active"] is False
                body = dict(utt="control-test", seq=0, final=False,
                            text="hello", origin="test")
                assert await request("speech.intent.say", body) == {"accepted": True}
                assert (await request("speech.query.state", {}))["active"] is True
                for subject in ("speech.intent.stop", "speech.cmd.stop"):
                    assert await request(subject, {}) == {"accepted": True}
                    assert (await request("speech.query.state", {}))["active"] is False
                assert await request("speech.cmd.hold", {"id": "test", "ttl": 1}) == {"accepted": True}
                assert await request("speech.cmd.release", {"id": "test"}) == {"accepted": True}
                transport.close()
                try:
                    await request("speech.query.state", {})
                except (nats.errors.TimeoutError, nats.errors.NoRespondersError):
                    pass
                else:
                    raise AssertionError("CONTROL replied without the bridge")
            finally:
                transport.close()
                bridge.close()
                await client.close()


        asyncio.run(main())
      '';

      systemd.services.lan-netns = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "lan-up" ''
            set -eu
            ${ip} netns add lan
            ${ip} link add lan0 type veth peer name eth0 netns lan
            ${ip} addr add 192.168.99.1/24 dev lan0
            ${ip} link set lan0 up
            ${ip} -n lan link set lo up
            ${ip} -n lan addr add 192.168.99.2/24 dev eth0
            ${ip} -n lan link set eth0 up
            ${ip} -n lan route add default via 192.168.99.1 dev eth0
          '';
        };
      };

      systemd.services.${tapUnit} = {
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

      systemd.services.speech-http-test = {
        after = [ "${tapUnit}.service" ];
        requires = [ "${tapUnit}.service" ];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8881 --bind 10.77.0.1";
      };

      systemd.services.agent-nats-leaf = {
        wantedBy = lib.mkForce [ "${vmUnit}.service" ];
        bindsTo = [ "${tapUnit}.service" ];
        after = [
          "${tapUnit}.service"
          "nats.service"
        ];
        serviceConfig.NetworkNamespacePath = "/run/netns/guest";
      };
    };

  testScript = ''
    import shlex
    import time
    import uuid

    G = "ip netns exec guest "
    L = "ip netns exec lan "
    HUB = "nats -s nats://127.0.0.1:${toString endpoint.clientPort} "
    LEAF = G + "nats -s nats://127.0.0.1:${toString endpoint.clientPort} "
    SEED_FILE = "${endpoint.seed.file}"


    def mark(tag):
        return f"{tag}-{uuid.uuid4().hex[:12]}"


    def show(unit, prop):
        return pale.succeed(f"systemctl show -p {prop} --value {unit}").strip()


    def host_sub(name, subject):
        out = f"/tmp/sub-{name}.out"
        pale.succeed(
            f"systemd-run --unit=sub-{name} --setenv=PATH=$PATH --setenv=HOME=/root "
            f"sh -c {shlex.quote(HUB + 'sub --raw ' + shlex.quote(subject) + ' > ' + out + ' 2>&1')}"
        )
        pale.wait_until_succeeds(f"systemctl is-active sub-{name}.service", timeout=30)
        time.sleep(1)
        return out


    def leaf_delivers(out, tag, subject="agent.test"):
        text = mark(tag)
        pale.wait_until_succeeds(
            f"{LEAF}pub {subject} {text} && sleep 0.5 && grep -qF {text} {out}", timeout=120
        )
        return text


    def guard_drops():
        out = pale.succeed("iptables -w -L agent-nats-guard -v -n -x")
        for line in out.splitlines():
            fields = line.split()
            if len(fields) > 2 and fields[2] == "DROP":
                return int(fields[0])
        raise Exception(out)


    def guard_intact():
        rules = pale.succeed("iptables -w -S INPUT")
        jumps = [l for l in rules.splitlines() if l.split()[-2:] == ["-j", "agent-nats-guard"]]
        assert len(jumps) == 1, rules
        assert "agent-nats-guard-new" not in pale.succeed("iptables -w -S")
        chain = pale.succeed("iptables -w -S agent-nats-guard").splitlines()
        assert chain == [
            "-N agent-nats-guard",
            "-A agent-nats-guard -s 10.77.0.2/32 -d 10.77.0.1/32 -i vm-agent -j ACCEPT",
            "-A agent-nats-guard -j DROP",
        ], chain


    def unreachable(prefix, addr):
        before = guard_drops()
        pale.fail(f"{prefix}timeout 5 bash -c '</dev/tcp/{addr}/${toString endpoint.leafPort}'")
        assert guard_drops() > before, (prefix, addr)


    def rogue(name, port, remote):
        conf = (
            f"server_name: {name}\n"
            f"host: 127.0.0.1\nport: {port}\n"
            "leafnodes { reconnect: \"1s\", remotes: [ { " + remote + " } ] }\n"
        )
        pale.succeed(f"cat > /tmp/{name}.conf <<'EOF'\n{conf}EOF")
        pale.succeed(
            f"systemd-run --unit={name} --setenv=PATH=$PATH --property=NetworkNamespacePath=/run/netns/guest "
            f"--setenv=NATS_LEAF_SEED=$(nk -gen user) "
            f"nats-server -c /tmp/{name}.conf -l /tmp/{name}.log"
        )
        pale.wait_until_succeeds(f"grep -qi 'authorization violation' /tmp/{name}.log", timeout=60)
        text = mark(name)
        pale.succeed(f"{G}nats -s nats://127.0.0.1:{port} pub agent.test {text}")
        return text


    start_all()
    pale.wait_for_unit("multi-user.target")
    pale.wait_for_unit("firewall.service")
    pale.wait_for_unit("lan-netns.service")

    with subtest("hub runs with JetStream before the VM exists"):
        pale.wait_for_unit("nats.service")
        pale.wait_for_open_port(${toString endpoint.clientPort}, "127.0.0.1")
        pale.succeed("journalctl -u nats -o cat --no-pager | grep -q 'Starting JetStream'")
        pale.succeed("test -d /var/lib/nats/jetstream")
        pale.wait_until_succeeds("ss -Htln '( sport = :${toString endpoint.leafPort} )' | grep -q '0.0.0.0:${toString endpoint.leafPort}'", timeout=30)
        pale.fail("ss -H6tln | grep -q ':${toString endpoint.leafPort}'")
        pale.fail("ss -Htln '( sport = :${toString endpoint.clientPort} )' | grep -v 127.0.0.1")

    with subtest("leaf without a seed file fails clearly"):
        pale.succeed("rm -f " + SEED_FILE)
        pale.succeed("systemctl start ${vmUnit}.service")
        pale.wait_until_succeeds(
            "journalctl -u agent-nats-leaf -o cat --no-pager | grep -F 'task agent-nats-leaf-seed'", timeout=30
        )
        pale.fail("systemctl is-active agent-nats-leaf.service")

    with subtest("leaf with the right seed connects"):
        pale.succeed(f"install -d -m 0700 $(dirname {SEED_FILE})")
        pale.succeed(f"(umask 077; printf 'NATS_LEAF_SEED=%s\\n' ${seed} > {SEED_FILE})")
        pale.succeed("systemctl restart agent-nats-leaf.service")
        pale.wait_for_unit("agent-nats-leaf.service")
        pale.wait_until_succeeds(
            "journalctl -u agent-nats-leaf -o cat --no-pager | grep -q 'Leafnode connection created'", timeout=60
        )
        pale.wait_until_succeeds(
            "journalctl -u nats -o cat --no-pager | grep -q 'Leafnode connection created'", timeout=60
        )
        pale.fail("journalctl -u agent-nats-leaf -o cat --no-pager | grep -F ${seed}")

    with subtest("leaf publish on agent.> reaches a HOST subscriber"):
        agent_out = host_sub("agent", "agent.>")
        all_out = host_sub("all", ">")
        leaf_delivers(agent_out, "p1")

    with subtest("speech intents reach HOST but commands do not"):
        speech_out = host_sub("speech", "speech.>")
        leaf_delivers(speech_out, "say", "speech.intent.say")
        forbidden = mark("command")
        pale.succeed(f"{LEAF}pub speech.cmd.stop {forbidden}")
        leaf_delivers(speech_out, "barrier", "speech.intent.stop")
        assert forbidden not in pale.succeed(f"cat {speech_out}")

    with subtest("CONTROL is bounded observation in HOST only"):
        import json
        pale.wait_for_unit("nats-control-stream.service")
        info = json.loads(pale.succeed(f"{HUB}stream info CONTROL --json"))
        assert info["config"]["no_ack"] is True
        assert info["config"]["max_age"] == 604800000000000
        assert info["config"]["max_bytes"] == 67108864
        assert set(info["config"]["subjects"]) == {"speech.>", "dictation.>", "cube.>"}
        assert info["state"]["messages"] > 0
        pale.fail(f"{LEAF}--js-domain ${endpoint.jsDomain} stream info CONTROL")
        pale.succeed("python3 /etc/speech-request-check.py")

    with subtest("existing CONTROL is reconciled without losing observations"):
        legacy = dict(info["config"], no_ack=False)
        pale.succeed("cat > /tmp/legacy-control.json <<'EOF'\n" + json.dumps(legacy) + "\nEOF")
        pale.succeed(f"{HUB}stream edit CONTROL --config /tmp/legacy-control.json --force")
        ack = json.loads(pale.succeed(f"{HUB}req speech.query.state '{{}}' --raw --timeout 2s"))
        assert ack["stream"] == "CONTROL", ack
        before = json.loads(pale.succeed(f"{HUB}stream info CONTROL --json"))
        assert before["config"].get("no_ack", False) is False
        pale.succeed("systemctl restart nats-control-stream.service")
        after = json.loads(pale.succeed(f"{HUB}stream info CONTROL --json"))
        assert after["config"]["no_ack"] is True
        assert after["state"]["messages"] == before["state"]["messages"]
        assert after["state"]["first_seq"] == before["state"]["first_seq"]
        assert after["state"]["last_seq"] == before["state"]["last_seq"]
        assert after["config"] == info["config"]
        pale.succeed("python3 /etc/speech-request-check.py")
        observed = json.loads(pale.succeed(f"{HUB}stream info CONTROL --json"))
        assert observed["state"]["messages"] > after["state"]["messages"]
        pale.succeed("systemctl restart nats-control-stream.service")
        again = json.loads(pale.succeed(f"{HUB}stream info CONTROL --json"))
        assert again["config"] == observed["config"]
        assert again["state"]["last_seq"] == observed["state"]["last_seq"]

    with subtest("subjects outside exports do not reach HOST"):
        outside = mark("outside")
        pale.succeed(f"{LEAF}pub other.test {outside}")
        pale.succeed(f"{LEAF}pub agentx.test {outside}")
        sentinel = leaf_delivers(all_out, "sentinel")
        time.sleep(1)
        seen = pale.succeed(f"cat {agent_out} {all_out}")
        assert outside not in seen, seen
        assert sentinel in seen, seen

    with subtest("JetStream usable from the leaf in AGENT"):
        pale.succeed(
            f"{LEAF}--js-domain ${endpoint.jsDomain} stream add JSTEST --subjects 'agent.js.>' --storage file --defaults"
        )
        pale.succeed(f"{LEAF}pub agent.js.one hello")
        pale.wait_until_succeeds(f"{LEAF}--js-domain ${endpoint.jsDomain} stream info JSTEST --json | grep -q '\"messages\": 1'", timeout=30)
        pale.fail(f"{HUB}stream info JSTEST")

    with subtest("leaf with a wrong or no nkey is rejected"):
        wrong = rogue("rogue-wrong", 4223, 'url: "nats-leaf://10.77.0.1:${toString endpoint.leafPort}", nkey: $NATS_LEAF_SEED')
        none = rogue("rogue-none", 4224, 'url: "nats-leaf://10.77.0.1:${toString endpoint.leafPort}"')
        sentinel = leaf_delivers(agent_out, "rogue-sentinel")
        seen = pale.succeed(f"cat {agent_out} {all_out}")
        assert wrong not in seen and none not in seen, seen
        pale.succeed("systemctl stop rogue-wrong rogue-none")

    with subtest("guest cannot reach the hub client port"):
        pale.fail(f"{G}timeout 5 bash -c '</dev/tcp/10.77.0.1/${toString endpoint.clientPort}'")

    with subtest("speech HTTP reachable only from host-local and VM"):
        pale.succeed("systemctl start speech-http-test.service")
        pale.wait_for_open_port(8881, "10.77.0.1")
        for action in ["reload", "restart"]:
            pale.succeed(f"systemctl {action} firewall.service")
            pale.succeed("curl --noproxy '*' --max-time 3 -f http://10.77.0.1:8881/")
            pale.succeed(f"{G}curl --noproxy '*' --max-time 3 -f http://10.77.0.1:8881/")
            pale.fail(f"{L}curl --noproxy '*' --max-time 3 -f http://10.77.0.1:8881/")
            pale.fail("curl --noproxy '*' --interface 192.168.99.1 --max-time 3 -f http://10.77.0.1:8881/")

    with subtest("leafnode port unreachable from non-tap sources"):
        guard_intact()
        unreachable("", "10.77.0.1")
        unreachable("", "127.0.0.1")
        unreachable(L, "10.77.0.1")
        unreachable(L, "192.168.99.1")

    with subtest("guard survives firewall reload and restart"):
        for action in ["reload", "reload", "restart"]:
            pale.succeed(f"systemctl {action} firewall.service")
            pale.wait_for_unit("firewall.service")
            guard_intact()
            unreachable(L, "192.168.99.1")
        pale.succeed("systemctl is-active nats.service")
        leaf_delivers(agent_out, "fw")

    with subtest("leaf survives a hub restart"):
        leaf = show("agent-nats-leaf.service", "MainPID")
        pale.succeed("systemctl restart nats.service")
        pale.wait_for_unit("nats.service")
        pale.succeed("systemctl restart sub-agent.service")
        time.sleep(1)
        leaf_delivers(agent_out, "hub-restart")
        assert show("agent-nats-leaf.service", "MainPID") == leaf

    with subtest("hub stays up across tap down and up"):
        hub = show("nats.service", "MainPID")
        sub = show("sub-agent.service", "MainPID")
        assert hub != "0" and sub != "0", (hub, sub)
        pale.succeed("systemctl stop ${vmUnit}.service")
        pale.succeed("systemctl stop ${tapUnit}.service")
        pale.wait_until_fails("systemctl is-active agent-nats-leaf.service", timeout=30)
        time.sleep(2)
        pale.succeed("systemctl is-active nats.service")
        assert show("nats.service", "MainPID") == hub
        pale.succeed("systemctl start ${vmUnit}.service")
        pale.wait_for_unit("${tapUnit}.service")
        pale.wait_for_unit("agent-nats-leaf.service")
        guard_intact()
        leaf_delivers(agent_out, "tap")
        assert show("nats.service", "MainPID") == hub
        assert show("sub-agent.service", "MainPID") == sub

    print(pale.succeed("journalctl -u nats -o cat --no-pager | tail -40"))
    print(pale.succeed("journalctl -u agent-nats-leaf -o cat --no-pager | tail -20"))
  '';
}

{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  writeShellApplication,
  symlinkJoin,
  mosquitto,
  jq,
}:
let
  endpoint = import ../endpoint.nix;
  inherit (endpoint) topics credentials;

  validator = stdenvNoCC.mkDerivation {
    pname = "agent-mqtt-validate";
    version = "1";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./validate.py
        ./test_validate.py
      ];
    };
    nativeBuildInputs = [ makeWrapper ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      ${python3}/bin/python3 -m unittest -v
      runHook postCheck
    '';
    installPhase = ''
      runHook preInstall
      install -Dm0444 validate.py "$out/lib/agent-mqtt/validate.py"
      makeWrapper ${python3}/bin/python3 "$out/bin/agent-mqtt-validate" \
        --add-flags "-I $out/lib/agent-mqtt/validate.py"
      runHook postInstall
    '';
    meta.mainProgram = "agent-mqtt-validate";
  };

  connection =
    {
      host,
      port,
      user,
      passwordFile,
    }:
    ''
      host=''${AGENT_MQTT_HOST:-${host}}
      port=''${AGENT_MQTT_PORT:-${toString port}}
      user=''${AGENT_MQTT_USER:-${user}}
      password_file=''${AGENT_MQTT_PASSWORD_FILE:-${passwordFile}}
      if [ ! -r "$password_file" ] || [ ! -s "$password_file" ]; then
        echo "agent-mqtt: password file $password_file for $user is missing, empty or unreadable" >&2
        exit 78
      fi
      password=
      IFS= read -r password < "$password_file" || true
      mqtt_options() {
        printf -- '-u %s\n-P %s\n' "$user" "$password"
      }
    '';

  hostConnection = user: {
    host = "127.0.0.1";
    port = endpoint.hostPort;
    inherit user;
    passwordFile = credentials.hostPasswordFile user;
  };

  guestConnection = user: {
    inherit (endpoint) host;
    port = endpoint.guestPort;
    inherit user;
    passwordFile = credentials.guestPasswordFile user;
  };

  speechConsumer = writeShellApplication {
    name = "agent-mqtt-speech-consumer";
    runtimeInputs = [
      mosquitto
      validator
    ];
    text = ''
      ${connection (hostConnection "host-speech")}
      mosquitto_sub -o <(mqtt_options) -h "$host" -p "$port" -q 0 -k 30 \
        -t ${lib.escapeShellArg topics.speechRequest} -F '%x' \
        | agent-mqtt-validate speech \
          --accept-interval "''${AGENT_MQTT_ACCEPT_INTERVAL:-3}" \
          --reject-log-interval "''${AGENT_MQTT_REJECT_LOG_INTERVAL:-10}"
    '';
  };

  inboxListener = writeShellApplication {
    name = "agent-mqtt-inbox-listener";
    runtimeInputs = [
      mosquitto
      validator
    ];
    text = ''
      ${connection (guestConnection "vm-inbox")}
      agents=()
      for agent in ''${AGENT_MQTT_AGENTS:-}; do
        agents+=(--agent "$agent")
      done
      if [ ''${#agents[@]} -eq 0 ]; then
        echo "agent-mqtt: AGENT_MQTT_AGENTS is empty, every message will be rejected" >&2
      fi
      mosquitto_sub -o <(mqtt_options) -h "$host" -p "$port" -q 0 -k 30 \
        -t ${lib.escapeShellArg topics.inbox} -F '%x %t' \
        | agent-mqtt-validate inbox "''${agents[@]}" \
          --reject-log-interval "''${AGENT_MQTT_REJECT_LOG_INTERVAL:-10}"
    '';
  };

  usage = name: args: ''
    if [ "$#" -ne 2 ]; then
      echo "usage: ${name} ${args}" >&2
      exit 64
    fi
    agent=$1
    text=$2
    if ! [[ $agent =~ ^[a-z0-9-]{1,32}$ ]]; then
      echo "${name}: agent must match [a-z0-9-]{1,32}" >&2
      exit 64
    fi
  '';

  speak = writeShellApplication {
    name = "agent-mqtt-speak";
    runtimeInputs = [
      mosquitto
      jq
    ];
    text = ''
      ${usage "agent-mqtt-speak" "AGENT TEXT"}
      ${connection (guestConnection "vm-speech")}
      payload=$(jq -cn --arg agent "$agent" --arg text "$text" '{v: 1, agent: $agent, text: $text}')
      mosquitto_pub -o <(mqtt_options) -h "$host" -p "$port" -q 0 \
        -t ${lib.escapeShellArg topics.speechRequest} -m "$payload"
    '';
  };

  inboxSend = writeShellApplication {
    name = "agent-mqtt-inbox-send";
    runtimeInputs = [
      mosquitto
      jq
    ];
    text = ''
      ${usage "agent-mqtt-inbox-send" "AGENT TEXT"}
      ${connection (hostConnection "host-inbox")}
      payload=$(jq -cn --arg text "$text" '{v: 1, text: $text}')
      mosquitto_pub -o <(mqtt_options) -h "$host" -p "$port" -q 0 \
        -t "host/agent/$agent/inbox" -m "$payload"
    '';
  };
in
symlinkJoin {
  name = "agent-mqtt-clients";
  paths = [
    validator
    speechConsumer
    inboxListener
    speak
    inboxSend
  ];
  passthru = {
    inherit
      validator
      speechConsumer
      inboxListener
      speak
      inboxSend
      ;
    unit = {
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "always";
        RestartSec = 2;
        RestartSteps = 5;
        RestartMaxDelaySec = 30;
        RestartPreventExitStatus = 78;
      };
    };
  };
}

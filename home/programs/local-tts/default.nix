{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.local-tts;
  endpoint = import ./bridge-endpoint.nix;
  speech = pkgs.callPackage ./package.nix { inherit (cfg) backend volume target; };
  unified = cfg.bridge.enable && cfg.bridge.natsUrl != null;
  toggle = pkgs.writeShellScriptBin "clipboard-speech-toggle" (
    if unified then
      ''
        exec ${speech}/bin/clipboard-speech-nats --url ${lib.escapeShellArg cfg.bridge.natsUrl} --max-chars ${toString cfg.bridge.maxChars}
      ''
    else
      ''
        exec ${pkgs.python3}/bin/python3 ${./clipboard_toggle.py} ${pkgs.systemd}/bin/systemctl
      ''
  );
in
{
  options.programs.local-tts = {
    enable = lib.mkEnableOption "foreground local text-to-speech";
    voiceControl.enable = lib.mkEnableOption "experimental guarded NATS dictation controller (no recording observer yet)";
    cubeControl.enable = lib.mkEnableOption "live NATS cube controller, relay and mechanical host executor";
    backend = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "http"
      ];
      default = "cpu";
      description = "Default speech backend; failures never select another backend.";
    };
    volume = lib.mkOption {
      type = lib.types.numbers.positive;
      default = 1.0;
      description = "Playback gain passed to pw-play; values above 1 amplify and may clip.";
    };
    target = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "PipeWire sink node name speech prefers; falls back to the default sink when absent.";
    };
    bridge = {
      enable = lib.mkEnableOption "the speech bridge serving the agent VM";
      natsUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional live NATS transport; HTTP remains independent.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = endpoint.port;
        description = "Bridge TCP port; the host firewall guard reads the same shared value.";
      };
      voice = lib.mkOption {
        type = lib.types.str;
        default = "af_bella";
        description = "Kokoro voice used for every bridge request.";
      };
      speed = lib.mkOption {
        type = lib.types.numbers.positive;
        default = 1.0;
        description = "Kokoro speech speed used for every bridge request.";
      };
      leadingSilenceMs = lib.mkOption {
        type = lib.types.ints.between 0 2000;
        default = 0;
        description = "Silence before the first audio of an utterance, for sink startup; not repeated per chunk.";
      };
      maxChars = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1000;
        description = "Longest text accepted by one bridge request.";
      };
      maxQueue = lib.mkOption {
        type = lib.types.ints.positive;
        default = 64;
        description = "Most sentences waiting to be spoken; further requests get 503.";
      };
    };
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.cubeControl.enable {
      assertions = [
        {
          assertion =
            unified
            && (config.services.handy.enable or false)
            && !cfg.voiceControl.enable
            && !(config.services.cube-remote.enable or false);
          message = "cubeControl requires NATS speech and Handy, with legacy cube and guarded dictation control disabled";
        }
      ];
      home.packages = [ speech ];
      systemd.user.services =
        lib.genAttrs [ "agent-controller" "cube-relay" "cube-host-executor" ]
          (name: {
            Unit = {
              Description = "NATS controller runtime: ${name}";
              Conflicts = lib.optionals (name == "agent-controller") [ "cube-controller.service" ];
              After = [
                "graphical-session.target"
              ]
              ++ lib.optionals (name == "agent-controller") [ "cube-controller.service" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = lib.escapeShellArgs (
                (
                  if name == "agent-controller" then
                    [ "${speech}/bin/agent-controller" ]
                  else
                    [
                      "${speech}/bin/cube-control"
                      (if name == "cube-relay" then "relay" else "executor")
                    ]
                )
                ++ [
                  "--url"
                  (if cfg.bridge.natsUrl == null then "" else cfg.bridge.natsUrl)
                ]
                ++ lib.optionals (name == "cube-host-executor") [
                  "--handy"
                  (lib.getExe config.services.handy.package)
                  "--wpctl"
                  "${pkgs.wireplumber}/bin/wpctl"
                  "--notify-send"
                  "${pkgs.libnotify}/bin/notify-send"
                ]
                ++ lib.optionals (name == "cube-relay") [
                  "--mosquitto"
                  "${pkgs.mosquitto}/bin/mosquitto_sub"
                ]
              );
              Restart = "on-failure";
              RestartSec = 2;
            };
            Install.WantedBy = [ "graphical-session.target" ];
          });
    })
    (lib.mkIf cfg.voiceControl.enable {
      assertions = [
        {
          assertion = unified && (config.services.handy.enable or false);
          message = "voiceControl requires the NATS speech bridge and services.handy.enable";
        }
      ];
      home.packages = [ speech ];
      systemd.user.services = lib.genAttrs [ "voice-controller" "handy-adapter" ] (name: {
        Unit = {
          Description = "Guarded NATS voice coordination: ${name}";
          After = [
            "graphical-session.target"
            "speech-bridge.service"
            "handy.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.escapeShellArgs (
            [
              "${speech}/bin/voice-control"
              (if name == "voice-controller" then "controller" else "adapter")
              "--url"
              (if cfg.bridge.natsUrl == null then "" else cfg.bridge.natsUrl)
            ]
            ++ lib.optionals (name == "handy-adapter") [
              "--handy"
              (lib.getExe config.services.handy.package)
            ]
          );
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      });
    })
    (lib.mkIf cfg.bridge.enable {
      home.packages = [
        (pkgs.writeShellScriptBin "speech-emergency-stop" ''
          exec ${pkgs.curl}/bin/curl --noproxy '*' --max-time 2 --fail --silent --show-error \
            -X POST http://${endpoint.host}:${toString cfg.bridge.port}/stop
        '')
      ];
      systemd.user.services.speech-bridge = {
        Unit = {
          Description = "Speech bridge for the agent VM";
          After = [ "pipewire.service" ];
        };
        Service = {
          ExecStart = lib.escapeShellArgs (
            [
              "${speech}/bin/speech-bridge"
              "--host"
              endpoint.host
              "--port"
              (toString cfg.bridge.port)
              "--voice"
              cfg.bridge.voice
              "--speed"
              (toString cfg.bridge.speed)
              "--max-chars"
              (toString cfg.bridge.maxChars)
              "--max-queue"
              (toString cfg.bridge.maxQueue)
              "--leading-silence-ms"
              (toString cfg.bridge.leadingSilenceMs)
            ]
            ++ lib.optionals (cfg.bridge.natsUrl != null) [
              "--nats-url"
              cfg.bridge.natsUrl
            ]
          );
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
    (lib.mkIf cfg.enable {
      home.packages = [
        speech
        toggle
      ];
      systemd.user.services.clipboard-speech = lib.mkIf (!unified) {
        Unit = {
          Description = "Clipboard speech owned by the desktop toggle";
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "exec";
          ExecStart = "${speech}/bin/speak --clipboard";
          KillMode = "control-group";
          TimeoutStopSec = "2s";
          Restart = "no";
          SuccessExitStatus = [ 130 ];
        };
      };
    })
  ];
}

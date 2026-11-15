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

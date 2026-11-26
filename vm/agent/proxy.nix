{ pkgs, ... }:
let
  credentialHelper = pkgs.writeShellScript "git-credential-placeholder" ''
    [ "$1" = get ] || exit 0
    path=
    while IFS= read -r line && [ -n "$line" ]; do
      case "$line" in path=*) path="''${line#path=}" ;; esac
    done
    case "$path" in
      spabreaks/*) token=PLACEHOLDER-gh-spabreaks ;;
      *) token=PLACEHOLDER-github ;;
    esac
    printf 'username=x-access-token\npassword=%s\n' "$token"
  '';
in
{
  security.pki.certificateFiles = [ ./proxy-ca.crt ];

  environment.variables = import ./proxy-env.nix // {
    GH_TOKEN = "PLACEHOLDER-github";
    TYPESAFE_API_KEY = "PLACEHOLDER-typesafe";
    ZAI_API_KEY = "PLACEHOLDER-zai";
    GEMINI_API_KEY = "PLACEHOLDER-gemini";
    GOOGLE_GENERATIVE_AI_API_KEY = "PLACEHOLDER-gemini";
    SB_AIRBRAKE_AUTH_TOKEN = "PLACEHOLDER-airbrake";
    GDA_TOKEN = "PLACEHOLDER-gcp";
    GDA_CHAT_TOKEN = "PLACEHOLDER-gda-chat";
    GA_TOKEN = "PLACEHOLDER-ga";
    CUE_DELEGATE_BACKEND = "supervisor";
    CUE_NATS_URL = "nats://127.0.0.1:4222";
    CUE_NATS_JS_DOMAIN = "pale";
    NINEROUTER_URL = "http://127.0.0.1:20128";
    NINEROUTER_PASSWORD = "123456";
  };

  programs.git = {
    enable = true;
    config = {
      url."https://github.com/".insteadOf = [
        "git@github.com:"
        "ssh://git@github.com/"
      ];
      credential."https://github.com" = {
        helper = "${credentialHelper}";
        useHttpPath = true;
      };
    };
  };
}

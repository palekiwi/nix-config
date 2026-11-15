{ config, lib, ... }:
let
  endpoint = import ../../modules/agent-nats/endpoint.nix;
  proxyVariables = [
    "http_proxy"
    "https_proxy"
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "no_proxy"
    "NO_PROXY"
    "NODE_EXTRA_CA_CERTS"
  ];
in
{
  imports = [ ../../modules/github-service.nix ];

  services.github-service = {
    enable = true;
    repositories = [ "spabreaks/spabreaks" ];
    pollInterval = 120;
    natsUrl = "nats://127.0.0.1:${toString endpoint.clientPort}";
    environment = lib.getAttrs proxyVariables config.environment.variables // {
      GH_TOKEN = "PLACEHOLDER-gh-spabreaks";
      GH_PROMPT_DISABLED = "1";
      SSL_CERT_FILE = config.security.pki.caBundle;
      NIX_SSL_CERT_FILE = config.security.pki.caBundle;
    };
  };
}

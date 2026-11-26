{ config, lib, ... }:
{
  environment.variables = {
    CUE_DELEGATE_BACKEND = "supervisor";
    CUE_NATS_URL = "nats://127.0.0.1:4222";
    CUE_NATS_JS_DOMAIN = "pale";
    NINEROUTER_URL = "http://127.0.0.1:20128";
    NINEROUTER_PASSWORD = "123456";
  };

  environment.etc."agent-vm/environment".text =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "${name}=${value}") (
        config.environment.variables
        // {
          NIX_PATH = lib.concatStringsSep ":" config.nix.nixPath;
          NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        }
      )
    )
    + "\n";
}

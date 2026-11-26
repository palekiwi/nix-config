{ config, lib, ... }:
{
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

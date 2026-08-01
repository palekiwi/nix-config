{ ... }:
{
  services.acuity = {
    enable = true;
    port = 33222;
    gotifyUrl = "http://haze:8780";
    environmentFile = "/run/secrets/acuity/env";
  };

  sops.secrets."acuity/env" = { owner = "acuity"; };
}

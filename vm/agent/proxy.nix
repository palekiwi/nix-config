let
  proxy = "http://10.77.0.1:3128";
  noProxy = "localhost,127.0.0.1,::1,10.77.0.0/24";
in
{
  security.pki.certificateFiles = [ ./proxy-ca.crt ];

  environment.variables = {
    http_proxy = proxy;
    https_proxy = proxy;
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    no_proxy = noProxy;
    NO_PROXY = noProxy;
    NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
    GH_TOKEN = "PLACEHOLDER-github";
    TYPESAFE_API_KEY = "PLACEHOLDER-typesafe";
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "Pawel Lisewski";
        email = "dev@palekiwi.com";
      };
      init.defaultBranch = "master";
      pull.rebase = true;
      url."https://github.com/".insteadOf = [
        "git@github.com:"
        "ssh://git@github.com/"
      ];
      credential."https://github.com".helper = "!gh auth git-credential";
    };
  };
}

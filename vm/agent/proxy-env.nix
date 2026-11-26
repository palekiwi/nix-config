let
  proxy = "http://10.77.0.1:3128";
  noProxy = "localhost,127.0.0.1,::1,10.77.0.0/24";
in
{
  http_proxy = proxy;
  https_proxy = proxy;
  HTTP_PROXY = proxy;
  HTTPS_PROXY = proxy;
  no_proxy = noProxy;
  NO_PROXY = noProxy;
  NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";
}

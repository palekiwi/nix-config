{ ... }:
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers."9router" = {
      image = "docker.io/decolua/9router:0.5.119@sha256:38e58865ff111599f409f44430084ad0016c2ba530757ef545848d4bbe0cf007";
      autoStart = true;
      pull = "missing";
      ports = [ "127.0.0.1:20128:20128" ];
      environment = {
        PORT = "20128";
        DATA_DIR = "/app/data";
      };
      volumes = [ "9router-data:/app/data" ];
      extraOptions = [ "--network=agent-llm" ];
    };
  };
}

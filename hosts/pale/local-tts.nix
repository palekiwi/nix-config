{ ... }:
{
  systemd.services.docker-kokoro = {
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers.kokoro = {
      image = "ghcr.io/remsky/kokoro-fastapi-gpu@sha256:797cb80c83b3c17bd03845a09cf131430a3fb95ca06cb55c2fbd12b54abce065";
      autoStart = true;
      pull = "never";
      ports = [ "127.0.0.1:8880:8880" ];
      environment = {
        NVIDIA_VISIBLE_DEVICES = "void";
        USE_GPU = "true";
        DEVICE_TYPE = "cuda";
        DEFAULT_VOICE = "af_bella";
        DOWNLOAD_MODEL = "false";
        ENABLE_WEB_PLAYER = "false";
        CORS_ENABLED = "false";
        API_LOG_LEVEL = "INFO";
      };
      extraOptions = [
        "--platform=linux/amd64"
        "--device=nvidia.com/gpu=all"
      ];
    };
  };
}

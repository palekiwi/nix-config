{ flake }:
let
  config = flake.nixosConfigurations.pale.config;
  container = config.virtualisation.oci-containers.containers.kokoro;
  unit = config.systemd.services.docker-kokoro;
  lib = flake.inputs.nixpkgs.lib;
in
assert builtins.all (assertion: assertion.assertion) config.assertions;
assert config.hardware.nvidia-container-toolkit.enable;
assert config.virtualisation.docker.daemon.settings.features.cdi;
assert !config.virtualisation.docker.enableNvidia;
assert config.virtualisation.oci-containers.backend == "docker";
assert
  container.image
  == "ghcr.io/remsky/kokoro-fastapi-gpu@sha256:797cb80c83b3c17bd03845a09cf131430a3fb95ca06cb55c2fbd12b54abce065";
assert container.pull == "never";
assert container.autoStart;
assert container.ports == [ "127.0.0.1:8880:8880" ];
assert
  container.extraOptions == [
    "--platform=linux/amd64"
    "--device=nvidia.com/gpu=all"
  ];
assert
  container.environment == {
    NVIDIA_VISIBLE_DEVICES = "void";
    USE_GPU = "true";
    DEVICE_TYPE = "cuda";
    DEFAULT_VOICE = "af_bella";
    DOWNLOAD_MODEL = "false";
    ENABLE_WEB_PLAYER = "false";
    CORS_ENABLED = "false";
    API_LOG_LEVEL = "INFO";
  };
assert !container.privileged;
assert container.volumes == [ ];
assert container.imageFile == null && container.imageStream == null;
assert builtins.elem "multi-user.target" unit.wantedBy;
assert builtins.elem "docker.service" unit.after;
assert builtins.elem "nvidia-container-toolkit-cdi-generator.service" unit.requires;
assert builtins.elem "nvidia-container-toolkit-cdi-generator.service" unit.after;
assert unit.serviceConfig.Restart == "on-failure";
assert lib.hasInfix "--pull never" unit.script;
assert lib.hasInfix "--device=nvidia.com/gpu=all" unit.script;
{
  system = config.system.build.toplevel.drvPath;
  inherit (container)
    serviceName
    image
    pull
    ports
    ;
  inherit (unit) script;
}

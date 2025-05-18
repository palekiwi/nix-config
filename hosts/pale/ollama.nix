{ ... }:
{
  services.ollama = {
    enable = false;
    acceleration = "cuda";
    loadModels = [ "deepseek-r1:7b" ];
  };
}

{ ... }:
{
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    loadModels = [ "deepseek-r1:7b" ];
  };
}

{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  environment.variables = {
    DISABLE_AUTOUPDATER = "1";
  };
}

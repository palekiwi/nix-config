{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];

  home.sessionVariables.DISABLE_AUTOUPDATER = "1";
}

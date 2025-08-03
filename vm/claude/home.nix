{ ... }:

{
  xdg.configFile = {
    "Claude/claude_desktop_config.json".source = ./claude_desktop_config.json;
  };

  home.sessionVariables = {
    NEO4J_USER = "neo4j";
    NEO4J_PASSWORD = "$PATH:$HOME/bin";
  };

  home.stateVersion = "25.05";
}

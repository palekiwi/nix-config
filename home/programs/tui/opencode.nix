{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    cast-mcp-client
    cue
    cue-legacy
  ];
}

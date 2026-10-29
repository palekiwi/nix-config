{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    cast-mcp-client
    cast-tui
    cue
  ];
}

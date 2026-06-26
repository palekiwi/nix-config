{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    cast-mcp-client
    cue
    curator
    mcp-rspec
    ocx
  ];
}

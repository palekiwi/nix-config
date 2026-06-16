{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    cast-mcp-client
    cue
    mcp-rspec
    ocx
    test-runner-mcp
  ];
}

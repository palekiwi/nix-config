{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    cast-mcp-client
    mcp-rspec
    mem
    ocx
    test-runner-mcp
  ];
}

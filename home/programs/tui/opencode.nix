{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cast
    mcp-rspec
    mem
    ocx
    test-runner-mcp
  ];
}

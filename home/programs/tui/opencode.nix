{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mcp-rspec
    mem
    ocx
    test-runner-mcp
  ];
}

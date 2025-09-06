{ pkgs, ... }:

{
  home.packages = with pkgs; [ opencode test-runner-mcp];
}

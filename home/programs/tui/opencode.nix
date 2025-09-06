{ pkgs, ... }:

{
  home.packages = with pkgs; [
    opencode
    opencode-rust
    test-runner-mcp
  ];
}

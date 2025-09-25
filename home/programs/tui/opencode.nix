{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
    opencode
    opencode-rust
    test-runner-mcp
    mcp-gemini-cli
  ];
}

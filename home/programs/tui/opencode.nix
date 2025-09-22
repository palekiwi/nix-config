{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
    opencode
    opencode-rust
    opencode-rust-enhanced
    test-runner-mcp
  ];
}

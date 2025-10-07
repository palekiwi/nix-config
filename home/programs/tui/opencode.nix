{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini
    opencode
    opencode-ruby
    opencode-rust
    test-runner-mcp
    mcp-gemini-cli
  ];
}

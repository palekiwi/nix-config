{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
    opencode
    opencode-ruby
    opencode-rust
    test-runner-mcp
    mcp-gemini-cli
  ];
}

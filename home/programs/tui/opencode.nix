{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini
    mcp-rspec
    opencode
    opencode-ruby
    opencode-rust
    test-runner-mcp
  ];
}

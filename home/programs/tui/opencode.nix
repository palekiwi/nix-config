{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini
    mcp-rspec
    ocx
    opencode
    opencode-ruby
    opencode-rust
    test-runner-mcp
  ];
}

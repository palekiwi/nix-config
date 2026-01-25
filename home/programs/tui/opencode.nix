{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini
    mcp-rspec
    mem
    ocx
    opencode
    opencode-ruby
    opencode-rust
    test-runner-mcp
  ];
}

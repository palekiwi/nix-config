{ pkgs, ... }:

{
  home.packages = with pkgs; [
    opencode
    opencode-rust
    opencode-rust-enhanced
    test-runner-mcp
  ];
}

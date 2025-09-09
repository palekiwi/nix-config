{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ansible
    ansible-lint
    gnumake
    go
    lua
    lua-language-server
    nixd
    nixpkgs-fmt
    nodePackages.prettier
    nodePackages.typescript-language-server
    nodejs_24
    python3
    rustup
    tree-sitter
    universal-ctags
    vscode-langservers-extracted
  ];
}

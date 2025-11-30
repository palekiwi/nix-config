{ pkgs, ... }:

{
  home.packages = with pkgs; [
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

  home.file.".npmrc".text = ''
    prefix=~/.npm-global
  '';
}

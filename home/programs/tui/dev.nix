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
    nodejs_22
    python3
    rustup
    universal-ctags
    vscode-langservers-extracted
  ];
}

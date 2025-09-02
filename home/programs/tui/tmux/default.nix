{ pkgs, ... }:

[
  (import ./git-repo.nix { inherit pkgs; })
]

{ pkgs, ... }:

[
  (import ./git-repo.nix { inherit pkgs; })
  (import ./ygt-spabreaks-dev.nix { inherit pkgs; })
  (import ./ygt-vrs-dev.nix { inherit pkgs; })
]

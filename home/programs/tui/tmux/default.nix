{ pkgs, ... }:

[
  (import ./git-repo.nix { inherit pkgs; })
  (import ./ygt-spabreaks-dev.nix { inherit pkgs; })
  (import ./ygt-vrs-dev.nix { inherit pkgs; })
  (import ./ygt-blog-dev.nix { inherit pkgs; })
  (import ./ygt-my-account-dev.nix { inherit pkgs; })
  (import ./ygt-sales-dev.nix { inherit pkgs; })
  (import ./ygt-wss-data-dev.nix { inherit pkgs; })
]

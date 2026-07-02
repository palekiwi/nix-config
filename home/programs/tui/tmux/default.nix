{ pkgs, ... }:

[
  (import ./git-repo.nix { inherit pkgs; })
  (import ./spabreaks-spabreaks-dev.nix { inherit pkgs; })
  (import ./spabreaks-vrs-dev.nix { inherit pkgs; })
  (import ./spabreaks-blog-dev.nix { inherit pkgs; })
  (import ./spabreaks-contacts-dev.nix { inherit pkgs; })
  (import ./spabreaks-booking-transform-dev.nix { inherit pkgs; })
  (import ./spabreaks-my-account-dev.nix { inherit pkgs; })
  (import ./spabreaks-wss-dev.nix { inherit pkgs; })
  (import ./spabreaks-wss-data-dev.nix { inherit pkgs; })
]

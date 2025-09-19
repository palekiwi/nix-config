{ pkgs, ... }:

[
  (import ./ygt_spabreaks_sync.nix { inherit pkgs; })
]

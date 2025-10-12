{ pkgs, ... }:

[
  (import ./fetch_gh_docs.nix { inherit pkgs; })
]

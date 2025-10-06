{ pkgs, ... }:

[
  (import ./ygt_spabreaks_sync.nix { inherit pkgs; })
  (import ./ygt_fetch_jira_ticket.nix { inherit pkgs; })
]

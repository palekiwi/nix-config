{ pkgs, ... }:

[
  (import ./ygt_spabreaks_sync.nix { inherit pkgs; })
  (import ./ygt_fetch_jira_ticket.nix { inherit pkgs; })
  (import ./ygt_jira_ticket_from_branch.nix { inherit pkgs; })
]

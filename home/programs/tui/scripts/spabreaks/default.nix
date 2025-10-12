{ pkgs, ... }:

[
  (import ./spabreaks_fetch_jira_ticket.nix { inherit pkgs; })
  (import ./spabreaks_jira_ticket_from_branch.nix { inherit pkgs; })
  (import ./spabreaks_save_jira_ticket.nix { inherit pkgs; })
  (import ./spabreaks_sync.nix { inherit pkgs; })
]

{ pkgs, ... }:

pkgs.writers.writeNuBin "spabreaks_fetch_jira_ticket" (builtins.readFile ./sb_fetch_jira_ticket.nu)

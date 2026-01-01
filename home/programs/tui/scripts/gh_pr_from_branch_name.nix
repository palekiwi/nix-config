{ pkgs, ... }:

let
  set_pr_info = import ./set_pr_info.nix { inherit pkgs; };
in
pkgs.writers.writeNuBin "gh_pr_from_branch_name" ''
  def main [--body: string = "", --draft, --base: string] {
    let branch_name = (git branch --show-current | str trim)

    if $branch_name == "main" or $branch_name == "master" {
      print "Cannot create PR from main/master branch"
      exit 1
    }

    let title = ($branch_name
      | str replace --regex "[-_]" " " --all
      | str capitalize)

    mut args = ["--title" $title "--body" $body]
    if $draft { $args = ($args | append "--draft") }
    if not ($base | is-empty) { $args = ($args | append ["--base" $base]) }

    print $"Creating PR with title: ($title)"
    gh pr create ...$args

    ${set_pr_info}/bin/set_pr_info
  }
''

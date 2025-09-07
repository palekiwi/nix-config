{ pkgs, ... }:

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

    let draft_flag = if $draft { " --draft" } else { "" }
    let base_flag = if ($base | is-empty) { "" } else { $" --base ($base)" }

    print $"Creating PR with title: ($title)"
    gh pr create --title $title --body $body $draft_flag $base_flag
  }
''

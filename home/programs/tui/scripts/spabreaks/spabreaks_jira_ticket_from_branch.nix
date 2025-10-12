{ pkgs, ... }:

pkgs.writers.writeNuBin "spabreaks_jira_ticket_from_branch" ''
  def main [] {
    let branch = (git branch --show-current)

    def print_ticket [ticket] {
      print $"SB-($ticket)"
    }

    # Try pattern: SB-<number>-... (case insensitive)
    let sb_match = ($branch | parse --regex '(?i)sb-(?P<ticket>\d+)')

    if ($sb_match | length) > 0 {
      print_ticket ($sb_match | get 0.ticket)
      return
    }

    # Try pattern: <number>-...
    let num_match = ($branch | parse --regex '^(?P<ticket>\d+)-')

    if ($num_match | length) > 0 {
      print_ticket ($num_match | get 0.ticket)
      return
    }

    error make {msg: "No ticket number found in branch name"}
  }
''

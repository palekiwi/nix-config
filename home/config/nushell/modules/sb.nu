export def ticket [--org = "spabreaks", --id = "SB", --open] {
    let number = git rev-parse --abbrev-ref HEAD
        | str trim
        | parse --regex '(?<number>\d{4,5})'
        | get number.0

    let url = $"https://($org).atlassian.net/browse/($id)-($number)"

    print $"Ticket URL: ($url)"

    if $open { xdg-open $url }
}

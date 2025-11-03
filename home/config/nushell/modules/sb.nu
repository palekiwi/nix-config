export def jira-card-url [--org = "spabreaks", --id = "SB"] {
    let number = git rev-parse --abbrev-ref HEAD
        | str trim
        | parse --regex '(?<number>\d{4,5})'
        | get number.0

    $"https://($org).atlassian.net/browse/($id)-($number)"
}

export def ticket [] {
    xdg-open (jira-card-url)
}

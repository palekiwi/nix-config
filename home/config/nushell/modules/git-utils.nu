export def "last-branch-name" [] {
    git rev-parse --abbrev-ref @{-1}
}

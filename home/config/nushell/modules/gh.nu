export def "pr body" [--save] {
    let response = (do { gh pr view --json body } | complete)
    if $response.exit_code != 0 {
        error make { msg: $response.stderr }
    }

    let content = $response.stdout | from json | get body

    if $save {
        let dir = $".agents/(git branch --show-current)"
        let filename = "pr-body.md"
        let dest = $"($dir)/($filename)"

        mkdir $dir
        $content | save -f $dest

        $dest
    } else {
        $content
    }
}

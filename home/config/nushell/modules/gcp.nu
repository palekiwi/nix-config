export def main [] {
    "TODO"
}

export def "buckets ls" [--fields: string] {
    let fields = $fields | default "name,creation_time"
    gcloud storage buckets list --format="csv(name,storage_url,creation_time)"
    | from csv
    | into datetime creation_time
}

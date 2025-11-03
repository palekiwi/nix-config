export def main [] {
    "TODO"
}

export def "buckets ls" [] {
    gcloud storage buckets list --format="csv(name,storage_url,creation_time)"
    | from csv
    | into datetime creation_time
}

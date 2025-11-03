export def main [] {
    "TODO"
}

export def "buckets ls" [] {
    gcloud storage buckets list --format="csv(name,storage_url,creation_time)"
    | from csv
    | into datetime creation_time
}

export def builds [--limit:int = 50] {
    gcloud builds list --format=json --limit=$"($limit)"
    | from json
    | select substitutions.REPO_NAME? substitutions.SHORT_SHA? status finishTime?
    | update finishTime { |row| try { $row.finishTime | into datetime } catch { null } }
    | rename repo commit status finished
}

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

# TODO: This is just an example
export def "logs spabreaks" [--limit:int = 50] {
    let query = [
        'resource.type="k8s_container"'
        'resource.labels.project_id="production-servers"'
        'resource.labels.location="europe-west1"'
        'resource.labels.cluster_name="spabreaks-cluster"'
        'resource.labels.namespace_name="spabreaks"'
        'labels."k8s-pod/app"="spabreaks"'
    ] | str join " AND "

    gcloud logging read --format=json --limit=$"($limit)" $query
    | from json
}

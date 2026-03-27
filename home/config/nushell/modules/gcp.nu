const DEFAULT_REGION = "europe-west2"
const DEFAULT_PROJECT = "spabreaks-production"

export def main [] {
    "TODO"
}

export def "buckets ls" [] {
    gcloud storage buckets list --format="csv(name,storage_url,creation_time)"
    | from csv
    | into datetime creation_time
}

export def "builds list" [
    --limit(-l):int = 50
    --project(-p)=$DEFAULT_PROJECT
    --region=$DEFAULT_REGION
] {
    (gcloud builds list
        --format=json
        --limit=$"($limit)"
        --project=$"($project)"
        --region=$"($region)"
    )
    | from json
    | select id substitutions.REPO_NAME? substitutions.COMMIT_SHA? status finishTime?
    | update finishTime { |row| try { $row.finishTime | into datetime } catch { null } }
    | rename id repo commit status finished
    | update commit { |row| $row.commit | str substring 0..7 }
}

export def "builds cancel" [
    id: string
    --project(-p)=$DEFAULT_PROJECT
    --region=$DEFAULT_REGION
] {
    gcloud builds cancel $id --project $project --region $region
}

export def "config get-value" [value: string] {
    gcloud config get-value $value
}

export def "projects list" [--full] {
    let fields = [name projectId projectNumber]

    gcloud projects list --format=json | from json | if $full { $in } else { select  ...$fields }
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

export alias b = builds

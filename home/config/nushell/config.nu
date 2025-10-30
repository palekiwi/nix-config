source aliases/main.nu

$env.config.hooks.env_change.PWD = [{ ||
    if (which direnv | is-empty) { return }
    direnv export json | from json | default {} | load-env
    $env.PATH = $env.PATH | split row (char env_sep)
}]

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

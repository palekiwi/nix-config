source aliases/main.nu
source aliases/git.nu

source atuin.nu

$env.config.keybindings ++= [
  {
    name: insert_last_token
    modifier: alt
    keycode: char_.
    mode: [emacs vi_normal vi_insert]
    event: [
      { edit: InsertString, value: " !$" }
      { send: Enter }
    ]
  }
]

$env.config.hooks.env_change.PWD = [{ ||
    if (which direnv | is-empty) { return }
    direnv export json | from json | default {} | load-env
    $env.PATH = $env.PATH | split row (char env_sep)
}]

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

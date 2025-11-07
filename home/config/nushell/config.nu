source aliases/gh.nu
source aliases/git.nu
source aliases/main.nu

source integrations/atuin.nu

use modules/gcp.nu
use modules/sb.nu

$env.EDITOR = "nvim"
$env.GPG_TTY = ^tty

$env.config.buffer_editor = "nvim"
$env.config.edit_mode = 'vi'
$env.config.show_banner = false
$env.config.table.mode = "default"

$env.config.cursor_shape = {
    vi_insert: line
    vi_normal: block
    emacs: underscore
}

$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""

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

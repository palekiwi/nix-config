source aliases/gh.nu
source aliases/git.nu
source aliases/main.nu

source integrations/atuin.nu

use modules/gcp.nu
use modules/gh-utils.nu
use modules/sb.nu

$env.EDITOR = "nvim"
$env.GPG_TTY = ^tty

$env.CONTEXT7_API_KEY = (cat /run/secrets/context7/api_key)
$env.OPENCODE_API_KEY = (cat /run/secrets/opencode/api_key)
$env.ZAI_CODING_PLAN_API_KEY = (cat /run/secrets/zai_coding_plan/api_key)

$env.OPENCODE_ENABLE_EXPERIMENTAL_MODELS = false

$env.CACHIX_AUTH_TOKEN = (cat /run/secrets/cachix/personal/token)

if ($env.SSH_CONNECTION? == null) or ((hostname) == "kyomu") {
    $env.SSH_AUTH_SOCK = (gpgconf --list-dirs agent-ssh-socket | str trim)
}

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

let carapace_completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}

$env.config.completions = {
    case_sensitive: false # case-sensitive completions
    quick: true    # set to false to prevent auto-selecting completions
    partial: true    # set to false to prevent partial filling of the prompt
    algorithm: "fuzzy"    # prefix or fuzzy
    external: {
        # set to false to prevent nushell looking into $env.PATH to find more suggestions
        enable: true
        # set to lower can improve completion performance at the cost of omitting some options
        max_results: 100
        completer: $carapace_completer # check 'carapace_completer'
    }
}

# $env.config.hooks.env_change.PWD = [{ ||
$env.config.hooks.pre_prompt = [{ ||
    if (which direnv | is-empty) { return }
    direnv export json | from json | default {} | load-env
    $env.PATH = $env.PATH | split row (char env_sep)
}]

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

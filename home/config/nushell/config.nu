source common.nu
source aliases/tn.nu

$env.GPG_TTY = ^tty
$env.BROWSER = "firefox"

$env.CONTEXT7_API_KEY = (cat /run/secrets/context7/api_key)
$env.TYPESAFE_API_KEY = (cat /run/secrets/typesafe/api_key)
$env.GEMINI_API_KEY = (cat /run/secrets/spabreaks/gemini_api_key)
$env.GOOGLE_GENERATIVE_AI_API_KEY = (cat /run/secrets/spabreaks/google_generative_ai_api_key)
$env.OPENCODE_API_KEY = (cat /run/secrets/opencode/api_key)
$env.ZAI_CODING_PLAN_API_KEY = (cat /run/secrets/zai_coding_plan/api_key)
$env.GH_TOKEN_READONLY = (cat /run/secrets/github/palekiwi/gh_cli_readonly)

$env.OPENCODE_ENABLE_EXPERIMENTAL_MODELS = false

$env.CACHIX_AUTH_TOKEN = (cat /run/secrets/cachix/personal/token)

if ($env.SSH_CONNECTION? == null) or ((hostname) == "kyomu") {
    $env.SSH_AUTH_SOCK = (gpgconf --list-dirs agent-ssh-socket | str trim)
}

if $env.TMUX? == null { tmux new-session -A -s $env.USER }

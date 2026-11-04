source ($nu.default-config-dir | path join "common.nu")

rm -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

$env.PROMPT_COMMAND = {||
  let dir = (pwd | str replace $nu.home-dir "~")
  $"(ansi yellow_bold)agent-vm(ansi reset) (ansi cyan)($dir)(ansi reset)\n"
}
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR_VI_INSERT = "> "
$env.PROMPT_INDICATOR_VI_NORMAL = ": "

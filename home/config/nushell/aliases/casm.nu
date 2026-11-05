# casm: host-side commands for the agent microVM workspace.

def "casm up" [] { sudo systemctl start microvm@agent }

def "casm down" [] { sudo systemctl stop microvm@agent }

def "casm restart" [] { sudo systemctl restart microvm@agent }

def "casm status" [] { systemctl status microvm@agent }

# Follow the guest console and boot log.
def "casm logs" [] { journalctl -u microvm@agent -f }

def "casm ip" [] { "10.77.0.2" }

# Interactive shell in the guest, or run a command: casm shell -- uptime.
# --here (-H) starts in the guest path matching the host cwd.
def --wrapped "casm shell" [--here (-H), ...args] {
  let dir = $env.PWD | str replace -a "'" "'\\''"
  let cd = $"cd '($dir)' || exit 1"
  if not $here {
    ssh pl@agent-vm ...$args
  } else if ($args | is-empty) {
    ssh -t pl@agent-vm $"($cd); exec bash -il"
  } else {
    ssh pl@agent-vm $"($cd); ($args | str join ' ')"
  }
}

const CASM_FORWARD_APPS = {
  spabreaks: [3030 8080]
}

# Forward host localhost ports to the guest: casm forward spabreaks, casm forward 3030 8080
def "casm forward" [...targets: string] {
  if ($targets | is-empty) {
    error make { msg: $"usage: casm forward <app|port>...; apps: ($CASM_FORWARD_APPS | columns | str join ', ')" }
  }
  mut ports = []
  for t in $targets {
    if $t in $CASM_FORWARD_APPS {
      $ports = $ports ++ ($CASM_FORWARD_APPS | get $t)
    } else if ($t =~ '^\d+$') {
      $ports = $ports ++ [($t | into int)]
    } else {
      error make { msg: $"unknown app or port: ($t)" }
    }
  }
  let ports = $ports | uniq
  let taken = $ports | where {|p| (^ss -Hltn $"sport = :($p)" | str trim) != "" }
  if ($taken | is-not-empty) {
    error make { msg: $"local ports already in use: ($taken | str join ', ')" }
  }
  let flags = $ports | each {|p| [-L $"($p):localhost:($p)"] } | flatten
  print $"forwarding ($ports | str join ', ') to casm, Ctrl-C to stop"
  ^ssh -N -o ExitOnForwardFailure=yes ...$flags pl@agent-vm
}

def "casm proxy status" [] { systemctl status agent-egress-proxy }

def "casm proxy restart" [] { sudo systemctl restart agent-egress-proxy }

def "casm proxy logs" [] { journalctl -u agent-egress-proxy -f }

def "cx up" [] { casm up }
def "cx down" [] { casm down }
def "cx restart" [] { casm restart }
def "cx status" [] { casm status }
def "cx logs" [] { casm logs }
def "cx ip" [] { casm ip }
def --wrapped "cx shell" [--here (-H), ...args] {
  if $here { casm shell --here ...$args } else { casm shell ...$args }
}
def "cx forward" [...targets: string] { casm forward ...$targets }
def "cx proxy status" [] { casm proxy status }
def "cx proxy restart" [] { casm proxy restart }
def "cx proxy logs" [] { casm proxy logs }

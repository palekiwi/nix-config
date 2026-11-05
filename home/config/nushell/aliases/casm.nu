# casm: host-side commands for the agent microVM workspace.

def "casm start" [] { sudo systemctl start microvm@agent }

def "casm stop" [] { sudo systemctl stop microvm@agent }

def "casm restart" [] { sudo systemctl restart microvm@agent }

def "casm status" [] { systemctl status microvm@agent }

# Follow the guest console and boot log.
def "casm logs" [] { journalctl -u microvm@agent -f }

def "casm ip" [] { "10.77.0.2" }

# Interactive shell in the guest, or run a command: casm shell -- uptime
def --wrapped "casm shell" [...args] { ssh pl@agent-vm ...$args }

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

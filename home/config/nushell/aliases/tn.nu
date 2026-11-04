# tn: host-side commands for the agent microVM workspace.

def "tn start" [] { sudo systemctl start microvm@agent }

def "tn stop" [] { sudo systemctl stop microvm@agent }

def "tn restart" [] { sudo systemctl restart microvm@agent }

def "tn status" [] { systemctl status microvm@agent }

# Follow the guest console and boot log.
def "tn logs" [] { journalctl -u microvm@agent -f }

def "tn ip" [] { "10.77.0.2" }

# Interactive shell in the guest, or run a command: tn shell -- uptime
def --wrapped "tn shell" [...args] { ssh pl@agent-vm ...$args }

const TN_FORWARD_APPS = {
  spabreaks: [3030 8080]
}

# Forward host localhost ports to the guest: tn forward spabreaks, tn forward 3030 8080
def "tn forward" [...targets: string] {
  if ($targets | is-empty) {
    error make { msg: $"usage: tn forward <app|port>...; apps: ($TN_FORWARD_APPS | columns | str join ', ')" }
  }
  mut ports = []
  for t in $targets {
    if $t in $TN_FORWARD_APPS {
      $ports = $ports ++ ($TN_FORWARD_APPS | get $t)
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
  print $"forwarding ($ports | str join ', ') to agent-vm, Ctrl-C to stop"
  ^ssh -N -o ExitOnForwardFailure=yes ...$flags pl@agent-vm
}

def "tn proxy status" [] { systemctl status agent-egress-proxy }

def "tn proxy restart" [] { sudo systemctl restart agent-egress-proxy }

def "tn proxy logs" [] { journalctl -u agent-egress-proxy -f }

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

def "tn proxy status" [] { systemctl status agent-egress-proxy }

def "tn proxy restart" [] { sudo systemctl restart agent-egress-proxy }

def "tn proxy logs" [] { journalctl -u agent-egress-proxy -f }

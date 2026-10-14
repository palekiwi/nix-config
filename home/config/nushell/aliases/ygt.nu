# ygt work-project helpers migrated from zsh aliases.d/ygt.zsh
const dir = "~/code/ygt"

def --env spa [] { cd $"($dir)/spabreaks" }
def --env wss [] { cd $"($dir)/sales" }
def --env btr [] { cd $"($dir)/booking-transform" }
def --env wss-api [] { cd $"($dir)/wss-api" }
def --env vrs [] { cd $"($dir)/sb-voucher-redemptions" }
def --env mya [] { cd $"($dir)/my-account" }

def "spa console" [] { spa; tmux new -s "spabreaks-console" "make console" }
def "spa dev" [] { spa; tmux new -s "spabreaks-dev" "make dev" }
def "spa guard" [] { spa; tmux new -s "spabreaks-guard" "make guard" }
def "spa debug" [] { spa; tmux new -s "spabreaks-debug" "task debug-web" }
def "spa git" [] { spa; tmux new -s "spabreaks-gitui" "gitui" }
def "spa test" [] { spa; tmux new -s "spabreaks-test" "make test" }
def "spa testbash" [] { spa; tmux new -s "spabreaks-test-bash" "make test-bash" }
def "spa build" [] { spa; tmux new -s "spabreaks-build" "make build" }
def "spa psql" [] { spa; tmux new -s "spabreaks-psql" "make psql" }
def "spa cypress" [] { spa; tmux new -s "spabreaks-cypress" "make cypress" }

def "spa routes" [grep?: string] {
    let output = (spa; make routes)
    if $grep == null { $output } else { $output | lines | where $it =~ $grep }
}

alias spabreaks = sesh connect spabreaks
alias spa-db-migrate = db-migrate
alias spa-db-rollback = db-rollback
alias spa-db-redo = make db-migrate-redo
alias sparoutes = spa routes

alias sales = sesh connect sales

def "sales dev" [] { wss; tmux new -s "sales-dev" "make dev" }

alias booking-transform = sesh connect booking-transform
def "btr dev" [] { btr; tmux new -s "btr-dev" "make dev" }
def "btr console" [] { btr; tmux new -s "btr-console" "make console" }

alias wssapi = sesh connect wss-api
def "wss-api console" [] { wss-api; tmux new -s "wss-api-console" "task console" }
def "wss-api dev" [] { wss-api; tmux new -s "wss-api-dev" "task dev" }
def "wss-api guard" [] { wss-api; tmux new -s "wss-api-guard" "task guard" }

alias voucher-redemptions = sesh connect sb-voucher-redemptions
def "vrs console" [] { vrs; tmux new -s "sb-voucher-redemptions-console" "make console" }
def "vrs dev" [] { vrs; tmux new -s "sb-voucher-redemptions-dev" "make dev" }
def "vrs git" [] { vrs; tmux new -s "sb-voucher-redemptions-gitui" "gitui" }
def "vrs testbash" [] { vrs; tmux new -s "sb-voucher-redemptions-test-bash" "make test-bash" }

alias myaccount = sesh connect my-account
def "myaccount dev" [] { mya; tmux new -s "my-account-dev" "make dev" }
def "myaccount test" [] { mya; distrobox-host-exec make test }
alias myaguard = hmake guard
alias myabuild = hmake build

alias sbj = sb-jira-card-url | xargs xdg-open
alias sba = sb-autostaging-url | xargs xdg-open
alias sbcp = sb-create-pr
alias sbcb = sb-create-branch
alias sbcbv = sb-create-branch-variant

{ pkgs, ... }:

pkgs.writeShellScriptBin "_tmux_ygt_spabreaks_dev" ''
  session="spabreaks-dev"

  tmux rename-window -t $session:1 dev

  tmux new-window -t $session -n debug
  tmux new-window -t $session -n mcp-rspec
  tmux new-window -t $session -n mcp-ask-gemini

  tmux send-keys -t $session:1 'make dev' C-m
  tmux send-keys -t $session:2 'sleep 1; task debug-web' C-m
  tmux send-keys -t $session:3 'test-runner-mcp -H 0.0.0.0 -p 30301 -c "docker compose exec -T test bundle exec rspec --format p" -y "docker exec \$(docker-compose -f /home/pl/code/ygt/spabreaks/docker-compose.cypress.yml -p cypress ps -q cypress) npx cypress run --project . --reporter json --quiet --spec" -w "cypress"' C-m
  tmux send-keys -t $session:4 'mcp-gemini-cli --hostname 0.0.0.0 --port 30302 --workspace .' C-m

  tmux select-window -t $session:1
''

{ pkgs, ... }:

pkgs.writeShellScriptBin "opencode-cleanup" ''
  NAME=$(pwd | ${pkgs.gawk}/bin/awk -F/ '{print "opencode-" $(NF-1) "-" $NF}')
  PORT=$(generate_port_from_path "$PWD")

  if docker ps -q --filter name="$NAME" | grep -q .; then
    echo "Stopping container with name: ''${NAME}..."
    docker stop "$NAME"
  fi

  for volume_type in local cache; do
    volume_name="opencode-$volume_type-$PORT"

    if docker volume ls -q --filter name="$volume_name" | grep -q .; then
      echo "Removing volume: ''$volume_name..."
      docker volume rm "$volume_name"
    fi
  done

  echo "DONE"
''

{ pkgs, ... }:

pkgs.writers.writeBashBin "exec_gotify" ''
  # Check if at least one argument is provided
  if [ $# -eq 0 ]; then
    echo "Usage: exec_gotify <command> [args...]"
    exit 1
  fi

  # Store the full command with args for notification
  cmd="$*"

  # Function to send notification on exit
  send_notification() {
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
      curl -s -X POST http://0.0.0.0:33222/gotify -H "Content-Type: application/json" -d "{\"title\": \"Command Completed\", \"message\": \"$cmd\"}" > /dev/null
    elif [ $exit_code -ne 130 ]; then
      curl -s -X POST http://0.0.0.0:33222/gotify -H "Content-Type: application/json" -d "{\"title\": \"Command Failed\", \"message\": \"$cmd failed with exit code $exit_code\"}" > /dev/null
    fi
    exit $exit_code
  }

  # Set up trap to catch signals and ensure notification is sent
  trap send_notification EXIT INT TERM

  # Execute the command directly, preserving real-time output and signal handling
  "$@"
''

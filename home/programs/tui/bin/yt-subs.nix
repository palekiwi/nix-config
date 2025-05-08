{ pkgs, ... }:

pkgs.writeShellScriptBin "yt-subs" ''
    # Check if at least one argument is provided
    if [ $# -lt 1 ]; then
        echo "Error: URL is required"
        echo "Usage: $0 <url> [output_filename]"
        exit 1
    fi

    # Assign the URL to a variable
    URL="$1"

    # Check if output filename is provided, otherwise use timestamp
    if [ $# -eq 2 ]; then
        OUTPUT_FILE=$(echo "$2" | tr ' ' '-')
    else
        OUTPUT_FILE="$(date '+%Y%m%d_%H%M%S').srt"
    fi

    # Create directory under /tmp if it doesn't exist
    TMP_DIR="/tmp/yt-subs"
    if [ ! -d "$TMP_DIR" ]; then
        mkdir -p "$TMP_DIR"
    fi

    # Check if language is provided, otherwise default to "en"
    if [ $# -gt 2 ]; then
        LANGUAGE="$3"
    else
        LANGUAGE="en"
    fi

    # Full path for the output file
    FULL_OUTPUT_PATH="$TMP_DIR/$OUTPUT_FILE"

    # Here you can add your code to download/process the URL and save to OUTPUT_FILE
    echo "URL: $URL"
    echo "Output will be saved as: $OUTPUT_FILE"

    # Your code will go here...

    ${pkgs.yt-dlp}/bin/yt-dlp \
      --write-sub \
      --skip-download \
      --sub-langs "$LANGUAGE.*" \
      -o $FULL_OUTPUT_PATH --convert-subs srt \
      $URL
''

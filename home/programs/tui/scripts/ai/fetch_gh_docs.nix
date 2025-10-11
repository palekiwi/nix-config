{ pkgs, ... }:

# TODO:
# - [ ] Accept command line arguments for docs file and output dir with defaults
# - [ ] Validate that the file link to is a markdown file
# - [ ] Fix the subdir path, it is now specific to a particular repo
# - [ ] Extract the subdir from repo name as these will all be gh links
# - [ ] Allow passing a regular gh link but convert it to a "raw" file url befor fetching

pkgs.writers.writeNuBin "fetch_gh_docs" ''
  let DOCS_FILE = "ai_docs/gh_docs.txt"
  let OUTPUT_DIR = "ai_docs/gemini-cli"

  mkdir $OUTPUT_DIR

  open $DOCS_FILE
  | lines
  | where { |url|
      $url != "" and not ($url | str starts-with "#")
    }
  | each { |url|
      let filename = ($url | path basename)

      let subdir = (
        $url
        | parse --regex '.*/docs/(?P<subdir>.*)/[^/]*$'
        | get -i 0.subdir
        | default ""
      )

      let output_path = if ($subdir != "") {
        mkdir $"($OUTPUT_DIR)/($subdir)"
        $"($OUTPUT_DIR)/($subdir)/($filename)"
      } else {
        $"($OUTPUT_DIR)/($filename)"
      }

      print $"Fetching ($url) -> ($output_path)"
      http get $url | save -f $output_path
    }

  print "Done!"
''

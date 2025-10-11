{ pkgs, ... }:

# TODO:
# - [x] Accept command line arguments for docs file and output dir with defaults
# - [ ] Validate that the file link to is a markdown file
# - [ ] Fix the subdir path, it is now specific to a particular repo
# - [ ] Extract the subdir from repo name as these will all be gh links
# - [ ] Allow passing a regular gh link but convert it to a "raw" file url befor fetching

pkgs.writers.writeNuBin "fetch_gh_docs" ''
  def main [
    --docs-file (-f): string = "ai_docs/gh_docs.txt"
    --output-dir (-o): string = "ai_docs/gemini-cli"
  ] {
    mkdir $output_dir

    open $docs_file
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
          mkdir $"($output_dir)/($subdir)"
          $"($output_dir)/($subdir)/($filename)"
        } else {
          $"($output_dir)/($filename)"
        }

        print $"Fetching ($url) -> ($output_path)"
        http get $url | save -f $output_path
      }

    print "Done!"
  }
''

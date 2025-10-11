{ pkgs, ... }:

# TODO:
# - [x] Accept command line arguments for docs file and output dir with defaults
# - [x] Validate that the file link to is a markdown file
# - [ ] Fix the subdir path, it is now specific to a particular repo
# - [ ] Extract the subdir from repo name as these will all be gh links
# - [x] Allow passing a regular gh link but convert it to a "raw" file url befor fetching

pkgs.writers.writeNuBin "fetch_gh_docs" ''
  def validate_markdown [url: string] {
    if not ($url | str ends-with ".md") {
      error make {
        msg: "Invalid file type"
        label: {
          text: $"URL must be a markdown file: ($url)"
          span: (metadata $url).span
        }
      }
    }
  }

  def validate_github_url [url: string] {
    if not (($url | str contains "github.com") or ($url | str contains "githubusercontent.com")) {
      error make {
        msg: "Invalid URL source"
        label: {
          text: $"URL must be from GitHub: ($url)"
          span: (metadata $url).span
        }
      }
    }
  }

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
        validate_markdown $url
        validate_github_url $url

        let raw_url = (
          $url
          | str replace --regex 'github\.com/([^/]+)/([^/]+)/blob/' 'raw.githubusercontent.com/$1/$2/'
        )

        let filename = ($raw_url | path basename)

        let subdir = (
          $raw_url
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

        print $"Fetching ($raw_url) -> ($output_path)"
        http get $raw_url | save -f $output_path
      }

    print "Done!"
  }
''

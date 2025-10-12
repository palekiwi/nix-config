{ pkgs, ... }:

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
    --output-dir (-o): string = "ai_docs"
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

        let parsed = (
          $raw_url
          | parse --regex 'raw\.githubusercontent\.com/[^/]+/(?P<repo>[^/]+)/[^/]+/(?P<filepath>.*)'
          | get -i 0
        )

        let subdir = if ($parsed != null) {
          let parent_dir = ($parsed.filepath | path dirname)
          if ($parent_dir == "" or $parent_dir == ".") {
            $parsed.repo
          } else {
            $"($parsed.repo)/($parent_dir)"
          }
        } else {
          ""
        }

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

{ pkgs-unstable, ... }:

with pkgs-unstable; {
  home.packages = [ gh-f gh-s ];

  programs.gh = {
    enable = true;
    extensions = [ gh-f gh-s ];
    package = pkgs-unstable.gh;
    settings = {
      aliases = {
        pw = "pr view --web";
      };
    };
  };
}

{ pkgs, ... }:

{
  home.packages = with pkgs; [ gh gh-f gh-s ];

  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-f pkgs.gh-s ];
    settings = {
      aliases = {
        pw = "pr view --web";
      };
    };
  };
}

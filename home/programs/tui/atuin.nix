{ ... }:

{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;   # if you use zsh

    settings = {
      auto_sync = false;
      update_check = false;

      show_preview = true;
      max_preview_height = 4;

      search_mode = "fuzzy";  # or "exact"
      filter_mode = "global"; # or "host", "session", "directory"
    };
  };
}

{ ... }:

{
  xdg.configFile = {
    "Claude/claude_desktop_config.json".source = ./claude_desktop_config.json;
  };

  xfconf.settings = {
    xfce4-screensaver = {
      "saver/enabled" = false;
      "saver/mode" = 0;
      "lock/enabled" = false;
      "lock/saver-activation/enabled" = false;
      "lock/user-switching/enabled" = false;
    };
  };

  programs.git = {
    enable = true;
    userName = "claude";
    userEmail = "claude@palekiwi.com";
    extraConfig = {
      init.defaultBranch = "master";
      pull.rebase = false;
    };
  };

  home.stateVersion = "25.05";
}

{ pkgs, ... }:
{
  services.unclutter = {
    enable = true;

    extraOptions = [
      "ignore-scrolling"
      "start-hidden"
    ];

    package = pkgs.unclutter-xfixes;

    timeout = 1;

    threshold = 2;
  };
}

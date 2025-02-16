{ ... }:
{
  services.unclutter = {
    enable = true;

    extraOptions = [
      "ignore-scrolling"
      "start-hidden"
    ];

    timeout = 1;

    threshold = 1;
  };
}

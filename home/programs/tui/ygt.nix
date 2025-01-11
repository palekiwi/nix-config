{ pkgs, ... }:

{
  home.packages = with pkgs; [
    docker-compose
    gcc
    gnumake
    go-task
    google-cloud-sdk
    slack
    sops
  ];
}

{ pkgs, ... }: {
  home.packages = import ./dmenu { inherit pkgs; };
}
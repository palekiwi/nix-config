{ pkgs, lib, ... }:

{
  home.packages = import ./dmenu { inherit pkgs lib; };
}

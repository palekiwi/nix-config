{ pkgs, lib, ... }:

{
  home.packages = [ pkgs.dmenu ] ++ import ./dmenu { inherit pkgs lib; };
}

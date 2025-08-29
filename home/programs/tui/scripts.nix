{ pkgs, config, lib, ... }:

{
  home.packages = import ./scripts { inherit pkgs config lib; };
}

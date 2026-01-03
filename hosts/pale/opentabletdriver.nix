{ pkgs, ... }:

{
  hardware.opentabletdriver.enable = true;

  environment.systemPackages = with pkgs; [
    opentabletdriver
  ];

  # Required by OpenTabletDriver
  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];
}

{ pkgs, ... }:

{
  hardware.opentabletdriver.enable = true;

  environment.systemPackages = with pkgs; [
    opentabletdriver
  ];

  # Required by OpenTabletDriver
  hardware.uinput.enable = true;
  boot.kernelModules = [ "uinput" ];

  services.xserver.modules = [ pkgs.xf86_input_wacom ];

  users.users.pl.extraGroups = [ "input" ];

  services.xserver.config = ''
    Section "InputClass"
      Identifier "OpenTabletDriver Virtual Tablet"
      MatchProduct "OpenTabletDriver Virtual"
      MatchDevicePath "/dev/input/event*"
      Driver "wacom"
    EndSection
  '';
}

{ inputs, ... }:

let
  vertoxr = inputs.self.packages.x86_64-linux.vertoxr;
in
{
  environment.systemPackages = [ vertoxr ];
  services.udev.packages = [ vertoxr ];
}

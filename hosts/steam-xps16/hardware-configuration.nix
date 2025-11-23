# This file needs to be generated on the actual hardware.
#
# After booting from NixOS installer on the external SSD:
# 1. Partition and format your external SSD
# 2. Mount your filesystems to /mnt
# 3. Run: nixos-generate-config --root /mnt
# 4. Copy the generated hardware-configuration.nix to this location
# 5. Verify and update the PCI bus IDs in nvidia.nix:
#    Run: lspci | grep -E "VGA|3D"
#    Look for Intel Arc and NVIDIA devices
#
# Example output:
# 00:02.0 VGA compatible controller: Intel Corporation ...
# 01:00.0 VGA compatible controller: NVIDIA Corporation ...
#
# Update nvidia.nix with these bus IDs in format "PCI:X:Y:Z"
{ config, lib, ... }:

{
  imports = [ ];

  # Placeholder - will be populated by nixos-generate-config
  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/PLACEHOLDER";
    fsType = "vfat";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

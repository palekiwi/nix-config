{ config, ... }:
{
  # Enable OpenGL for both Intel Arc and NVIDIA
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Required for Steam games
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Disabled for gaming stability.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Disabled for gaming - we want the GPU always ready.
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # RTX 4060 supports open drivers, but using proprietary for maximum compatibility.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Use stable driver version for gaming
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # NVIDIA PRIME configuration for hybrid graphics
  # Using sync mode: NVIDIA handles all rendering, Intel manages display output
  # This ensures maximum gaming performance with NVIDIA always active
  hardware.nvidia.prime = {
    sync.enable = true;

    # IMPORTANT: These bus IDs must be verified on actual hardware
    # Run: lspci | grep -E "VGA|3D"
    # Update these values based on output
    intelBusId = "PCI:0:2:0";  # Intel Arc - verify this!
    nvidiaBusId = "PCI:1:0:0"; # NVIDIA 4060 - verify this!
  };

  # Enable Intel Arc support
  boot.kernelModules = [ "i915" ];

  # Intel Arc graphics settings
  hardware.intelgpu.driver = "xe"; # Modern Intel driver for Arc
}

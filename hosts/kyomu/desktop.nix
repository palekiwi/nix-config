{ lib, ... }:

{
  imports = [ ../../modules/awesome-desktop.nix ];

  # Ported from nagomi, which runs this exact setup on the same
  # physical machine (Intel NUC8i7HNK). No explicit GPU config is
  # needed: amdgpu/i915 both load by default for the Vega M GL +
  # HD Graphics 630 pair.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  specialisation.awesome-only.configuration = {
    services.displayManager.sddm.enable = lib.mkForce false;
    services.desktopManager.plasma6.enable = lib.mkForce false;
    services.displayManager.defaultSession = "none+awesome";
    services.xserver.displayManager.lightdm.greeters.mini = {
      enable = true;
      user = "pl";
    };
  };

  systemd.user.services = lib.genAttrs [ "picom" "xscreensaver" ] (_: {
    unitConfig.ConditionEnvironment = "!WAYLAND_DISPLAY";
  });
}

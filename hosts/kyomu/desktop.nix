{ ... }:

{
  # Ported from nagomi, which runs this exact setup on the same
  # physical machine (Intel NUC8i7HNK). No explicit GPU config is
  # needed: amdgpu/i915 both load by default for the Vega M GL +
  # HD Graphics 630 pair.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = "jennifer";
  };

  # Workaround for autologin issues if any
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}

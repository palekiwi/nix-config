{ ... }:
{
  imports = [ ../../modules/awesome-desktop.nix ];

  services = {
    displayManager.defaultSession = "none+awesome";

    xserver = {
      dpi = 96;

      displayManager.lightdm.greeters.mini = {
        enable = true;
        user = "pl";
        extraConfig = ''
          [greeter]
          show-password-label = false
          [greeter-theme]
          background-image = ""
        '';
      };
    };
  };
}

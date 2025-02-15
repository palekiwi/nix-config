{ pkgs, ... }:
{
  services = {
    displayManager.defaultSession = "none+awesome";

    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

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

      windowManager = {
        awesome = {
          enable = true;
          luaModules = with pkgs.luaPackages; [
            luarocks # is the package manager for Lua modules
            luadbi-mysql # Database abstraction layer
          ];
        };
      };
    };
  };
}

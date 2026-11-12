{ pkgs, ... }:
let
  displayLayout = import ../../home/programs/gui/dmenu/xrandr.nix { inherit pkgs; };
in
{
  environment.systemPackages = [ displayLayout ];

  services = {
    displayManager.defaultSession = "none+awesome";

    xserver = {
      enable = true;

      dpi = 96;

      xkb = {
        layout = "us";
        variant = "";
      };

      displayManager.setupCommands = ''
        ${displayLayout}/bin/dmenu_xrandr --profile auto --layout-only || echo "Display layout failed; keeping X defaults" >&2
      '';

      displayManager.sessionCommands = ''
        ${displayLayout}/bin/dmenu_xrandr --profile auto --layout-only || echo "Display layout failed; keeping X defaults" >&2
      '';

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

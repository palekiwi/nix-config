# sc-controller-cc profile, generated from Nix.
#
# Button names (keys of `buttons`), as defined by sc-controller's SCButtons:
#   A B X Y            face buttons
#   LB RB              bumpers
#   LT RT              triggers (full pull, used as buttons)
#   LGRIP RGRIP        upper back grips (L4 / R4)
#   LGRIP2 RGRIP2      lower back grips (L5 / R5)
#   START BACK         menu (top right) / view (top left)
#   C                  Steam button
#   DOTS               "..." quick access button
#   LPAD RPAD          trackpad clicks
#   STICKPRESS         left stick click
#   RSTICKPRESS        right stick click
# Source: https://github.com/Patola/sc-controller-cc/blob/master/scc/constants.py
# (class SCButtons); controller mapping in scc/drivers/sc2.py.
#
# Key names (values of `buttons`) are Linux evdev names, e.g. KEY_ENTER,
# KEY_LEFTMETA, BTN_LEFT. A binding is a list of keys pressed together.
# Source: https://github.com/torvalds/linux/blob/master/include/uapi/linux/input-event-codes.h
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sc-controller;

  buttonNames = [
    "A" "B" "X" "Y" "LB" "RB" "LT" "RT"
    "LGRIP" "RGRIP" "LGRIP2" "RGRIP2"
    "START" "BACK" "C" "DOTS"
    "LPAD" "RPAD" "STICKPRESS" "RSTICKPRESS"
  ];

  keyAction = keys:
    lib.concatMapStringsSep " and " (k: "button(Keys.${k})") keys;

  defaultButtons = {
    C = "hold(menu('Default.menu'), menu('Default.menu'))";
  };

  profile = {
    buttons = lib.mapAttrs (_: action: { inherit action; })
      (defaultButtons // lib.mapAttrs (_: keyAction) cfg.buttons);
    dpad.action =
      "dpad(button(Keys.KEY_UP), button(Keys.KEY_DOWN), "
      + "button(Keys.KEY_LEFT), button(Keys.KEY_RIGHT))";
    pad_left.action =
      "feedback(LEFT, 4096, 16, ball(XY(None, mouse(Rels.REL_WHEEL, 1.0))))";
    pad_right.action =
      "smooth(8, 0.78, 2.0, feedback(RIGHT, 256, sens(3.0, 3.0, ball(mouse()))))";
    stick = { };
    rstick = { };
    gyro = { };
    cpad = { };
    trigger_left = { };
    trigger_right = { };
    menus = { };
    is_template = false;
    version = 1.4;
  };

  allKeys = lib.unique (lib.concatLists (lib.attrValues cfg.buttons));

  profileFile = pkgs.runCommand "Default.sccprofile" {
    profile = builtins.toJSON profile;
    passAsFile = [ "profile" ];
  } ''
    header=${pkgs.linuxHeaders}/include/linux/input-event-codes.h
    for key in ${lib.escapeShellArgs allKeys}; do
      if ! grep -qE "^#define[[:space:]]+$key[[:space:]]" "$header"; then
        echo "sc-controller: unknown key name '$key' (see input-event-codes.h)" >&2
        exit 1
      fi
    done
    ${lib.getExe pkgs.jq} . "$profilePath" > $out
  '';
in {
  options.programs.sc-controller = {
    enable = lib.mkEnableOption "sc-controller-cc profile generated from Nix";

    buttons = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nonEmptyListOf lib.types.str);
      default = { };
      example = {
        A = [ "KEY_ENTER" ];
        B = [ "KEY_LEFTMETA" "KEY_Q" ];
      };
      description = "Button name to the list of evdev keys it presses together.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = lib.all (b: lib.elem b buttonNames) (lib.attrNames cfg.buttons);
      message = "programs.sc-controller.buttons: unknown button(s) "
        + lib.concatStringsSep ", "
          (lib.filter (b: !lib.elem b buttonNames) (lib.attrNames cfg.buttons))
        + "; valid: " + lib.concatStringsSep " " buttonNames;
    }];

    xdg.configFile."scc/profiles/Default.sccprofile".source = profileFile;
  };
}

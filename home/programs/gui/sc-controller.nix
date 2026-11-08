# sc-controller-cc profile, generated from Nix.
#
# Button names (keys of `buttons` and `layers.<modifier>.buttons`), as
# defined by sc-controller's SCButtons:
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
# Layer modifiers (keys of `layers`): LB RB LT RT LGRIP RGRIP LGRIP2 RGRIP2.
# D-pad directions (keys of `layers.<modifier>.dpad`): up down left right.
#
# Key names (binding values) are Linux evdev names, e.g. KEY_ENTER,
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

  modifierNames = [ "LB" "RB" "LT" "RT" "LGRIP" "RGRIP" "LGRIP2" "RGRIP2" ];

  directions = [ "up" "down" "left" "right" ];

  binding = lib.types.nonEmptyListOf lib.types.str;

  keyAction = keys:
    lib.concatMapStringsSep " and " (k: "button(Keys.${k})") keys;

  layerNames = lib.attrNames cfg.layers;

  withLayers = getLayerBinding: base:
    let
      layered = lib.concatMap (m:
        let b = getLayerBinding cfg.layers.${m};
        in lib.optional (b != null) "${m}, ${keyAction b}") layerNames;
    in
    if layered == [ ] then base
    else "mode(${lib.concatStringsSep ", " (layered ++ [ base ])})";

  buttonAction = name:
    let
      base =
        if cfg.buttons ? ${name} then keyAction cfg.buttons.${name}
        else if name == "C" then "hold(menu('Default.menu'), menu('Default.menu'))"
        else "None";
    in withLayers (l: l.buttons.${name} or null) base;

  usedButtons = lib.filter
    (n: cfg.buttons ? ${n} || n == "C"
      || lib.any (m: cfg.layers.${m}.buttons ? ${n}) layerNames)
    buttonNames;

  withFeedback = side: amplitude: period: action:
    if amplitude == 0 then action
    else "feedback(${side}, ${toString amplitude}"
      + lib.optionalString (period != null) ", ${toString period}"
      + ", ${action})";

  dpadAction = dir: withLayers (l: l.dpad.${dir} or null)
    (keyAction [ "KEY_${lib.toUpper dir}" ]);

  profile = {
    buttons = lib.genAttrs usedButtons (n: { action = buttonAction n; });
    dpad.action = "dpad(${lib.concatMapStringsSep ", " dpadAction directions})";
    pad_left.action = withFeedback "LEFT" cfg.pads.left.haptics 16
      "ball(XY(None, mouse(Rels.REL_WHEEL, ${toString cfg.pads.left.scrollSpeed})))";
    pad_right.action = "smooth(8, 0.78, 2.0, "
      + withFeedback "RIGHT" cfg.pads.right.haptics null
        "sens(${toString cfg.pads.right.sensitivity}, ${toString cfg.pads.right.sensitivity}, ball(mouse()))"
      + ")";
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

  allBindings = lib.attrValues cfg.buttons
    ++ lib.concatMap (l: lib.attrValues l.buttons ++ lib.attrValues l.dpad)
      (lib.attrValues cfg.layers);

  allKeys = lib.unique (lib.concatLists allBindings);

  unknown = valid: names: lib.filter (n: !lib.elem n valid) names;

  layerButtonNames = lib.concatMap (l: lib.attrNames l.buttons) (lib.attrValues cfg.layers);
  layerDpadNames = lib.concatMap (l: lib.attrNames l.dpad) (lib.attrValues cfg.layers);
  boundModifiers = lib.filter (m: cfg.buttons ? ${m}) layerNames;

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

  layerType = lib.types.submodule {
    options = {
      buttons = lib.mkOption {
        type = lib.types.attrsOf binding;
        default = { };
        description = "Button bindings while the modifier is held.";
      };
      dpad = lib.mkOption {
        type = lib.types.attrsOf binding;
        default = { };
        description = "D-pad bindings (up, down, left, right) while the modifier is held.";
      };
    };
  };
in {
  options.programs.sc-controller = {
    enable = lib.mkEnableOption "sc-controller-cc profile generated from Nix";

    buttons = lib.mkOption {
      type = lib.types.attrsOf binding;
      default = { };
      example = {
        A = [ "KEY_ENTER" ];
        B = [ "KEY_LEFTMETA" "KEY_Q" ];
      };
      description = "Base layer: button name to the list of evdev keys it presses together.";
    };

    layers = lib.mkOption {
      type = lib.types.attrsOf layerType;
      default = { };
      example = {
        RT.dpad.up = [ "KEY_LEFTMETA" "KEY_TAB" ];
        RT.buttons.B = [ "KEY_LEFTMETA" "KEY_Q" ];
      };
      description = ''
        Layers keyed by the modifier button that activates them while held.
        Unbound buttons fall through to the base layer.
      '';
    };

    pads = {
      left = {
        scrollSpeed = lib.mkOption {
          type = lib.types.number;
          default = 1.0;
          description = "Left pad vertical scroll speed multiplier.";
        };
        haptics = lib.mkOption {
          type = lib.types.ints.between 0 32768;
          default = 4096;
          description = "Left pad haptic feedback amplitude while scrolling; 0 disables it.";
        };
      };
      right = {
        sensitivity = lib.mkOption {
          type = lib.types.number;
          default = 3.0;
          description = "Right pad pointer speed multiplier.";
        };
        haptics = lib.mkOption {
          type = lib.types.ints.between 0 32768;
          default = 256;
          description = "Right pad haptic feedback amplitude while moving the pointer; 0 disables it.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = unknown buttonNames (lib.attrNames cfg.buttons ++ layerButtonNames) == [ ];
        message = "programs.sc-controller: unknown button(s) "
          + toString (unknown buttonNames (lib.attrNames cfg.buttons ++ layerButtonNames))
          + "; valid: " + toString buttonNames;
      }
      {
        assertion = unknown modifierNames layerNames == [ ];
        message = "programs.sc-controller.layers: unknown modifier(s) "
          + toString (unknown modifierNames layerNames)
          + "; valid: " + toString modifierNames;
      }
      {
        assertion = unknown directions layerDpadNames == [ ];
        message = "programs.sc-controller.layers.*.dpad: unknown direction(s) "
          + toString (unknown directions layerDpadNames)
          + "; valid: " + toString directions;
      }
      {
        assertion = boundModifiers == [ ];
        message = "programs.sc-controller: layer modifier(s) "
          + toString boundModifiers + " must not also be bound in buttons";
      }
    ];

    xdg.configFile."scc/profiles/Default.sccprofile" = {
      source = profileFile;
      onChange = ''
        ${pkgs.systemd}/bin/systemctl --user try-restart scc-daemon.service || true
      '';
    };
  };
}

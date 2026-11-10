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

  menuCommands = {
    radial = "radialmenu";
    list = "menu";
    row = "hmenu";
    grid = "gridmenu";
  };

  menuAction = side: name:
    let m = cfg.menus.${name};
    in "${menuCommands.${m.type}}('${name}.menu', ${side}"
      + ", ${if m.confirm == "release" then "SAME" else m.confirm}"
      + lib.optionalString (m.cancel != null) ", ${m.cancel}"
      + ")";

  stickMenuAction = name:
    "${menuCommands.${cfg.menus.${name}.type}}('${name}.menu'"
      + lib.optionalString (cfg.stick.confirm == "centre") ", DEFAULT, STICK, B"
      + ")";

  zoneNames = [ "up" "down" "left" "right" "up-left" "up-right" "down-left" "down-right" ];

  zonesAction = zones: "click(dpad8("
    + lib.concatMapStringsSep ", "
      (z: if zones ? ${z} then keyAction zones.${z} else "None") zoneNames
    + "))";

  layerPads = lib.concatMap (l: [ l.pads.left l.pads.right ]) (lib.attrValues cfg.layers);

  padWithLayers = pad: side: base:
    let
      layered = lib.concatMap (m:
        let p = cfg.layers.${m}.pads.${pad};
        in if p.menu != null then [ "${m}, ${menuAction side p.menu}" ]
        else if p.zones != { } then [ "${m}, ${zonesAction p.zones}" ]
        else [ ]) layerNames;
    in
    if layered == [ ] then base
    else "mode(${lib.concatStringsSep ", " (layered ++ [ base ])})";

  menuFile = name: m: builtins.toJSON (lib.imap0 (i: item: {
    id = "i${toString i}";
    name = item.label;
    action = keyAction item.keys;
  }) m.items);

  layerMenuNames = lib.concatMap (l:
    lib.filter (n: n != null) [ l.pads.left.menu l.pads.right.menu ])
    (lib.attrValues cfg.layers);

  dpadAction = dir: withLayers (l: l.dpad.${dir} or null)
    (keyAction [ "KEY_${lib.toUpper dir}" ]);

  profile = {
    buttons = lib.genAttrs usedButtons (n: { action = buttonAction n; });
    dpad.action = "dpad(${lib.concatMapStringsSep ", " dpadAction directions})";
    pad_left.action = padWithLayers "left" "LEFT" (withFeedback "LEFT" cfg.pads.left.haptics 16
      "ball(XY(None, mouse(Rels.REL_WHEEL, ${toString cfg.pads.left.scrollSpeed})))");
    pad_right.action = padWithLayers "right" "RIGHT" ("smooth(8, 0.78, 2.0, "
      + withFeedback "RIGHT" cfg.pads.right.haptics null
        "sens(${toString cfg.pads.right.sensitivity}, ${toString cfg.pads.right.sensitivity}, ball(mouse()))"
      + ")");
    stick = lib.optionalAttrs (cfg.stick.menu != null) {
      action = stickMenuAction cfg.stick.menu;
    };
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
      (lib.attrValues cfg.layers)
    ++ lib.concatMap (m: map (i: i.keys) m.items) (lib.attrValues cfg.menus)
    ++ lib.concatMap (p: lib.attrValues p.zones) layerPads;

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
      pads = lib.genAttrs [ "left" "right" ] (pad: {
        menu = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name of a menu (from `menus`) the ${pad} pad opens and steers while the modifier is held.";
        };
        zones = lib.mkOption {
          type = lib.types.attrsOf binding;
          default = { };
          example = { up = [ "KEY_LEFTMETA" "KEY_T" ]; };
          description = "Keys sent by pressing the ${pad} pad in one of eight 45-degree zones while the modifier is held. Zones: ${toString zoneNames}.";
        };
      });
    };
  };

  menuItemType = lib.types.submodule {
    options = {
      label = lib.mkOption {
        type = lib.types.str;
        description = "Text shown for the entry.";
      };
      keys = lib.mkOption {
        type = binding;
        description = "Evdev keys pressed together when the entry is chosen.";
      };
    };
  };

  menuType = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.enum (lib.attrNames menuCommands);
        default = "radial";
        description = "Menu layout.";
      };
      confirm = lib.mkOption {
        type = lib.types.enum ([ "release" ] ++ buttonNames);
        default = "release";
        description = "Choose the entry when the thumb lifts off the steering pad (release), or when the given button is released.";
      };
      cancel = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum buttonNames);
        default = null;
        description = "Button that closes the menu without choosing; null keeps the daemon default (B).";
      };
      items = lib.mkOption {
        type = lib.types.nonEmptyListOf menuItemType;
        description = "Menu entries, in order.";
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

    menus = lib.mkOption {
      type = lib.types.attrsOf menuType;
      default = { };
      example = {
        tags.items = [
          { label = "r"; keys = [ "KEY_LEFTMETA" "KEY_R" ]; }
        ];
      };
      description = "Menus by name, opened from layer pads (`layers.<modifier>.pads.<pad>.menu`) or the left stick (`stick.menu`).";
    };

    stick.menu = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tags";
      description = ''
        Name of a menu (from `menus`) the left stick opens when tilted past a
        third of its travel, and then steers. `stick.confirm` chooses how an
        entry is picked and how the menu is cancelled. The menu's `confirm`
        and `cancel` settings do not apply to the stick.
      '';
    };

    stick.confirm = lib.mkOption {
      type = lib.types.enum [ "press" "centre" ];
      default = "press";
      description = ''
        How the stick menu picks the selected entry. press: pressing the
        stick picks it, returning the stick to center cancels. centre:
        returning the stick to center picks the highlighted entry (or closes
        the menu if none is highlighted), B cancels; radial menus only.
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
        assertion = unknown (lib.attrNames cfg.menus) layerMenuNames == [ ];
        message = "programs.sc-controller.layers.*.pads: unknown menu(s) "
          + toString (unknown (lib.attrNames cfg.menus) layerMenuNames);
      }
      {
        assertion = cfg.stick.menu == null || cfg.menus ? ${cfg.stick.menu};
        message = "programs.sc-controller.stick.menu: unknown menu '${toString cfg.stick.menu}'"
          + "; defined: " + toString (lib.attrNames cfg.menus);
      }
      {
        assertion = cfg.stick.confirm != "centre" || cfg.stick.menu == null
          || (cfg.menus.${cfg.stick.menu}.type or "radial") == "radial";
        message = "programs.sc-controller.stick.confirm: centre needs a radial stick menu";
      }
      {
        assertion = unknown zoneNames (lib.concatMap (p: lib.attrNames p.zones) layerPads) == [ ];
        message = "programs.sc-controller.layers.*.pads.*.zones: unknown zone(s) "
          + toString (unknown zoneNames (lib.concatMap (p: lib.attrNames p.zones) layerPads))
          + "; valid: " + toString zoneNames;
      }
      {
        assertion = lib.all (p: p.menu == null || p.zones == { }) layerPads;
        message = "programs.sc-controller.layers.*.pads: a pad takes either menu or zones, not both";
      }
      {
        assertion = boundModifiers == [ ];
        message = "programs.sc-controller: layer modifier(s) "
          + toString boundModifiers + " must not also be bound in buttons";
      }
    ];

    xdg.configFile = lib.mapAttrs' (name: m:
      lib.nameValuePair "scc/menus/${name}.menu" { text = menuFile name m; }) cfg.menus
    // {
    "scc/profiles/Default.sccprofile" = {
      source = profileFile;
      onChange = ''
        ${pkgs.systemd}/bin/systemctl --user try-restart scc-daemon.service || true
      '';
    };
    };
  };
}

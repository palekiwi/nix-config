{ ... }:
{
  services.picom = {
    enable = true;

    backend = "xrender";

    shadow = true;
    shadowOpacity = 0.8;
    shadowOffsets = [ (-32) (-32) ];
    shadowExclude = [
      "! name~=''"
      "!focused"
      "name = 'Notification'"
      "name *= 'picom'"
      "class_g = 'Firefox' && argb"
      "class_g = 'awesome'"
      "class_g ?= 'Notify-osd'"
      "class_g ?= 'Cairo-dock'"
      "_GTK_FRAME_EXTENTS@:c"
      "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
    ];

    settings = {
      "shadow-radius" = 32;
    };

    vSync = true;
  };
}

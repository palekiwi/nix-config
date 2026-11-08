{ ... }:

{
  programs.sc-controller = {
    buttons = {
      A = [ "KEY_ENTER" ];
      B = [ "KEY_ESC" ];
      X = [ "KEY_BACKSPACE" ];
      Y = [ "KEY_SPACE" ];
      DOTS = [ "KEY_PAUSE" ];
      RPAD = [ "BTN_LEFT" ];
      LPAD = [ "BTN_RIGHT" ];
      LGRIP = [ "KEY_LEFTSHIFT" ];
      RGRIP = [ "KEY_LEFTCTRL" ];
      START = [ "KEY_LEFTMETA" "KEY_BACKSPACE" ];
      BACK = [ "KEY_LEFTMETA" "KEY_LEFTCTRL" "KEY_BACKSPACE" ];
      LB = [ "KEY_LEFTCTRL" "KEY_PAGEUP" ];
      RB = [ "KEY_LEFTCTRL" "KEY_PAGEDOWN" ];
    };
    pads = {
      left = {
        scrollSpeed = 1.0;
        haptics = 0;
      };
      right = {
        sensitivity = 3.0;
        haptics = 0;
      };
    };
    menus.tags.items = [
      { label = "vm"; keys = [ "KEY_LEFTMETA" "KEY_R" ]; }
      { label = "web"; keys = [ "KEY_LEFTMETA" "KEY_S" ]; }
      { label = "editor"; keys = [ "KEY_LEFTMETA" "KEY_T" ]; }
      { label = "web 2"; keys = [ "KEY_LEFTMETA" "KEY_F" ]; }
      { label = "coord"; keys = [ "KEY_LEFTMETA" "KEY_W" ]; }
      { label = "chat"; keys = [ "KEY_LEFTMETA" "KEY_A" ]; }
    ];
    layers.LT.buttons = {
      A = [ "KEY_F2" ];
      X = [ "KEY_F3" ];
      B = [ "KEY_F4" ];
      Y = [ "KEY_LEFTCTRL" "KEY_F" ];
    };
    layers.RT = {
      pads.left.menu = "tags";
      buttons.B = [ "KEY_LEFTMETA" "KEY_Q" ];
      dpad = {
        up = [ "KEY_LEFTMETA" "KEY_TAB" ];
        down = [ "KEY_LEFTMETA" "KEY_Q" ];
        left = [ "KEY_LEFTMETA" "KEY_N" ];
        right = [ "KEY_LEFTMETA" "KEY_I" ];
      };
    };
  };
}

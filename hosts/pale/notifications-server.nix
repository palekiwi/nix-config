{ ... }:
{
   services.notifications-server = {
     enable = false;
     port = 33222;
     hostname = "0.0.0.0";
     notifyCommand = "notify-send \"$NOTIFY_TITLE\" \"$NOTIFY_MESSAGE\"";
     gotifyTokenFile = "/run/secrets/gotify/env";
     gotifyHost = "haze:8780";
   };
}

{ ... }:
{
   services.notifications-server = {
     enable = true;
     port = 33222;
     hostname = "0.0.0.0";
     notifyCommand = "notify-send \"$NOTIFY_TITLE\" \"$NOTIFY_MESSAGE\"";
     gotifyTokenFile = "/run/secrets/gotify/token";
     gotifyHost = "haze:8780";
   };
}

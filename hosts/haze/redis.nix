{
  services.redis.servers.nextcloud = {
    enable = true;
    port = 6379;

    bind = "127.0.0.1";

    save = [ ]; # Disable RDB snapshots
  };
}

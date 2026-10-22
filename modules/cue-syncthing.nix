{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "pl";
    group = "users";
    dataDir = "/home/pl/.local/state/syncthing";
    configDir = "/home/pl/.local/state/syncthing/config";
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = false;
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      devices = { };
      folders = { };
      options = {
        listenAddresses = [ "tcp://127.0.0.1:22000" ];
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
      };
    };
  };

  # Bootstrap identities without creating Syncthing's default ~/Sync folder.
  systemd.services.syncthing = {
    environment.STNODEFAULTFOLDER = "true";
    # The NixOS settings updater runs after first startup. Keep even that
    # initial default configuration isolated until peers are configured.
    serviceConfig = {
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
    };
  };
}

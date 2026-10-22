{ config, lib, ... }:

let
  hostName = config.networking.hostName;

  peers = {
    pale = "TUYKCSW-XWA7FT2-VXXJV4K-NSTVIH4-BQPP5VR-G7ELV7Q-MVA7ZQG-HCE6NA2";
    kyomu = "SO7T23M-A6PNWMN-2JL3GCY-6BRHNJF-KE4YNMN-VQYPQHM-VT2ZN4Q-LHVN3QF";
    haze = "XK2UDDG-JGCUIUP-BECYJBJ-YP5FF7H-OWO3ACS-WTX25AG-GRH2ITJ-5DPQCQD";
  };

  # Hosts receiving the cue store. kyomu joins after pale <-> haze converges.
  storeHosts = [
    "pale"
    "haze"
  ];

  others = lib.filterAttrs (name: _: name != hostName) peers;
in
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
      devices = lib.mapAttrs (name: id: {
        inherit id;
        # Tailscale MagicDNS names; no discovery or relays.
        addresses = [ "tcp://${name}:22000" ];
      }) others;

      folders.cue-store = {
        enable = builtins.elem hostName storeHosts;
        path = "/home/pl/cue";
        type = "sendreceive";
        devices = builtins.filter (name: name != hostName) storeHosts;
        # Declared paused; unpause deliberately after checking each replica.
        paused = true;
      };

      options = {
        listenAddresses = [ "tcp://0.0.0.0:22000" ];
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
      };
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22000 ];

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
}

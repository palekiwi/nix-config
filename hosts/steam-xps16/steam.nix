{ pkgs, ... }:
{
  # Steam configuration for dedicated gaming machine
  programs.steam = {
    enable = true;
    
    # Enable Steam Remote Play
    remotePlay.openFirewall = true;
    
    # Enable Source Dedicated Server
    dedicatedServer.openFirewall = true;
    
    # Enable local network game transfers
    localNetworkGameTransfers.openFirewall = true;
    
    # Extra compatibility tools
    extraCompatPackages = with pkgs; [
      proton-ge-bin  # Community Proton builds for better game compatibility
    ];
  };

  # Additional gaming packages
  environment.systemPackages = with pkgs; [
    # Steam utilities
    steamcmd  # Steam command-line client
    steam-tui # Terminal UI for Steam
  ];
}
